import Foundation

final class BudgetStatisticsService {
    private let calendar: Calendar
    private let locale: Locale

    init(calendar: Calendar = .current, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
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

    func buildSummary(
        from periodEvents: [BudgetHistoryEvent],
        mode: HistoryPeriodMode,
        selectedMonth: HistoryMonthOption?,
        selectedYear: Int?,
        now: Date = Date()
    ) -> BudgetStatisticsSummary {
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
            topExpenseSubcategories: buildTopExpenseSubcategories(from: expenseEvents, totalExpense: totalExpense),
            timelineBuckets: buildTimelineBuckets(
                from: statisticEvents,
                mode: mode,
                selectedMonth: selectedMonth,
                selectedYear: selectedYear,
                now: now
            )
        )
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

    private func buildTopExpenseSubcategories(
        from expenseEvents: [BudgetHistoryEvent],
        totalExpense: Double
    ) -> [BudgetSubcategoryStatLine] {
        struct Accumulator {
            var title: String
            var iconName: String
            var amount: Double
        }

        var lines: [String: Accumulator] = [:]

        for event in expenseEvents {
            let key = event.subcategoryID?.uuidString
                ?? [event.categoryTitleSnapshot, event.subcategoryNameSnapshot]
                    .compactMap { $0 }
                    .joined(separator: "::")
            let title = event.subcategoryNameSnapshot ?? "Без карточки"
            let iconName = event.displayIconName
            let current = lines[key] ?? Accumulator(title: title, iconName: iconName, amount: 0)
            lines[key] = Accumulator(title: current.title, iconName: current.iconName, amount: current.amount + event.amount)
        }

        return lines
            .map { key, accumulator in
                BudgetSubcategoryStatLine(
                    id: key,
                    title: accumulator.title,
                    iconName: accumulator.iconName,
                    amount: roundToCents(accumulator.amount),
                    share: totalExpense > 0 ? accumulator.amount / totalExpense : 0
                )
            }
            .sorted { $0.amount > $1.amount }
            .prefix(5)
            .map { $0 }
    }

    private func buildTimelineBuckets(
        from statisticEvents: [BudgetHistoryEvent],
        mode: HistoryPeriodMode,
        selectedMonth: HistoryMonthOption?,
        selectedYear: Int?,
        now: Date
    ) -> [BudgetStatisticsBucket] {
        switch mode {
        case .month:
            return buildDailyBuckets(for: statisticEvents, selectedMonth: selectedMonth, now: now)
        case .year:
            return buildMonthlyBucketsForYear(for: statisticEvents, selectedYear: selectedYear, now: now)
        case .allTime:
            return buildMonthlyBucketsForAllTime(for: statisticEvents, now: now)
        }
    }

    private func buildDailyBuckets(
        for events: [BudgetHistoryEvent],
        selectedMonth: HistoryMonthOption?,
        now: Date
    ) -> [BudgetStatisticsBucket] {
        let monthOption = selectedMonth ?? availableMonths(from: events, now: now).first
        guard let monthOption,
              let monthStart = monthOption.startDate(calendar: calendar),
              let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        var eventsByDay: [Int: (income: Double, expense: Double)] = [:]
        for event in events {
            let day = calendar.component(.day, from: event.createdAt)
            var current = eventsByDay[day, default: (0, 0)]
            if event.type == .income {
                current.income += event.amount
            } else if event.type == .expense {
                current.expense += event.amount
            }
            eventsByDay[day] = current
        }

        return dayRange.compactMap { day -> BudgetStatisticsBucket? in
            guard let date = calendar.date(from: DateComponents(year: monthOption.year, month: monthOption.month, day: day)) else {
                return nil
            }
            let values = eventsByDay[day, default: (0, 0)]
            return BudgetStatisticsBucket(
                id: "day-\(day)",
                startDate: date,
                label: "\(day)",
                income: roundToCents(values.income),
                expense: roundToCents(values.expense)
            )
        }
    }

    private func buildMonthlyBucketsForYear(
        for events: [BudgetHistoryEvent],
        selectedYear: Int?,
        now: Date
    ) -> [BudgetStatisticsBucket] {
        let year = selectedYear ?? calendar.component(.year, from: now)
        var valuesByMonth: [Int: (income: Double, expense: Double)] = [:]

        for event in events {
            let month = calendar.component(.month, from: event.createdAt)
            var current = valuesByMonth[month, default: (0, 0)]
            if event.type == .income {
                current.income += event.amount
            } else if event.type == .expense {
                current.expense += event.amount
            }
            valuesByMonth[month] = current
        }

        return (1...12).compactMap { month -> BudgetStatisticsBucket? in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
                return nil
            }
            let values = valuesByMonth[month, default: (0, 0)]
            return BudgetStatisticsBucket(
                id: "year-\(year)-month-\(month)",
                startDate: date,
                label: shortMonthLabel(for: date),
                income: roundToCents(values.income),
                expense: roundToCents(values.expense)
            )
        }
    }

    private func buildMonthlyBucketsForAllTime(
        for events: [BudgetHistoryEvent],
        now: Date
    ) -> [BudgetStatisticsBucket] {
        let monthOptions = availableMonths(from: events, now: now).sorted { lhs, rhs in
            if lhs.year == rhs.year {
                return lhs.month < rhs.month
            }
            return lhs.year < rhs.year
        }

        guard !monthOptions.isEmpty else { return [] }

        var valuesByMonthKey: [String: (income: Double, expense: Double)] = [:]
        for event in events {
            let components = calendar.dateComponents([.year, .month], from: event.createdAt)
            let key = String(format: "%04d-%02d", components.year ?? 0, components.month ?? 1)
            var current = valuesByMonthKey[key, default: (0, 0)]
            if event.type == .income {
                current.income += event.amount
            } else if event.type == .expense {
                current.expense += event.amount
            }
            valuesByMonthKey[key] = current
        }

        return monthOptions.compactMap { option -> BudgetStatisticsBucket? in
            guard let date = option.startDate(calendar: calendar) else { return nil }
            let key = option.id
            let values = valuesByMonthKey[key, default: (0, 0)]
            return BudgetStatisticsBucket(
                id: "all-\(key)",
                startDate: date,
                label: shortMonthYearLabel(for: date),
                income: roundToCents(values.income),
                expense: roundToCents(values.expense)
            )
        }
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func shortMonthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "LLL"
        return formatter.string(from: date).capitalized
    }

    private func shortMonthYearLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "LLL yy"
        return formatter.string(from: date).capitalized
    }

    private func roundToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
