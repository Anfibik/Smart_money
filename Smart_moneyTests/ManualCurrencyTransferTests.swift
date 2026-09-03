import XCTest
@testable import Smart_money

@MainActor
final class ManualCurrencyTransferTests: XCTestCase {
    func testForeignCurrencyCatalogContainsSupportedCommonCurrencies() {
        XCTAssertEqual(
            Smart_money.ForeignCurrencyType.allCases.map(\.rawValue),
            ["USD", "EUR", "GBP", "CHF", "PLN", "CAD", "JPY", "CNY", "RUB"]
        )
        XCTAssertEqual(Smart_money.AppCurrencyFormatter.symbol(for: "GBP"), "£")
        XCTAssertEqual(Smart_money.AppCurrencyFormatter.symbol(for: "PLN"), "zł")
        XCTAssertEqual(Smart_money.AppCurrencyFormatter.symbol(for: "RUB"), "₽")
        XCTAssertEqual(
            Smart_money.AppCurrencyFormatter.string(3_925, currencyCode: "CAD"),
            "3 925,00 C$"
        )
    }

    func testManualCardCurrencyUpdatesWithoutChangingBalance() throws {
        let currencyCardID = UUID()
        let currencyCard = Smart_money.Subcategory(
            id: currencyCardID,
            name: "Валюта",
            isSystem: true,
            systemKey: .currency,
            percentage: 0,
            fundingMode: .manualOnly,
            balanceCurrencyCode: Smart_money.ForeignCurrencyType.usd.rawValue
        )
        let viewModel = makeViewModel(
            income: 0,
            categories: [
                Smart_money.ExpenseCategory(
                    type: .savings,
                    percentage: 0,
                    subcategories: [currencyCard]
                )
            ]
        )
        viewModel.depositToManualCard(
            categoryType: .savings,
            subcategoryID: currencyCardID,
            amount: 250
        )

        viewModel.updateManualCardCurrency(
            categoryType: .savings,
            subcategoryID: currencyCardID,
            currency: .rub
        )

        let allocation = try allocation(in: viewModel, subcategoryID: currencyCardID)
        XCTAssertEqual(allocation.balanceCurrencyCode, "RUB")
        XCTAssertEqual(allocation.remainingAmount, 250, accuracy: 0.0001)
    }

    func testDepositFromFreeCapitalUpdatesBothBalancesAndCanBeUndone() throws {
        let currencyCardID = UUID()
        let currencyCard = Smart_money.Subcategory(
            id: currencyCardID,
            name: "Валюта",
            isSystem: true,
            systemKey: .currency,
            iconName: Smart_money.SystemSubcategoryKey.currency.defaultIconName,
            percentage: 0,
            priority: Smart_money.SubcategoryPriorityLevel.medium.rawValue,
            fundingMode: .manualOnly,
            balanceCurrencyCode: Smart_money.ForeignCurrencyType.usd.rawValue
        )
        let viewModel = makeViewModel(
            income: 1_000,
            categories: [
                Smart_money.ExpenseCategory(
                    type: .savings,
                    percentage: 0,
                    subcategories: [currencyCard]
                )
            ]
        )

        XCTAssertEqual(viewModel.bankAvailableAmount, 1_000, accuracy: 0.0001)

        let succeeded = viewModel.depositToManualCardFromFreeCapital(
            categoryType: .savings,
            subcategoryID: currencyCardID,
            foreignAmount: 10,
            hryvniaAmount: 415,
            exchangeRateToUAH: 41.5
        )

        XCTAssertTrue(succeeded)
        XCTAssertEqual(viewModel.bankAvailableAmount, 585, accuracy: 0.0001)
        XCTAssertEqual(
            try allocation(in: viewModel, subcategoryID: currencyCardID).remainingAmount,
            10,
            accuracy: 0.0001
        )

        let event = try XCTUnwrap(viewModel.historyEvents.first)
        XCTAssertEqual(event.type, .transferFromFreeCapital)
        XCTAssertEqual(event.amount, 415, accuracy: 0.0001)
        XCTAssertEqual(event.currencyCode, "UAH")
        XCTAssertTrue(event.counterpartyNameSnapshot?.contains("10,00 $") == true)
        XCTAssertTrue(viewModel.revertHistoryEvent(id: event.id))
        XCTAssertEqual(viewModel.bankAvailableAmount, 1_000, accuracy: 0.0001)
        XCTAssertEqual(
            try allocation(in: viewModel, subcategoryID: currencyCardID).remainingAmount,
            0,
            accuracy: 0.0001
        )
    }

    func testDepositFromFreeCapitalRejectsInsufficientBalance() throws {
        let currencyCardID = UUID()
        let currencyCard = Smart_money.Subcategory(
            id: currencyCardID,
            name: "Валюта",
            isSystem: true,
            systemKey: .currency,
            percentage: 0,
            fundingMode: .manualOnly,
            balanceCurrencyCode: Smart_money.ForeignCurrencyType.eur.rawValue
        )
        let viewModel = makeViewModel(
            income: 100,
            categories: [
                Smart_money.ExpenseCategory(
                    type: .savings,
                    percentage: 0,
                    subcategories: [currencyCard]
                )
            ]
        )

        XCTAssertFalse(
            viewModel.depositToManualCardFromFreeCapital(
                categoryType: .savings,
                subcategoryID: currencyCardID,
                foreignAmount: 10,
                hryvniaAmount: 450,
                exchangeRateToUAH: 45
            )
        )
        XCTAssertEqual(viewModel.bankAvailableAmount, 100, accuracy: 0.0001)
        XCTAssertEqual(
            try allocation(in: viewModel, subcategoryID: currencyCardID).remainingAmount,
            0,
            accuracy: 0.0001
        )
        XCTAssertTrue(viewModel.historyEvents.isEmpty)
    }

    func testManualCurrencyCardCannotFundAnotherCardExpense() throws {
        let goalCardID = UUID()
        let currencyCardID = UUID()
        let goalCard = Smart_money.Subcategory(
            id: goalCardID,
            name: "Цель",
            isSystem: true,
            systemKey: .goal,
            percentage: 100,
            priority: Smart_money.SubcategoryPriorityLevel.medium.rawValue
        )
        let currencyCard = Smart_money.Subcategory(
            id: currencyCardID,
            name: "Валюта",
            isSystem: true,
            systemKey: .currency,
            percentage: 0,
            fundingMode: .manualOnly,
            balanceCurrencyCode: Smart_money.ForeignCurrencyType.usd.rawValue
        )
        let viewModel = makeViewModel(
            income: 0,
            categories: [
                Smart_money.ExpenseCategory(
                    type: .savings,
                    percentage: 100,
                    subcategories: [goalCard, currencyCard]
                )
            ]
        )
        viewModel.depositToManualCard(
            categoryType: .savings,
            subcategoryID: currencyCardID,
            amount: 100
        )
        let historyCountBeforeExpense = viewModel.historyEvents.count

        let preview = try XCTUnwrap(
            viewModel.expenseFundingPreview(
                categoryType: .savings,
                subcategoryID: goalCardID,
                amount: 50,
                fundingStrategy: .categoryFirst
            )
        )

        XCTAssertFalse(preview.canPay)
        XCTAssertEqual(preview.uncoveredAmount, 50, accuracy: 0.0001)
        XCTAssertFalse(
            preview.immediateLines.contains(where: { $0.subcategoryID == currencyCardID })
        )

        viewModel.addExpense(
            categoryType: .savings,
            subcategoryID: goalCardID,
            amount: 50,
            fundingStrategy: .categoryFirst
        )

        XCTAssertEqual(viewModel.historyEvents.count, historyCountBeforeExpense)
        XCTAssertEqual(
            try allocation(in: viewModel, subcategoryID: currencyCardID).remainingAmount,
            100,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try allocation(in: viewModel, subcategoryID: goalCardID).spentAmount,
            0,
            accuracy: 0.0001
        )
    }

    private func makeViewModel(
        income: Double,
        categories: [Smart_money.ExpenseCategory]
    ) -> Smart_money.BudgetViewModel {
        let suiteName = "ManualCurrencyTransferTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let persistenceService = Smart_money.PersistenceService(
            defaults: defaults,
            storageKey: "budget-state-\(UUID().uuidString)"
        )
        let historyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        let historyStorage = Smart_money.BudgetHistoryStorage(
            directoryURL: historyDirectory,
            fileName: "history.json"
        )

        return Smart_money.BudgetViewModel(
            income: income,
            settings: Smart_money.BudgetSettings(
                categories: categories,
                currencyCode: "UAH"
            ),
            persistenceService: persistenceService,
            allocationEngine: Smart_money.BudgetAllocationEngine(),
            historyStorage: historyStorage
        )
    }

    private func allocation(
        in viewModel: Smart_money.BudgetViewModel,
        subcategoryID: UUID
    ) throws -> Smart_money.SubcategoryAllocation {
        try XCTUnwrap(
            viewModel.distribution.categoryAllocations
                .flatMap(\.subcategoryAllocations)
                .first(where: { $0.id == subcategoryID })
        )
    }
}
