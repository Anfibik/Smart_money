import XCTest

final class BudgetStatisticsServiceTests: XCTestCase {
    private var calendar: Calendar!
    private var service: BudgetStatisticsService!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        service = BudgetStatisticsService(calendar: calendar)
    }

    func testMonthSummaryExcludesTransfersFromFinancialStatistics() {
        let foodID = UUID()
        let events = [
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: 5, hour: 10),
                type: .income,
                amount: 1000,
                currencyCode: "UAH"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: 6, hour: 12),
                type: .expense,
                amount: 200,
                currencyCode: "UAH",
                categoryType: .essentials,
                categoryTitleSnapshot: "Основные",
                subcategoryID: foodID,
                subcategoryNameSnapshot: "Питание",
                iconNameSnapshot: "fork.knife"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: 6, hour: 14),
                type: .transferFromFreeCapital,
                amount: 50,
                currencyCode: "UAH",
                categoryType: .essentials,
                categoryTitleSnapshot: "Основные",
                subcategoryID: foodID,
                subcategoryNameSnapshot: "Питание",
                iconNameSnapshot: "fork.knife"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: 7, hour: 9),
                type: .currencyConversion,
                amount: 100,
                currencyCode: "USD",
                categoryType: .savings,
                categoryTitleSnapshot: "Финансы",
                subcategoryID: UUID(),
                subcategoryNameSnapshot: "Валюта",
                iconNameSnapshot: "dollarsign.arrow.circlepath",
                counterpartyNameSnapshot: "4 150,00 ₴, курс 41.5"
            )
        ]

        let periodEvents = service.eventsForSelectedPeriod(
            from: events,
            mode: .month,
            selectedMonth: HistoryMonthOption(year: 2026, month: 3),
            selectedYear: nil,
            now: makeDate(year: 2026, month: 3, day: 10)
        )
        let summary = service.buildSummary(from: periodEvents)

        XCTAssertEqual(periodEvents.count, 4)
        XCTAssertEqual(summary.totalIncome, 1000, accuracy: 0.0001)
        XCTAssertEqual(summary.totalExpense, 200, accuracy: 0.0001)
        XCTAssertEqual(summary.netResult, 800, accuracy: 0.0001)
        XCTAssertEqual(summary.transferOperationsCount, 2)
        XCTAssertEqual(summary.operationCount, 4)
        XCTAssertEqual(summary.expenseByCategory.first?.title, "Основные")
        XCTAssertEqual(summary.expenseSubcategoriesByCategory.first?.title, "Основные")
        XCTAssertEqual(summary.expenseSubcategoriesByCategory.first?.subcategories.first?.title, "Питание")
        let foodAmount = summary.expenseSubcategoriesByCategory.first?.subcategories.first?.amount
        XCTAssertEqual(foodAmount ?? 0, 200, accuracy: 0.0001)
    }

    func testYearSummaryAggregatesAcrossSelectedCalendarYear() {
        let events = [
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2025, month: 12, day: 31, hour: 23),
                type: .expense,
                amount: 75,
                currencyCode: "UAH",
                categoryType: .wants,
                categoryTitleSnapshot: "Желаемые",
                subcategoryNameSnapshot: "Хобби",
                iconNameSnapshot: "gamecontroller.fill"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 1, day: 8, hour: 9),
                type: .income,
                amount: 2000,
                currencyCode: "UAH"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 2, day: 2, hour: 18),
                type: .expense,
                amount: 300,
                currencyCode: "UAH",
                categoryType: .essentials,
                categoryTitleSnapshot: "Основные",
                subcategoryNameSnapshot: "Жилье",
                iconNameSnapshot: "house.fill"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 11, day: 14, hour: 13),
                type: .expense,
                amount: 500,
                currencyCode: "UAH",
                categoryType: .savings,
                categoryTitleSnapshot: "Накопления",
                subcategoryNameSnapshot: "Подушка",
                iconNameSnapshot: "shield.fill"
            )
        ]

        let periodEvents = service.eventsForSelectedPeriod(
            from: events,
            mode: .year,
            selectedMonth: nil,
            selectedYear: 2026,
            now: makeDate(year: 2026, month: 11, day: 20)
        )
        let summary = service.buildSummary(from: periodEvents)

        XCTAssertEqual(periodEvents.count, 3)
        XCTAssertEqual(summary.totalIncome, 2000, accuracy: 0.0001)
        XCTAssertEqual(summary.totalExpense, 800, accuracy: 0.0001)
        XCTAssertEqual(summary.largestExpense, 500, accuracy: 0.0001)
        XCTAssertEqual(summary.expenseSubcategoriesByCategory.map(\.title), ["Накопления", "Основные"])
    }

    func testSubcategoryStatisticsIncludeAllExpenseCardsGroupedByCategory() {
        let events = (1...6).map { index in
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: index),
                type: .expense,
                amount: Double(index * 10),
                currencyCode: "UAH",
                categoryType: .essentials,
                categoryTitleSnapshot: "Основные",
                subcategoryID: UUID(),
                subcategoryNameSnapshot: "Карточка \(index)",
                iconNameSnapshot: "creditcard.fill"
            )
        }

        let periodEvents = service.eventsForSelectedPeriod(
            from: events,
            mode: .month,
            selectedMonth: HistoryMonthOption(year: 2026, month: 3),
            selectedYear: nil,
            now: makeDate(year: 2026, month: 3, day: 10)
        )
        let summary = service.buildSummary(from: periodEvents)

        XCTAssertEqual(summary.expenseSubcategoriesByCategory.count, 1)
        XCTAssertEqual(summary.expenseSubcategoriesByCategory.first?.subcategories.count, 6)
        XCTAssertEqual(summary.expenseSubcategoriesByCategory.first?.subcategories.first?.title, "Карточка 6")
    }

    func testAvailableMonthsAndYearsBuildContinuousSelections() {
        let events = [
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2025, month: 11, day: 10),
                type: .income,
                amount: 10,
                currencyCode: "UAH"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 2, day: 10),
                type: .expense,
                amount: 10,
                currencyCode: "UAH",
                categoryType: .essentials,
                categoryTitleSnapshot: "Основные",
                subcategoryNameSnapshot: "Питание",
                iconNameSnapshot: "fork.knife"
            )
        ]

        let months = service.availableMonths(
            from: events,
            now: makeDate(year: 2026, month: 3, day: 1)
        )
        let years = service.availableYears(
            from: events,
            now: makeDate(year: 2026, month: 3, day: 1)
        )

        XCTAssertEqual(months.first, HistoryMonthOption(year: 2026, month: 3))
        XCTAssertEqual(months.last, HistoryMonthOption(year: 2025, month: 11))
        XCTAssertEqual(years, [2026, 2025])
    }

    func testDashboardStatisticsUseCurrentPeriodAndKeepCurrencySeparate() throws {
        let now = makeDate(year: 2026, month: 3, day: 10)
        let events = [
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 1, day: 5),
                type: .income,
                amount: 500,
                currencyCode: "UAH"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: 2),
                type: .income,
                amount: 1_000,
                currencyCode: "UAH"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: 3),
                type: .expense,
                amount: 200,
                currencyCode: "UAH"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: 4),
                type: .categoryReallocation,
                amount: 400,
                currencyCode: "UAH"
            ),
            BudgetHistoryEvent(
                createdAt: makeDate(year: 2026, month: 3, day: 5),
                type: .expense,
                amount: 10,
                currencyCode: "USD"
            )
        ]
        let regularCard = makeCardBalance(
            systemKey: .emergencyFund,
            remainingAmount: 2_500
        )
        let debtCard = makeCardBalance(
            systemKey: .debt,
            maxLimit: 1_000,
            spentAmount: 200,
            remainingAmount: 400
        )
        let currencyCard = makeCardBalance(
            systemKey: .currency,
            currencyCode: "USD",
            remainingAmount: 25
        )
        let balanceState = DashboardBalanceState(
            bankAmount: 100,
            cards: [regularCard, debtCard, currencyCard]
        )

        let month = service.buildDashboardStatistics(
            from: events,
            balanceState: balanceState,
            currencyCode: "UAH",
            period: .month,
            now: now
        )
        let year = service.buildDashboardStatistics(
            from: events,
            balanceState: balanceState,
            currencyCode: "UAH",
            period: .year,
            now: now
        )

        XCTAssertEqual(month.totalIncome, 1_000, accuracy: 0.0001)
        XCTAssertEqual(month.totalExpense, 200, accuracy: 0.0001)
        XCTAssertEqual(month.closingBalance, 3_000, accuracy: 0.0001)
        XCTAssertEqual(month.openingBalance, 2_200, accuracy: 0.0001)
        XCTAssertEqual(month.outstandingDebt, 800, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(month.currencyBalances.first).currencyCode, "USD")
        XCTAssertEqual(try XCTUnwrap(month.currencyBalances.first).amount, 25, accuracy: 0.0001)

        XCTAssertEqual(year.totalIncome, 1_500, accuracy: 0.0001)
        XCTAssertEqual(year.totalExpense, 200, accuracy: 0.0001)
        XCTAssertEqual(year.openingBalance, 1_700, accuracy: 0.0001)
    }

    private func makeCardBalance(
        systemKey: SystemSubcategoryKey,
        maxLimit: Double? = nil,
        spentAmount: Double = 0,
        currencyCode: String = "UAH",
        remainingAmount: Double
    ) -> DashboardCardBalance {
        DashboardCardBalance(
            systemKey: systemKey,
            currencyCode: currencyCode,
            remainingAmount: remainingAmount,
            maxLimit: maxLimit,
            minLimit: nil,
            spentAmount: spentAmount,
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }
}
