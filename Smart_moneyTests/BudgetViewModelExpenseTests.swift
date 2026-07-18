import XCTest

@MainActor
final class BudgetViewModelExpenseTests: XCTestCase {
    func testExpenseFullyCoveredBySelectedCard() throws {
        let targetID = UUID()
        let donorID = UUID()
        let viewModel = makeViewModel(
            income: 1_000,
            categories: [
                makeEssentialsCategory(
                    subcategories: [
                        makeSubcategory(id: targetID, name: "Target", percentage: 50),
                        makeSubcategory(id: donorID, name: "Donor", percentage: 50)
                    ]
                )
            ]
        )

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 200,
            fundingStrategy: .categoryFirst
        )

        let target = try allocation(in: viewModel, subcategoryID: targetID)
        let donor = try allocation(in: viewModel, subcategoryID: donorID)
        XCTAssertEqual(target.allocatedAmount, 500, accuracy: 0.0001)
        XCTAssertEqual(target.spentAmount, 200, accuracy: 0.0001)
        XCTAssertEqual(target.remainingAmount, 300, accuracy: 0.0001)
        XCTAssertEqual(donor.allocatedAmount, 500, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.historyEvents.count, 1)
        XCTAssertEqual(viewModel.historyEvents.first?.type, .expense)
    }

    func testExpenseUsesAutomaticCategoryReallocationBeforeFreeCapital() throws {
        let targetID = UUID()
        let donorID = UUID()
        let viewModel = makeViewModel(
            income: 1_000,
            categories: [
                makeEssentialsCategory(
                    subcategories: [
                        makeSubcategory(id: targetID, name: "Target", percentage: 50),
                        makeSubcategory(id: donorID, name: "Donor", percentage: 50, minLimit: 100)
                    ]
                )
            ]
        )

        let preview = try XCTUnwrap(
            viewModel.expenseFundingPreview(
                categoryType: .essentials,
                subcategoryID: targetID,
                amount: 700,
                fundingStrategy: .categoryFirst
            )
        )

        XCTAssertEqual(preview.immediateLines.map(\.kind), [.selectedCard, .automaticCategoryCard])
        XCTAssertEqual(preview.immediateLines.map(\.amount), [500, 200])

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 700,
            fundingStrategy: .categoryFirst
        )

        let target = try allocation(in: viewModel, subcategoryID: targetID)
        let donor = try allocation(in: viewModel, subcategoryID: donorID)
        XCTAssertEqual(target.allocatedAmount, 700, accuracy: 0.0001)
        XCTAssertEqual(target.spentAmount, 700, accuracy: 0.0001)
        XCTAssertEqual(donor.allocatedAmount, 300, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.historyEvents.map(\.type), [.expense, .categoryReallocation])
    }

    func testExpenseUsesFreeCapitalWhenCategoryIsShort() throws {
        let targetID = UUID()
        let viewModel = makeViewModel(
            income: 1_000,
            categories: [
                makeEssentialsCategory(
                    subcategories: [
                        makeSubcategory(id: targetID, name: "Target", percentage: 50)
                    ]
                )
            ]
        )

        let preview = try XCTUnwrap(
            viewModel.expenseFundingPreview(
                categoryType: .essentials,
                subcategoryID: targetID,
                amount: 700,
                fundingStrategy: .categoryFirst
            )
        )

        XCTAssertEqual(preview.immediateLines.map(\.kind), [.selectedCard, .freeCapital])
        XCTAssertEqual(preview.immediateLines.map(\.amount), [500, 200])
        XCTAssertTrue(preview.canPay)

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 700,
            fundingStrategy: .categoryFirst
        )

        let target = try allocation(in: viewModel, subcategoryID: targetID)
        XCTAssertEqual(target.allocatedAmount, 700, accuracy: 0.0001)
        XCTAssertEqual(target.spentAmount, 700, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, 300, accuracy: 0.0001)
        XCTAssertEqual(viewModel.historyEvents.count, 1)
        XCTAssertEqual(viewModel.historyEvents.first?.type, .expense)
    }

    func testExpenseWithoutCoverageLeavesStateUnchangedWhenMoneyIsInsufficient() throws {
        let targetID = UUID()
        let viewModel = makeViewModel(
            income: 1_000,
            categories: [
                makeEssentialsCategory(
                    subcategories: [
                        makeSubcategory(id: targetID, name: "Target", percentage: 50)
                    ]
                )
            ]
        )

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 1_200,
            fundingStrategy: .categoryFirst
        )

        let target = try allocation(in: viewModel, subcategoryID: targetID)
        XCTAssertEqual(target.allocatedAmount, 500, accuracy: 0.0001)
        XCTAssertEqual(target.spentAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(target.remainingAmount, 500, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, 500, accuracy: 0.0001)
        XCTAssertTrue(viewModel.historyEvents.isEmpty)
    }

    func testUndoExpenseRestoresAllocatedSpentAndFreeCapital() throws {
        let targetID = UUID()
        let viewModel = makeViewModel(
            income: 1_000,
            categories: [
                makeEssentialsCategory(
                    subcategories: [
                        makeSubcategory(id: targetID, name: "Target", percentage: 50)
                    ]
                )
            ]
        )

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 700,
            fundingStrategy: .categoryFirst
        )

        let eventID = try XCTUnwrap(viewModel.historyEvents.first?.id)
        XCTAssertTrue(viewModel.revertHistoryEvent(id: eventID))

        let target = try allocation(in: viewModel, subcategoryID: targetID)
        XCTAssertEqual(target.allocatedAmount, 500, accuracy: 0.0001)
        XCTAssertEqual(target.spentAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(target.remainingAmount, 500, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, 500, accuracy: 0.0001)
        XCTAssertTrue(viewModel.historyEvents.isEmpty)
    }

    private func makeViewModel(
        income: Double,
        categories: [ExpenseCategory],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> BudgetViewModel {
        let suiteName = "BudgetViewModelExpenseTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let persistenceService = PersistenceService(
            defaults: defaults,
            storageKey: "budget-state-\(UUID().uuidString)"
        )
        let historyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BudgetViewModelExpenseTests-\(UUID().uuidString)", isDirectory: true)
        let historyStorage = BudgetHistoryStorage(
            directoryURL: historyDirectory,
            fileName: "history.json"
        )

        return BudgetViewModel(
            income: income,
            settings: BudgetSettings(categories: categories, currencyCode: "UAH"),
            persistenceService: persistenceService,
            allocationEngine: BudgetAllocationEngine(),
            historyStorage: historyStorage
        )
    }

    private func makeEssentialsCategory(subcategories: [Subcategory]) -> ExpenseCategory {
        ExpenseCategory(
            type: .essentials,
            percentage: 100,
            subcategories: subcategories
        )
    }

    private func makeSubcategory(
        id: UUID,
        name: String,
        percentage: Double,
        minLimit: Double? = nil
    ) -> Subcategory {
        Subcategory(
            id: id,
            name: name,
            percentage: percentage,
            minLimit: minLimit,
            priority: SubcategoryPriorityLevel.low.rawValue
        )
    }

    private func allocation(
        in viewModel: BudgetViewModel,
        subcategoryID: UUID,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> SubcategoryAllocation {
        let allocations = viewModel.distribution.categoryAllocations
            .flatMap(\.subcategoryAllocations)
        return try XCTUnwrap(
            allocations.first(where: { $0.id == subcategoryID }),
            file: file,
            line: line
        )
    }
}
