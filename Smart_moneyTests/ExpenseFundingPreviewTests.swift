import XCTest
@testable import Smart_money

@MainActor
final class ExpenseFundingPreviewTests: XCTestCase {
    func testCustomCardCanBeCreatedWithoutOptionalMinimum() throws {
        let viewModel = makeViewModel(
            subcategories: [
                makeSubcategory(id: UUID(), name: "Existing", percentage: 50)
            ]
        )

        let result = viewModel.addCustomSubcategory(
            categoryType: .essentials,
            name: "Optional minimum",
            iconName: "creditcard.fill",
            percentage: 25,
            minLimit: 0,
            maxLimit: 0,
            priority: .low,
            requiresMinimumAmount: false
        )

        let id = try result.get()
        let card = try allocation(in: viewModel, subcategoryID: id)
        XCTAssertNil(card.minLimit)
        XCTAssertFalse(card.requiresMinimumAmount)
    }

    func testCustomCardRejectsMissingRequiredMinimum() {
        let viewModel = makeViewModel(
            subcategories: [
                makeSubcategory(id: UUID(), name: "Existing", percentage: 50)
            ]
        )

        let result = viewModel.addCustomSubcategory(
            categoryType: .essentials,
            name: "Required minimum",
            iconName: "creditcard.fill",
            percentage: 25,
            minLimit: 0,
            maxLimit: 0,
            priority: .low,
            requiresMinimumAmount: true
        )

        guard case .failure(.invalidParameters) = result else {
            return XCTFail("Expected a missing mandatory minimum to be rejected")
        }
    }

    func testDisablingRequirementKeepsExistingMinimumAmount() throws {
        let cardID = UUID()
        let card = Smart_money.Subcategory(
            id: cardID,
            name: "Editable",
            percentage: 50,
            minLimit: 100,
            requiresMinimumAmount: true,
            priority: Smart_money.SubcategoryPriorityLevel.low.rawValue
        )
        let viewModel = makeViewModel(subcategories: [card])

        viewModel.updateSubcategory(
            categoryType: .essentials,
            subcategoryID: cardID,
            name: "Editable",
            iconName: card.iconName,
            percentage: 50,
            minLimit: 100,
            maxLimit: 0,
            priority: .low,
            requiresMinimumAmount: false
        )

        let updated = try allocation(in: viewModel, subcategoryID: cardID)
        XCTAssertFalse(updated.requiresMinimumAmount)
        XCTAssertEqual(updated.minLimit, 100)
    }

    func testPermanentSystemCardRequirementCannotBeDisabledByUpdate() throws {
        let housingID = UUID()
        let housing = Smart_money.Subcategory(
            id: housingID,
            name: "Жилье",
            isSystem: true,
            systemKey: .housing,
            percentage: 50,
            minLimit: 100,
            requiresMinimumAmount: false,
            priority: Smart_money.SubcategoryPriorityLevel.high.rawValue
        )
        let viewModel = makeViewModel(subcategories: [housing])

        viewModel.updateSubcategory(
            categoryType: .essentials,
            subcategoryID: housingID,
            name: housing.name,
            iconName: housing.iconName,
            percentage: 50,
            minLimit: 100,
            maxLimit: 0,
            priority: .high,
            requiresMinimumAmount: false
        )

        let updated = try allocation(in: viewModel, subcategoryID: housingID)
        XCTAssertTrue(updated.requiresMinimumAmount)
    }

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

    func testAddCustomSubcategoryRollsBackEveryMutationWhenManualCoverageIsIncomplete() throws {
        let donorID = UUID()
        let viewModel = makeViewModel(
            subcategories: [
                makeSubcategory(
                    id: donorID,
                    name: "Donor",
                    percentage: 50,
                    minLimit: 500
                )
            ],
            categoryPercentage: 80
        )
        let donorBefore = try allocation(in: viewModel, subcategoryID: donorID)
        let bankBefore = viewModel.distribution.bankAmount
        let categoryCountBefore = viewModel.settings.categories[0].subcategories.count

        let result = viewModel.addCustomSubcategoryWithManualForcedCoverage(
            categoryType: .essentials,
            name: "New card",
            iconName: "creditcard.fill",
            percentage: 20,
            minLimit: 1_000,
            maxLimit: 0,
            priority: .low,
            allocations: [donorID: 100]
        )

        guard case .failure(.invalidManualAllocation) = result else {
            return XCTFail("Expected incomplete manual coverage to be rejected")
        }

        let donorAfter = try allocation(in: viewModel, subcategoryID: donorID)
        XCTAssertEqual(donorAfter.allocatedAmount, donorBefore.allocatedAmount, accuracy: 0.0001)
        XCTAssertEqual(donorAfter.remainingAmount, donorBefore.remainingAmount, accuracy: 0.0001)
        XCTAssertEqual(donorAfter.monthlyIncomeAmount, donorBefore.monthlyIncomeAmount, accuracy: 0.0001)
        XCTAssertEqual(donorAfter.monthlyOtherIncomingAmount, donorBefore.monthlyOtherIncomingAmount, accuracy: 0.0001)
        XCTAssertEqual(donorAfter.monthlyOtherOutgoingAmount, donorBefore.monthlyOtherOutgoingAmount, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, bankBefore, accuracy: 0.0001)
        XCTAssertEqual(viewModel.settings.categories[0].subcategories.count, categoryCountBefore)
        XCTAssertFalse(
            viewModel.settings.categories[0].subcategories.contains(where: { $0.name == "New card" })
        )
        XCTAssertTrue(viewModel.historyEvents.isEmpty)
    }

    func testAddCustomSubcategoryCommitsMoneyAndHistoryOnlyAfterCompleteCoverage() throws {
        let donorID = UUID()
        let viewModel = makeViewModel(
            subcategories: [
                makeSubcategory(
                    id: donorID,
                    name: "Donor",
                    percentage: 50,
                    minLimit: 500
                )
            ],
            categoryPercentage: 80
        )

        let result = viewModel.addCustomSubcategoryWithManualForcedCoverage(
            categoryType: .essentials,
            name: "New card",
            iconName: "creditcard.fill",
            percentage: 20,
            minLimit: 1_000,
            maxLimit: 0,
            priority: .low,
            allocations: [donorID: 500]
        )

        let newSubcategoryID = try result.get()
        let newSubcategory = try allocation(in: viewModel, subcategoryID: newSubcategoryID)
        let donor = try allocation(in: viewModel, subcategoryID: donorID)
        let domesticTotal = viewModel.distribution.bankAmount
            + viewModel.distribution.categoryAllocations.reduce(0) { $0 + $1.allocatedAmount }

        XCTAssertEqual(newSubcategory.allocatedAmount, 1_000, accuracy: 0.0001)
        XCTAssertEqual(newSubcategory.remainingAmount, 1_000, accuracy: 0.0001)
        XCTAssertEqual(donor.allocatedAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, 0, accuracy: 0.0001)
        XCTAssertEqual(domesticTotal, 1_000, accuracy: 0.0001)
        XCTAssertEqual(viewModel.settings.categories[0].subcategories.count, 2)
        XCTAssertEqual(viewModel.historyEvents.count, 3)
        XCTAssertEqual(
            viewModel.historyEvents.filter { $0.type == .categoryReallocation }.count,
            2
        )
        XCTAssertEqual(
            viewModel.historyEvents.filter { $0.type == .transferFromFreeCapital }.count,
            1
        )
    }

    private func makeViewModel(
        subcategories: [Smart_money.Subcategory],
        categoryPercentage: Double = 100,
        income: Double = 1_000
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
            percentage: categoryPercentage,
            subcategories: subcategories
        )

        return Smart_money.BudgetViewModel(
            income: income,
            settings: Smart_money.BudgetSettings(categories: [category], currencyCode: "UAH"),
            persistenceService: persistenceService,
            allocationEngine: Smart_money.BudgetAllocationEngine(),
            historyStorage: historyStorage
        )
    }

    private func makeSubcategory(
        id: UUID,
        name: String,
        percentage: Double = 50,
        minLimit: Double? = nil
    ) -> Smart_money.Subcategory {
        Smart_money.Subcategory(
            id: id,
            name: name,
            percentage: percentage,
            minLimit: minLimit,
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
