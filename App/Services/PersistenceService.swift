import Foundation

struct BudgetPersistedState: Codable {
    let income: Double
    let lastIncomeAmount: Double
    let settings: BudgetSettings
    let allocatedBySubcategoryID: [String: Double]
    let categoryTargetBaselineByID: [String: Double]
    let lastIncomeToBankByCategoryID: [String: Double]
    let lastBankAutoDistributedBySubcategoryID: [String: Double]
    let monthlyIncomeBySubcategoryID: [String: Double]
    let monthlyIncomeDistributionBySubcategoryID: [String: Double]
    let monthlyOtherIncomingBySubcategoryID: [String: Double]
    let monthlyOtherOutgoingBySubcategoryID: [String: Double]
    let monthlyTrackingMonthKey: String
    let bankBalance: Double

    init(
        income: Double,
        lastIncomeAmount: Double,
        settings: BudgetSettings,
        allocatedBySubcategoryID: [String: Double],
        categoryTargetBaselineByID: [String: Double],
        lastIncomeToBankByCategoryID: [String: Double],
        lastBankAutoDistributedBySubcategoryID: [String: Double],
        monthlyIncomeBySubcategoryID: [String: Double],
        monthlyIncomeDistributionBySubcategoryID: [String: Double] = [:],
        monthlyOtherIncomingBySubcategoryID: [String: Double] = [:],
        monthlyOtherOutgoingBySubcategoryID: [String: Double] = [:],
        monthlyTrackingMonthKey: String,
        bankBalance: Double
    ) {
        self.income = income
        self.lastIncomeAmount = lastIncomeAmount
        self.settings = settings
        self.allocatedBySubcategoryID = allocatedBySubcategoryID
        self.categoryTargetBaselineByID = categoryTargetBaselineByID
        self.lastIncomeToBankByCategoryID = lastIncomeToBankByCategoryID
        self.lastBankAutoDistributedBySubcategoryID = lastBankAutoDistributedBySubcategoryID
        self.monthlyIncomeBySubcategoryID = monthlyIncomeBySubcategoryID
        self.monthlyIncomeDistributionBySubcategoryID = monthlyIncomeDistributionBySubcategoryID
        self.monthlyOtherIncomingBySubcategoryID = monthlyOtherIncomingBySubcategoryID
        self.monthlyOtherOutgoingBySubcategoryID = monthlyOtherOutgoingBySubcategoryID
        self.monthlyTrackingMonthKey = monthlyTrackingMonthKey
        self.bankBalance = bankBalance
    }

    private enum CodingKeys: String, CodingKey {
        case income
        case lastIncomeAmount
        case settings
        case allocatedBySubcategoryID
        case categoryTargetBaselineByID
        case lastIncomeToBankByCategoryID
        case lastBankAutoDistributedBySubcategoryID
        case monthlyIncomeBySubcategoryID
        case monthlyIncomeDistributionBySubcategoryID
        case monthlyOtherIncomingBySubcategoryID
        case monthlyOtherOutgoingBySubcategoryID
        case monthlyTrackingMonthKey
        case bankBalance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        income = try container.decode(Double.self, forKey: .income)
        lastIncomeAmount = try container.decode(Double.self, forKey: .lastIncomeAmount)
        settings = try container.decode(BudgetSettings.self, forKey: .settings)
        allocatedBySubcategoryID = try container.decode([String: Double].self, forKey: .allocatedBySubcategoryID)
        categoryTargetBaselineByID = try container.decode([String: Double].self, forKey: .categoryTargetBaselineByID)
        lastIncomeToBankByCategoryID = try container.decode([String: Double].self, forKey: .lastIncomeToBankByCategoryID)
        lastBankAutoDistributedBySubcategoryID = try container.decode([String: Double].self, forKey: .lastBankAutoDistributedBySubcategoryID)
        monthlyIncomeBySubcategoryID = try container.decodeIfPresent([String: Double].self, forKey: .monthlyIncomeBySubcategoryID) ?? [:]
        monthlyIncomeDistributionBySubcategoryID = try container.decodeIfPresent([String: Double].self, forKey: .monthlyIncomeDistributionBySubcategoryID) ?? [:]
        monthlyOtherIncomingBySubcategoryID = try container.decodeIfPresent([String: Double].self, forKey: .monthlyOtherIncomingBySubcategoryID) ?? [:]
        monthlyOtherOutgoingBySubcategoryID = try container.decodeIfPresent([String: Double].self, forKey: .monthlyOtherOutgoingBySubcategoryID) ?? [:]
        monthlyTrackingMonthKey = try container.decodeIfPresent(String.self, forKey: .monthlyTrackingMonthKey) ?? ""
        bankBalance = try container.decode(Double.self, forKey: .bankBalance)
    }
}

enum BudgetStateLoadStatus: Equatable {
    case missing
    case loaded
    case recoveredFromBackup
    case unrecoverable
}

struct BudgetStateLoadResult {
    let state: BudgetPersistedState?
    let status: BudgetStateLoadStatus
}

final class PersistenceService {
    private let defaults: UserDefaults
    private let storageKey: String
    private let backupStorageKey: String
    private let saveQueue: DispatchQueue
    private var pendingSave: DispatchWorkItem?
    private var pendingState: BudgetPersistedState?
    private var isWriteProtected = false

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "budget_state_v2",
        backupStorageKey: String? = nil,
        saveQueue: DispatchQueue = DispatchQueue(label: "smart-money.persistence-save", qos: .utility)
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.backupStorageKey = backupStorageKey ?? "\(storageKey)_backup"
        self.saveQueue = saveQueue
    }

    func loadBudgetState() -> BudgetPersistedState? {
        loadBudgetStateWithRecovery().state
    }

    func loadBudgetStateWithRecovery() -> BudgetStateLoadResult {
        let primaryExists = defaults.object(forKey: storageKey) != nil
        let backupExists = defaults.object(forKey: backupStorageKey) != nil
        let primaryData = defaults.data(forKey: storageKey)
        let backupData = defaults.data(forKey: backupStorageKey)

        if let primaryData,
           let state = Self.decodeState(from: primaryData) {
            if backupData.flatMap(Self.decodeState(from:)) == nil {
                defaults.set(primaryData, forKey: backupStorageKey)
            }
            isWriteProtected = false
            return BudgetStateLoadResult(state: state, status: .loaded)
        }

        if let backupData,
           let state = Self.decodeState(from: backupData) {
            defaults.set(backupData, forKey: storageKey)
            isWriteProtected = false
            return BudgetStateLoadResult(state: state, status: .recoveredFromBackup)
        }

        if !primaryExists, !backupExists {
            isWriteProtected = false
            return BudgetStateLoadResult(state: nil, status: .missing)
        }

        isWriteProtected = true
        return BudgetStateLoadResult(state: nil, status: .unrecoverable)
    }

    func saveBudgetState(_ state: BudgetPersistedState) {
        pendingSave?.cancel()
        pendingSave = nil
        pendingState = nil
        guard !isWriteProtected,
              let data = try? JSONEncoder().encode(state) else { return }
        saveQueue.sync {
            Self.writeStateData(
                data,
                defaults: defaults,
                storageKey: storageKey,
                backupStorageKey: backupStorageKey
            )
        }
    }

    func scheduleSaveBudgetState(_ state: BudgetPersistedState, delay: TimeInterval = 0.35) {
        pendingSave?.cancel()
        guard !isWriteProtected else {
            pendingSave = nil
            pendingState = nil
            return
        }
        pendingState = state

        guard let data = try? JSONEncoder().encode(state) else { return }
        let defaults = defaults
        let storageKey = storageKey
        let backupStorageKey = backupStorageKey
        let workItem = DispatchWorkItem {
            Self.writeStateData(
                data,
                defaults: defaults,
                storageKey: storageKey,
                backupStorageKey: backupStorageKey
            )
        }

        pendingSave = workItem
        saveQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func flushPendingSave() {
        guard let pendingState else { return }
        saveBudgetState(pendingState)
    }

    func clearBudgetState() {
        pendingSave?.cancel()
        pendingSave = nil
        pendingState = nil
        saveQueue.sync {
            defaults.removeObject(forKey: storageKey)
            defaults.removeObject(forKey: backupStorageKey)
        }
        isWriteProtected = false
    }

    private static func decodeState(from data: Data) -> BudgetPersistedState? {
        try? JSONDecoder().decode(BudgetPersistedState.self, from: data)
    }

    private static func writeStateData(
        _ newData: Data,
        defaults: UserDefaults,
        storageKey: String,
        backupStorageKey: String
    ) {
        if defaults.object(forKey: storageKey) != nil {
            guard let primaryData = defaults.data(forKey: storageKey) else {
                guard let backupData = defaults.data(forKey: backupStorageKey),
                      decodeState(from: backupData) != nil else {
                    return
                }
                defaults.set(newData, forKey: storageKey)
                return
            }

            if decodeState(from: primaryData) != nil {
                defaults.set(primaryData, forKey: backupStorageKey)
            } else {
                guard let backupData = defaults.data(forKey: backupStorageKey),
                      decodeState(from: backupData) != nil else {
                    return
                }
            }
        }

        defaults.set(newData, forKey: storageKey)
    }
}
