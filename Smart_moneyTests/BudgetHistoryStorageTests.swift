import XCTest
@testable import Smart_money

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

    func testHistoryRecoversFromBackupWhenPrimaryFileIsCorrupted() throws {
        let directoryURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileName = "history.json"
        let primaryURL = directoryURL.appendingPathComponent(fileName)
        let firstEvent = makeIncomeEvent(amount: 1_200)
        let secondEvent = makeIncomeEvent(amount: 2_400)
        let storage = BudgetHistoryStorage(
            directoryURL: directoryURL,
            fileName: fileName
        )

        storage.replaceAll([firstEvent])
        storage.replaceAll([secondEvent])
        try Data("corrupted-primary".utf8).write(to: primaryURL, options: .atomic)

        let recoveredStorage = BudgetHistoryStorage(
            directoryURL: directoryURL,
            fileName: fileName
        )
        let result = recoveredStorage.loadEventsWithRecovery()

        XCTAssertEqual(result.status, .recoveredFromBackup)
        XCTAssertEqual(result.events.map(\.id), [firstEvent.id])

        let repairedStorage = BudgetHistoryStorage(
            directoryURL: directoryURL,
            fileName: fileName
        )
        XCTAssertEqual(repairedStorage.loadEventsWithRecovery().status, .loaded)
        XCTAssertEqual(repairedStorage.loadEvents().map(\.id), [firstEvent.id])
    }

    func testHistoryDoesNotOverwriteFilesWhenPrimaryAndBackupAreCorrupted() throws {
        let directoryURL = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileName = "history.json"
        let primaryURL = directoryURL.appendingPathComponent(fileName)
        let backupURL = directoryURL.appendingPathComponent("\(fileName).backup")
        let corruptedPrimary = Data("corrupted-primary".utf8)
        let corruptedBackup = Data("corrupted-backup".utf8)
        try corruptedPrimary.write(to: primaryURL, options: .atomic)
        try corruptedBackup.write(to: backupURL, options: .atomic)

        let storage = BudgetHistoryStorage(
            directoryURL: directoryURL,
            fileName: fileName
        )
        XCTAssertEqual(storage.loadEventsWithRecovery().status, .unrecoverable)

        storage.replaceAll([makeIncomeEvent(amount: 5_000)])

        XCTAssertEqual(try Data(contentsOf: primaryURL), corruptedPrimary)
        XCTAssertEqual(try Data(contentsOf: backupURL), corruptedBackup)

        storage.clear()
        storage.replaceAll([makeIncomeEvent(amount: 5_000)])
        XCTAssertEqual(storage.loadEventsWithRecovery().status, .loaded)
        XCTAssertEqual(storage.loadEvents().count, 1)
    }

    func testBudgetStateRecoversFromBackupWhenPrimaryValueIsCorrupted() {
        let suiteName = "BudgetPersistenceRecovery-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "budget-state"
        let backupKey = "budget-state-backup"
        let service = Smart_money.PersistenceService(
            defaults: defaults,
            storageKey: storageKey,
            backupStorageKey: backupKey
        )
        service.saveBudgetState(makeBudgetState(income: 1_000))
        service.saveBudgetState(makeBudgetState(income: 2_000))
        defaults.set(Data("corrupted-primary".utf8), forKey: storageKey)

        let recoveredService = Smart_money.PersistenceService(
            defaults: defaults,
            storageKey: storageKey,
            backupStorageKey: backupKey
        )
        let result = recoveredService.loadBudgetStateWithRecovery()

        XCTAssertEqual(result.status, .recoveredFromBackup)
        XCTAssertEqual(result.state?.income, 1_000)

        let repairedService = Smart_money.PersistenceService(
            defaults: defaults,
            storageKey: storageKey,
            backupStorageKey: backupKey
        )
        XCTAssertEqual(repairedService.loadBudgetStateWithRecovery().status, .loaded)
        XCTAssertEqual(repairedService.loadBudgetState()?.income, 1_000)
    }

    func testBudgetStateDoesNotOverwriteValuesWhenPrimaryAndBackupAreCorrupted() {
        let suiteName = "BudgetPersistenceProtection-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "budget-state"
        let backupKey = "budget-state-backup"
        let corruptedPrimary = Data("corrupted-primary".utf8)
        let corruptedBackup = Data("corrupted-backup".utf8)
        defaults.set(corruptedPrimary, forKey: storageKey)
        defaults.set(corruptedBackup, forKey: backupKey)

        let service = Smart_money.PersistenceService(
            defaults: defaults,
            storageKey: storageKey,
            backupStorageKey: backupKey
        )
        XCTAssertEqual(service.loadBudgetStateWithRecovery().status, .unrecoverable)

        service.saveBudgetState(makeBudgetState(income: 3_000))

        XCTAssertEqual(defaults.data(forKey: storageKey), corruptedPrimary)
        XCTAssertEqual(defaults.data(forKey: backupKey), corruptedBackup)

        service.clearBudgetState()
        service.saveBudgetState(makeBudgetState(income: 3_000))
        XCTAssertEqual(service.loadBudgetStateWithRecovery().status, .loaded)
        XCTAssertEqual(service.loadBudgetState()?.income, 3_000)
    }

    func testBudgetStateTreatsUnexpectedStoredTypeAsUnrecoverable() {
        let suiteName = "BudgetPersistenceUnexpectedType-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "budget-state"
        let backupKey = "budget-state-backup"
        defaults.set("unexpected-value", forKey: storageKey)

        let service = Smart_money.PersistenceService(
            defaults: defaults,
            storageKey: storageKey,
            backupStorageKey: backupKey
        )

        XCTAssertEqual(service.loadBudgetStateWithRecovery().status, .unrecoverable)
        service.saveBudgetState(makeBudgetState(income: 7_000))
        XCTAssertEqual(defaults.string(forKey: storageKey), "unexpected-value")
    }

    private func makeTemporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func makeIncomeEvent(amount: Double) -> BudgetHistoryEvent {
        BudgetHistoryEvent(
            type: .income,
            amount: amount,
            currencyCode: "UAH"
        )
    }

    private func makeBudgetState(income: Double) -> Smart_money.BudgetPersistedState {
        Smart_money.BudgetPersistedState(
            income: income,
            lastIncomeAmount: income,
            settings: Smart_money.BudgetSettings(),
            allocatedBySubcategoryID: [:],
            categoryTargetBaselineByID: [:],
            lastIncomeToBankByCategoryID: [:],
            lastBankAutoDistributedBySubcategoryID: [:],
            monthlyIncomeBySubcategoryID: [:],
            monthlyTrackingMonthKey: "2026-08",
            bankBalance: 0
        )
    }
}
