import Foundation

struct BudgetCategoryStatLine: Identifiable, Hashable {
    let id: String
    let title: String
    let amount: Double
    let share: Double
}

struct BudgetSubcategoryStatLine: Identifiable, Hashable {
    let id: String
    let title: String
    let iconName: String
    let amount: Double
    let share: Double
}

struct BudgetSubcategoryStatSection: Identifiable, Hashable {
    let id: String
    let title: String
    let amount: Double
    let share: Double
    let subcategories: [BudgetSubcategoryStatLine]
}

struct BudgetStatisticsSummary: Hashable {
    let totalIncome: Double
    let totalExpense: Double
    let netResult: Double
    let operationCount: Int
    let incomeOperationsCount: Int
    let expenseOperationsCount: Int
    let transferOperationsCount: Int
    let largestExpense: Double
    let averageExpense: Double
    let expenseByCategory: [BudgetCategoryStatLine]
    let expenseSubcategoriesByCategory: [BudgetSubcategoryStatSection]

    static let empty = BudgetStatisticsSummary(
        totalIncome: 0,
        totalExpense: 0,
        netResult: 0,
        operationCount: 0,
        incomeOperationsCount: 0,
        expenseOperationsCount: 0,
        transferOperationsCount: 0,
        largestExpense: 0,
        averageExpense: 0,
        expenseByCategory: [],
        expenseSubcategoriesByCategory: []
    )
}
