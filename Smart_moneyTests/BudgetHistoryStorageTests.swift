import XCTest

final class BudgetHistoryStorageTests: XCTestCase {
    func testAppendLoadAndClearHistoryFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = BudgetHistoryStorage(
            fileManager: .default,
            directoryURL: directoryURL,
            fileName: "history.json"
        )

        let incomeEvent = BudgetHistoryEvent(
            createdAt: Date(timeIntervalSince1970: 100),
            type: .income,
            amount: 1200,
            currencyCode: "UAH"
        )
        let expenseEvent = BudgetHistoryEvent(
            createdAt: Date(timeIntervalSince1970: 200),
            type: .expense,
            amount: 300,
            currencyCode: "UAH",
            categoryType: .essentials,
            categoryTitleSnapshot: "Основные",
            subcategoryNameSnapshot: "Питание",
            iconNameSnapshot: "fork.knife"
        )

        storage.append(incomeEvent)
        storage.append(expenseEvent)

        let loaded = storage.loadEvents()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].type, .income)
        XCTAssertEqual(loaded[1].type, .expense)

        storage.clear()

        XCTAssertTrue(storage.loadEvents().isEmpty)
    }
}
