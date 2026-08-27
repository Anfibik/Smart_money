import XCTest
@testable import Smart_money

@MainActor
final class HistoryPresentationTests: XCTestCase {
    func testExpenseHidesLinkedInternalMovementAndShowsIndicator() throws {
        let targetID = UUID()
        let donorID = UUID()
        let viewModel = makeViewModel(targetID: targetID, donorID: donorID)

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 700,
            fundingStrategy: .categoryFirst
        )

        let expense = try XCTUnwrap(viewModel.historyEvents.first { $0.type == .expense })
        let movement = try XCTUnwrap(
            viewModel.historyEvents.first { $0.type == .categoryReallocation }
        )
        let entries = Smart_money.BudgetHistoryPresentation.entries(from: viewModel.historyEvents)

        XCTAssertEqual(movement.parentEventID, expense.id)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].event.id, expense.id)
        XCTAssertEqual(entries[0].internalMovementEventIDs, [movement.id])
        XCTAssertTrue(entries[0].hasInternalMovements)
    }

    func testDeletingExpenseRestoresLinkedInternalMovement() throws {
        let targetID = UUID()
        let donorID = UUID()
        let viewModel = makeViewModel(targetID: targetID, donorID: donorID)
        let targetBefore = try allocation(in: viewModel, subcategoryID: targetID)
        let donorBefore = try allocation(in: viewModel, subcategoryID: donorID)
        let bankBefore = viewModel.distribution.bankAmount

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 700,
            fundingStrategy: .categoryFirst
        )

        let expense = try XCTUnwrap(viewModel.historyEvents.first { $0.type == .expense })
        XCTAssertTrue(viewModel.revertHistoryEvent(id: expense.id))

        let target = try allocation(in: viewModel, subcategoryID: targetID)
        let donor = try allocation(in: viewModel, subcategoryID: donorID)
        XCTAssertEqual(target.allocatedAmount, targetBefore.allocatedAmount, accuracy: 0.0001)
        XCTAssertEqual(target.spentAmount, targetBefore.spentAmount, accuracy: 0.0001)
        XCTAssertEqual(donor.allocatedAmount, donorBefore.allocatedAmount, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, bankBefore, accuracy: 0.0001)
        XCTAssertTrue(viewModel.historyEvents.isEmpty)
    }

    func testHistoryRevertUsesLIFOOrder() throws {
        let targetID = UUID()
        let donorID = UUID()
        let viewModel = makeViewModel(
            targetID: targetID,
            donorID: donorID,
            income: 0
        )

        viewModel.addIncome(1_000)
        let incomeEvent = try XCTUnwrap(viewModel.historyEvents.first { $0.type == .income })

        viewModel.addExpense(
            categoryType: .essentials,
            subcategoryID: targetID,
            amount: 700,
            fundingStrategy: .categoryFirst
        )
        let expenseEvent = try XCTUnwrap(viewModel.historyEvents.first { $0.type == .expense })
        let distributionBeforeRejectedRevert = viewModel.distribution

        XCTAssertFalse(viewModel.canRevertHistoryEvent(id: incomeEvent.id))
        XCTAssertFalse(viewModel.revertHistoryEvent(id: incomeEvent.id))
        XCTAssertEqual(viewModel.distribution, distributionBeforeRejectedRevert)

        XCTAssertTrue(viewModel.canRevertHistoryEvent(id: expenseEvent.id))
        XCTAssertTrue(viewModel.revertHistoryEvent(id: expenseEvent.id))
        XCTAssertTrue(viewModel.canRevertHistoryEvent(id: incomeEvent.id))
        XCTAssertTrue(viewModel.revertHistoryEvent(id: incomeEvent.id))

        XCTAssertTrue(viewModel.historyEvents.isEmpty)
        XCTAssertEqual(viewModel.distribution.income, 0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.distribution.bankAmount, 0, accuracy: 0.0001)
    }

    func testHistoryRevertRemainsAvailableForTodayAndYesterdayOnly() throws {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -1, to: todayStart)
        )
        let twoDaysAgoStart = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -2, to: todayStart)
        )
        let yesterdayEvent = Smart_money.BudgetHistoryEvent(
            createdAt: yesterdayStart.addingTimeInterval(12 * 60 * 60),
            type: .income,
            amount: 0,
            currencyCode: "UAH",
            undoDelta: Smart_money.BudgetOperationDelta()
        )
        let olderEvent = Smart_money.BudgetHistoryEvent(
            createdAt: twoDaysAgoStart.addingTimeInterval(12 * 60 * 60),
            type: .income,
            amount: 0,
            currencyCode: "UAH",
            undoDelta: Smart_money.BudgetOperationDelta()
        )
        let viewModel = makeViewModel(
            targetID: UUID(),
            donorID: UUID(),
            income: 0,
            historyEvents: [olderEvent, yesterdayEvent]
        )

        XCTAssertTrue(viewModel.canRevertHistoryEvent(id: yesterdayEvent.id, now: now))
        XCTAssertFalse(viewModel.canRevertHistoryEvent(id: olderEvent.id, now: now))
        XCTAssertTrue(viewModel.revertHistoryEvent(id: yesterdayEvent.id, now: now))
        XCTAssertFalse(viewModel.canRevertHistoryEvent(id: olderEvent.id, now: now))
        XCTAssertFalse(viewModel.revertHistoryEvent(id: olderEvent.id, now: now))
    }

    func testStandaloneTransferRemainsVisible() {
        let transfer = Smart_money.BudgetHistoryEvent(
            type: .categoryReallocation,
            amount: 250,
            currencyCode: "UAH",
            categoryType: .essentials,
            categoryTitleSnapshot: Smart_money.ExpenseCategoryType.essentials.title,
            subcategoryNameSnapshot: "Питание",
            counterpartyNameSnapshot: "Жилье"
        )

        let entries = Smart_money.BudgetHistoryPresentation.entries(from: [transfer])

        XCTAssertEqual(entries.map(\.event.id), [transfer.id])
        XCTAssertFalse(entries[0].hasInternalMovements)
    }

    func testLegacyInternalMovementIsGroupedWithExpense() {
        let expenseDate = Date()
        let expense = Smart_money.BudgetHistoryEvent(
            createdAt: expenseDate,
            type: .expense,
            amount: 500,
            currencyCode: "UAH",
            categoryType: .essentials,
            categoryTitleSnapshot: Smart_money.ExpenseCategoryType.essentials.title,
            subcategoryNameSnapshot: "Питание"
        )
        let movement = Smart_money.BudgetHistoryEvent(
            createdAt: expenseDate.addingTimeInterval(-0.1),
            type: .categoryReallocation,
            amount: 175,
            currencyCode: "UAH",
            categoryType: .essentials,
            categoryTitleSnapshot: Smart_money.ExpenseCategoryType.essentials.title,
            subcategoryNameSnapshot: "Жилье",
            counterpartyNameSnapshot: "Питание"
        )

        let entries = Smart_money.BudgetHistoryPresentation.entries(from: [movement, expense])

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].event.id, expense.id)
        XCTAssertEqual(entries[0].internalMovementEventIDs, [movement.id])
    }

    private func makeViewModel(
        targetID: UUID,
        donorID: UUID,
        income: Double = 1_000,
        historyEvents: [Smart_money.BudgetHistoryEvent] = []
    ) -> Smart_money.BudgetViewModel {
        let target = Smart_money.Subcategory(
            id: targetID,
            name: "Питание",
            percentage: 50,
            priority: Smart_money.SubcategoryPriorityLevel.low.rawValue
        )
        let donor = Smart_money.Subcategory(
            id: donorID,
            name: "Жилье",
            percentage: 50,
            minLimit: 100,
            priority: Smart_money.SubcategoryPriorityLevel.low.rawValue
        )
        let category = Smart_money.ExpenseCategory(
            type: .essentials,
            percentage: 100,
            subcategories: [target, donor]
        )
        let suiteName = "HistoryPresentationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        let historyStorage = Smart_money.BudgetHistoryStorage(
            directoryURL: directory,
            fileName: "history.json"
        )
        historyStorage.replaceAll(historyEvents)

        return Smart_money.BudgetViewModel(
            income: income,
            settings: Smart_money.BudgetSettings(
                categories: [category],
                currencyCode: "UAH"
            ),
            persistenceService: Smart_money.PersistenceService(
                defaults: defaults,
                storageKey: "budget-state"
            ),
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
                .first { $0.id == subcategoryID }
        )
    }
}
