import Foundation

struct SubcategoryAllocation: Identifiable, Hashable {
    let id: UUID
    let name: String
    let isSystem: Bool
    let iconName: String
    let basePercentage: Double
    let fixedMinimumPercentage: Double?
    let minLimit: Double?
    let maxLimit: Double?
    let priority: Int
    let percentage: Double
    let allocatedAmount: Double
    let spentAmount: Double
    let remainingAmount: Double
    let deficitAmount: Double
}

struct CategoryAllocation: Identifiable, Hashable {
    let id: UUID
    let type: ExpenseCategoryType
    let percentage: Double
    let allocatedAmount: Double
    let lastIncomeToBankAmount: Double
    let subcategoryAllocations: [SubcategoryAllocation]
    let deficitAmount: Double
}

struct BankAutoDistributionLine: Identifiable, Hashable {
    let id: UUID
    let name: String
    let amount: Double
}

struct BudgetDistribution: Hashable {
    let income: Double
    let categoryAllocations: [CategoryAllocation]
    let bankAmount: Double
    let lastBankAutoDistributions: [BankAutoDistributionLine]
}
