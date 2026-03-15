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
        monthlyTrackingMonthKey = try container.decodeIfPresent(String.self, forKey: .monthlyTrackingMonthKey) ?? ""
        bankBalance = try container.decode(Double.self, forKey: .bankBalance)
    }
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
