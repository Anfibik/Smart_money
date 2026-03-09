import Foundation

final class BudgetHistoryStorage {
    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        fileName: String = "budget_history_v1.json"
    ) {
        self.fileManager = fileManager

        let resolvedDirectoryURL: URL
        if let directoryURL {
            resolvedDirectoryURL = directoryURL
        } else {
            let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            let folderName = Bundle.main.bundleIdentifier ?? "Smart_money"
            resolvedDirectoryURL = baseDirectory.appendingPathComponent(folderName, isDirectory: true)
        }

        self.fileURL = resolvedDirectoryURL.appendingPathComponent(fileName)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadEvents() -> [BudgetHistoryEvent] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([BudgetHistoryEvent].self, from: data)
        } catch {
            return []
        }
    }

    func append(_ event: BudgetHistoryEvent) {
        var events = loadEvents()
        events.append(event)
        replaceAll(events)
    }

    func replaceAll(_ events: [BudgetHistoryEvent]) {
        do {
            try ensureDirectoryExists()
            let data = try encoder.encode(events)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }

    func clear() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    private func ensureDirectoryExists() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }
}
