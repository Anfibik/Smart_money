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

enum DashboardStatisticsPeriod: String, CaseIterable, Identifiable {
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "Месяц"
        case .year: return "Год"
        }
    }
}

struct DashboardCurrencyBalance: Identifiable, Hashable {
    let currencyCode: String
    let amount: Double

    var id: String { currencyCode }
}

struct DashboardCardBalance: Hashable {
    let systemKey: SystemSubcategoryKey?
    let currencyCode: String
    let remainingAmount: Double
    let maxLimit: Double?
    let minLimit: Double?
    let spentAmount: Double
}

struct DashboardBalanceState: Hashable {
    let bankAmount: Double
    let cards: [DashboardCardBalance]
}

struct DashboardPeriodStatistics: Hashable {
    let totalIncome: Double
    let totalExpense: Double
    let openingBalance: Double
    let closingBalance: Double
    let outstandingDebt: Double
    let currencyBalances: [DashboardCurrencyBalance]
}
