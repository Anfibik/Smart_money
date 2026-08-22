import Foundation

final class BudgetHistoryStorage {
    private let fileManager: FileManager
    private let fileURL: URL
    private let decoder = JSONDecoder()
    private let writeQueue: DispatchQueue
    private var cachedEvents: [BudgetHistoryEvent]?
    private var pendingWrite: DispatchWorkItem?

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        fileName: String = "budget_history_v1.json",
        writeQueue: DispatchQueue = DispatchQueue(label: "smart-money.history-write", qos: .utility)
    ) {
        self.fileManager = fileManager
        self.writeQueue = writeQueue

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
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadEvents() -> [BudgetHistoryEvent] {
        if let cachedEvents {
            return cachedEvents
        }

        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            let events = try decoder.decode([BudgetHistoryEvent].self, from: data)
            cachedEvents = events
            return events
        } catch {
            return []
        }
    }

    func append(_ event: BudgetHistoryEvent) {
        var events = cachedEvents ?? loadEvents()
        events.append(event)
        replaceAll(events)
    }

    func replaceAll(_ events: [BudgetHistoryEvent]) {
        pendingWrite?.cancel()
        pendingWrite = nil
        cachedEvents = events
        write(events)
    }

    func scheduleReplaceAll(_ events: [BudgetHistoryEvent], delay: TimeInterval = 0.35) {
        cachedEvents = events
        pendingWrite?.cancel()

        let workItem = DispatchWorkItem { [fileManager, fileURL] in
            do {
                let directoryURL = fileURL.deletingLastPathComponent()
                if !fileManager.fileExists(atPath: directoryURL.path) {
                    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                }

                let data = try Self.makeEncoder().encode(events)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                return
            }
        }

        pendingWrite = workItem
        writeQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func flushPendingWrite() {
        guard let cachedEvents else { return }
        replaceAll(cachedEvents)
    }

    func clear() {
        pendingWrite?.cancel()
        pendingWrite = nil
        cachedEvents = []
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    private func write(_ events: [BudgetHistoryEvent]) {
        do {
            try ensureDirectoryExists()
            let data = try Self.makeEncoder().encode(events)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }

    private func ensureDirectoryExists() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
