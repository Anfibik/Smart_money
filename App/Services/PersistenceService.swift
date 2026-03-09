import Foundation

struct BudgetPersistedState: Codable {
    let income: Double
    let lastIncomeAmount: Double
    let settings: BudgetSettings
    let allocatedBySubcategoryID: [String: Double]
    let categoryTargetBaselineByID: [String: Double]
    let lastIncomeToBankByCategoryID: [String: Double]
    let lastBankAutoDistributedBySubcategoryID: [String: Double]
    let bankBalance: Double
}

final class PersistenceService {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "budget_state_v2"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func loadBudgetState() -> BudgetPersistedState? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(BudgetPersistedState.self, from: data)
    }

    func saveBudgetState(_ state: BudgetPersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func clearBudgetState() {
        defaults.removeObject(forKey: storageKey)
    }
}
