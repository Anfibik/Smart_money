import Foundation

enum BudgetHistoryLoadStatus: Equatable {
    case missing
    case loaded
    case recoveredFromBackup
    case unrecoverable
}

struct BudgetHistoryLoadResult {
    let events: [BudgetHistoryEvent]
    let status: BudgetHistoryLoadStatus
}

final class BudgetHistoryStorage {
    private let fileManager: FileManager
    private let fileURL: URL
    private let backupFileURL: URL
    private let decoder = JSONDecoder()
    private let writeQueue: DispatchQueue
    private var cachedEvents: [BudgetHistoryEvent]?
    private var cachedLoadStatus: BudgetHistoryLoadStatus?
    private var pendingWrite: DispatchWorkItem?
    private var isWriteProtected = false

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        fileName: String = "budget_history_v1.json",
        backupFileName: String? = nil,
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
        self.backupFileURL = resolvedDirectoryURL.appendingPathComponent(
            backupFileName ?? "\(fileName).backup"
        )
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadEvents() -> [BudgetHistoryEvent] {
        loadEventsWithRecovery().events
    }

    func loadEventsWithRecovery() -> BudgetHistoryLoadResult {
        if let cachedEvents, let cachedLoadStatus {
            return BudgetHistoryLoadResult(events: cachedEvents, status: cachedLoadStatus)
        }

        let primaryData = try? Data(contentsOf: fileURL)
        let backupData = try? Data(contentsOf: backupFileURL)

        if let primaryData,
           let events = try? decoder.decode([BudgetHistoryEvent].self, from: primaryData) {
            if backupData.flatMap({ try? decoder.decode([BudgetHistoryEvent].self, from: $0) }) == nil {
                try? ensureDirectoryExists()
                try? primaryData.write(to: backupFileURL, options: .atomic)
            }
            cachedEvents = events
            cachedLoadStatus = .loaded
            isWriteProtected = false
            return BudgetHistoryLoadResult(events: events, status: .loaded)
        }

        if let backupData,
           let events = try? decoder.decode([BudgetHistoryEvent].self, from: backupData) {
            try? ensureDirectoryExists()
            try? backupData.write(to: fileURL, options: .atomic)
            cachedEvents = events
            cachedLoadStatus = .recoveredFromBackup
            isWriteProtected = false
            return BudgetHistoryLoadResult(events: events, status: .recoveredFromBackup)
        }

        let primaryExists = fileManager.fileExists(atPath: fileURL.path)
        let backupExists = fileManager.fileExists(atPath: backupFileURL.path)
        guard primaryExists || backupExists else {
            cachedEvents = []
            cachedLoadStatus = .missing
            isWriteProtected = false
            return BudgetHistoryLoadResult(events: [], status: .missing)
        }

        cachedEvents = []
        cachedLoadStatus = .unrecoverable
        isWriteProtected = true
        return BudgetHistoryLoadResult(events: [], status: .unrecoverable)
    }

    func append(_ event: BudgetHistoryEvent) {
        var events = cachedEvents ?? loadEvents()
        events.append(event)
        replaceAll(events)
    }

    func replaceAll(_ events: [BudgetHistoryEvent]) {
        pendingWrite?.cancel()
        pendingWrite = nil
        guard !isWriteProtected else { return }
        cachedEvents = events
        cachedLoadStatus = .loaded
        write(events)
    }

    func scheduleReplaceAll(_ events: [BudgetHistoryEvent], delay: TimeInterval = 0.35) {
        guard !isWriteProtected else { return }
        cachedEvents = events
        cachedLoadStatus = .loaded
        pendingWrite?.cancel()

        let fileManager = fileManager
        let fileURL = fileURL
        let backupFileURL = backupFileURL
        let workItem = DispatchWorkItem {
            Self.write(
                events,
                fileManager: fileManager,
                fileURL: fileURL,
                backupFileURL: backupFileURL
            )
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
        cachedLoadStatus = .missing
        isWriteProtected = false
        writeQueue.sync {
            try? fileManager.removeItem(at: fileURL)
            try? fileManager.removeItem(at: backupFileURL)
        }
    }

    private func write(_ events: [BudgetHistoryEvent]) {
        writeQueue.sync {
            Self.write(
                events,
                fileManager: fileManager,
                fileURL: fileURL,
                backupFileURL: backupFileURL
            )
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

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func write(
        _ events: [BudgetHistoryEvent],
        fileManager: FileManager,
        fileURL: URL,
        backupFileURL: URL
    ) {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directoryURL.path) {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            }

            if fileManager.fileExists(atPath: fileURL.path) {
                let primaryData = try Data(contentsOf: fileURL)
                if (try? makeDecoder().decode([BudgetHistoryEvent].self, from: primaryData)) != nil {
                    try primaryData.write(to: backupFileURL, options: .atomic)
                } else {
                    guard let backupData = try? Data(contentsOf: backupFileURL),
                          (try? makeDecoder().decode([BudgetHistoryEvent].self, from: backupData)) != nil else {
                        return
                    }
                }
            }

            let data = try makeEncoder().encode(events)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }
}
