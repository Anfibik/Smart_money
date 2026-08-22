import XCTest
@testable import Smart_money

@MainActor
final class ExpenseFundingPreviewTests: XCTestCase {
    func testPreviewUsesActualSelectedCardRemainder() throws {
        let targetID = UUID()
        let donorID = UUID()
        let viewModel = makeViewModel(
            subcategories: [
                makeSubcategory(id: targetID, name: "Target"),
                makeSubcategory(id: donorID, name: "Donor")
            ]
        )

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 175.98,
            fundingStrategy: .categoryFirst
        )

        let target = try allocation(in: viewModel, subcategoryID: targetID)
        XCTAssertEqual(target.remainingAmount, 324.02, accuracy: 0.0001)

        let preview = try XCTUnwrap(
            viewModel.expenseFundingPreview(
                categoryType: .essentials,
                subcategoryID: targetID,
                amount: 824.02,
                fundingStrategy: .categoryFirst
            )
        )

        XCTAssertEqual(preview.immediateLines.map(\.kind), [.selectedCard, .automaticCategoryCard])
        XCTAssertEqual(preview.immediateLines.map(\.amount), [324.02, 500])
        XCTAssertTrue(preview.canPay)
    }

    private func makeViewModel(
        subcategories: [Smart_money.Subcategory]
    ) -> Smart_money.BudgetViewModel {
        let suiteName = "ExpenseFundingPreviewTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let persistenceService = Smart_money.PersistenceService(
            defaults: defaults,
            storageKey: "budget-state-\(UUID().uuidString)"
        )
        let historyStorage = Smart_money.BudgetHistoryStorage(
            directoryURL: FileManager.default.temporaryDirectory
                .appendingPathComponent(suiteName, isDirectory: true),
            fileName: "history.json"
        )
        let category = Smart_money.ExpenseCategory(
            type: .essentials,
            percentage: 100,
            subcategories: subcategories
        )

        return Smart_money.BudgetViewModel(
            income: 1_000,
            settings: Smart_money.BudgetSettings(categories: [category], currencyCode: "UAH"),
            persistenceService: persistenceService,
            allocationEngine: Smart_money.BudgetAllocationEngine(),
            historyStorage: historyStorage
        )
    }

    private func makeSubcategory(
        id: UUID,
        name: String
    ) -> Smart_money.Subcategory {
        Smart_money.Subcategory(
            id: id,
            name: name,
            percentage: 50,
            priority: Smart_money.SubcategoryPriorityLevel.low.rawValue
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
