import Foundation

final class BudgetStatisticsService {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func availableMonths(from events: [BudgetHistoryEvent], now: Date = Date()) -> [HistoryMonthOption] {
        let latestMonthDate = startOfMonth(for: now)
        guard let earliestEventDate = events.map(\.createdAt).min() else {
            let currentComponents = calendar.dateComponents([.year, .month], from: latestMonthDate)
            return [HistoryMonthOption(year: currentComponents.year ?? 0, month: currentComponents.month ?? 1)]
        }

        var cursor = startOfMonth(for: earliestEventDate)
        var result: [HistoryMonthOption] = []

        while cursor <= latestMonthDate {
            let components = calendar.dateComponents([.year, .month], from: cursor)
            result.append(
                HistoryMonthOption(
                    year: components.year ?? 0,
                    month: components.month ?? 1
                )
            )

            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }

        return result.sorted { lhs, rhs in
            if lhs.year == rhs.year {
                return lhs.month > rhs.month
            }
            return lhs.year > rhs.year
        }
    }

    func availableYears(from events: [BudgetHistoryEvent], now: Date = Date()) -> [Int] {
        let currentYear = calendar.component(.year, from: now)
        guard let earliestEventDate = events.map(\.createdAt).min() else {
            return [currentYear]
        }

        let earliestYear = calendar.component(.year, from: earliestEventDate)
        return Array(earliestYear...currentYear).sorted(by: >)
    }

    func eventsForSelectedPeriod(
        from events: [BudgetHistoryEvent],
        mode: HistoryPeriodMode,
        selectedMonth: HistoryMonthOption?,
        selectedYear: Int?,
        now: Date = Date()
    ) -> [BudgetHistoryEvent] {
        let filtered: [BudgetHistoryEvent]

        switch mode {
        case .month:
            guard let selectedMonth,
                  let monthStart = selectedMonth.startDate(calendar: calendar),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                filtered = []
                break
            }
            filtered = events.filter { $0.createdAt >= monthStart && $0.createdAt < monthEnd }

        case .year:
            let year = selectedYear ?? calendar.component(.year, from: now)
            guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) else {
                filtered = []
                break
            }
            filtered = events.filter { $0.createdAt >= yearStart && $0.createdAt < yearEnd }

        case .allTime:
            filtered = events
        }

        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    func buildSummary(from periodEvents: [BudgetHistoryEvent]) -> BudgetStatisticsSummary {
        let statisticEvents = periodEvents.filter(\.affectsStatistics)
        let incomeEvents = statisticEvents.filter { $0.type == .income }
        let expenseEvents = statisticEvents.filter { $0.type == .expense }
        let totalIncome = roundToCents(incomeEvents.reduce(0) { $0 + $1.amount })
        let totalExpense = roundToCents(expenseEvents.reduce(0) { $0 + $1.amount })
        let largestExpense = roundToCents(expenseEvents.map(\.amount).max() ?? 0)
        let averageExpense: Double
        if expenseEvents.isEmpty {
            averageExpense = 0
        } else {
            averageExpense = roundToCents(totalExpense / Double(expenseEvents.count))
        }

        return BudgetStatisticsSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netResult: roundToCents(totalIncome - totalExpense),
            operationCount: periodEvents.count,
            incomeOperationsCount: incomeEvents.count,
            expenseOperationsCount: expenseEvents.count,
            transferOperationsCount: periodEvents.filter { $0.type.isTransfer }.count,
            largestExpense: largestExpense,
            averageExpense: averageExpense,
            expenseByCategory: buildExpenseByCategory(from: expenseEvents, totalExpense: totalExpense),
            expenseSubcategoriesByCategory: buildExpenseSubcategoriesByCategory(
                from: expenseEvents,
                totalExpense: totalExpense
            )
        )
    }

    func buildDashboardStatistics(
        from events: [BudgetHistoryEvent],
        balanceState: DashboardBalanceState,
        currencyCode: String,
        period: DashboardStatisticsPeriod,
        now: Date = Date()
    ) -> DashboardPeriodStatistics {
        let periodEvents = currentPeriodEvents(from: events, period: period, now: now)
            .filter { $0.currencyCode == currencyCode }
        let summary = buildSummary(from: periodEvents)

        let hryvniaCardBalance = balanceState.cards
            .filter { card in
                card.currencyCode == currencyCode
            }
            .reduce(0.0) { $0 + $1.remainingAmount }
        let closingBalance = roundToCents(balanceState.bankAmount + hryvniaCardBalance)
        let openingBalance = roundToCents(
            closingBalance - summary.totalIncome + summary.totalExpense
        )

        let outstandingDebt = balanceState.cards
            .filter { $0.systemKey == .debt }
            .reduce(0.0) { result, debt in
                let target = debt.maxLimit ?? debt.minLimit ?? 0
                return result + max(0, target - debt.spentAmount)
            }
        let currencyBalances = Dictionary(
            grouping: balanceState.cards.filter { card in
                card.currencyCode != currencyCode
            },
            by: \.currencyCode
        )
        .map { code, cards in
            DashboardCurrencyBalance(
                currencyCode: code,
                amount: roundToCents(cards.reduce(0.0) { $0 + $1.remainingAmount })
            )
        }
        .sorted { $0.currencyCode < $1.currencyCode }

        return DashboardPeriodStatistics(
            totalIncome: summary.totalIncome,
            totalExpense: summary.totalExpense,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            outstandingDebt: roundToCents(outstandingDebt),
            currencyBalances: currencyBalances
        )
    }

    private func currentPeriodEvents(
        from events: [BudgetHistoryEvent],
        period: DashboardStatisticsPeriod,
        now: Date
    ) -> [BudgetHistoryEvent] {
        let start: Date
        let end: Date

        switch period {
        case .month:
            start = startOfMonth(for: now)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) else {
                return []
            }
            end = nextMonth
        case .year:
            let year = calendar.component(.year, from: now)
            guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                  let nextYear = calendar.date(byAdding: .year, value: 1, to: yearStart) else {
                return []
            }
            start = yearStart
            end = nextYear
        }

        return events.filter { $0.createdAt >= start && $0.createdAt < end }
    }

    private func buildExpenseByCategory(
        from expenseEvents: [BudgetHistoryEvent],
        totalExpense: Double
    ) -> [BudgetCategoryStatLine] {
        var amountsByTitle: [String: Double] = [:]

        for event in expenseEvents {
            let title = event.categoryTitleSnapshot ?? event.categoryType?.title ?? "Без категории"
            amountsByTitle[title, default: 0] += event.amount
        }

        return amountsByTitle
            .map { title, amount in
                BudgetCategoryStatLine(
                    id: title,
                    title: title,
                    amount: roundToCents(amount),
                    share: totalExpense > 0 ? amount / totalExpense : 0
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    private func buildExpenseSubcategoriesByCategory(
        from expenseEvents: [BudgetHistoryEvent],
        totalExpense: Double
    ) -> [BudgetSubcategoryStatSection] {
        struct SubcategoryAccumulator {
            var title: String
            var iconName: String
            var amount: Double
        }

        struct CategoryAccumulator {
            var id: String
            var title: String
            var amount: Double
            var subcategories: [String: SubcategoryAccumulator]
        }

        var categories: [String: CategoryAccumulator] = [:]

        for event in expenseEvents {
            let categoryID = event.categoryType?.rawValue
                ?? event.categoryTitleSnapshot
                ?? "uncategorized"
            let categoryTitle = event.categoryTitleSnapshot ?? event.categoryType?.title ?? "Без категории"
            let subcategoryID = event.subcategoryID?.uuidString
                ?? [categoryID, event.subcategoryNameSnapshot]
                    .compactMap { $0 }
                    .joined(separator: "::")
            let title = event.subcategoryNameSnapshot ?? "Без карточки"
            let iconName = event.displayIconName

            var category = categories[categoryID] ?? CategoryAccumulator(
                id: categoryID,
                title: categoryTitle,
                amount: 0,
                subcategories: [:]
            )
            let subcategory = category.subcategories[subcategoryID]
                ?? SubcategoryAccumulator(title: title, iconName: iconName, amount: 0)

            category.amount += event.amount
            category.subcategories[subcategoryID] = SubcategoryAccumulator(
                title: subcategory.title,
                iconName: subcategory.iconName,
                amount: subcategory.amount + event.amount
            )
            categories[categoryID] = category
        }

        return categories.values
            .map { category in
                let subcategories = category.subcategories
                    .map { key, subcategory in
                        BudgetSubcategoryStatLine(
                            id: key,
                            title: subcategory.title,
                            iconName: subcategory.iconName,
                            amount: roundToCents(subcategory.amount),
                            share: totalExpense > 0 ? subcategory.amount / totalExpense : 0
                        )
                    }
                    .sorted { $0.amount > $1.amount }

                return BudgetSubcategoryStatSection(
                    id: category.id,
                    title: category.title,
                    amount: roundToCents(category.amount),
                    share: totalExpense > 0 ? category.amount / totalExpense : 0,
                    subcategories: subcategories
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func roundToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
