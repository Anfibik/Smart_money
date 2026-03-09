import Foundation

struct BudgetStatisticsBucket: Identifiable, Hashable {
    let id: String
    let startDate: Date
    let label: String
    let income: Double
    let expense: Double
}

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
    let topExpenseSubcategories: [BudgetSubcategoryStatLine]
    let timelineBuckets: [BudgetStatisticsBucket]

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
        topExpenseSubcategories: [],
        timelineBuckets: []
    )
}
