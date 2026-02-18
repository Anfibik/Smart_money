import Foundation

struct BudgetSettings: Codable, Hashable {
    var categories: [ExpenseCategory]
    var currencyCode: String

    init(
        categories: [ExpenseCategory] = BudgetSettings.defaultCategories,
        currencyCode: String = "UAH"
    ) {
        self.categories = categories
        self.currencyCode = currencyCode
    }

    var categoriesTotalPercentage: Double {
        categories.reduce(0) { $0 + $1.percentage }
    }

    func isValidCategoryDistribution() -> Bool {
        abs(categoriesTotalPercentage - 100) < 0.0001
    }

    static let defaultCategories: [ExpenseCategory] = [
        ExpenseCategory(
            type: .essentials,
            percentage: 60,
            subcategories: [
                Subcategory(name: "Жилье", isSystem: true, percentage: 25, minLimit: 27000, priority: 2),
                Subcategory(name: "Питание", isSystem: true, percentage: 15, minLimit: 15000, priority: 3),
            ]
        ),
        
        
        ExpenseCategory(
            type: .wants,
            percentage: 20,
            subcategories: [
                Subcategory(name: "Шопинг", isSystem: true, percentage: 10, priority: 2),
                Subcategory(name: "Хобби", isSystem: true, percentage: 20, priority: 3),

            ]
        ),
        
        ExpenseCategory(
            type: .savings,
            percentage: 20,
            subcategories: [
                Subcategory(name: "Подушка", isSystem: true, percentage: 25, minLimit: 600000, priority: 3),

            ]
        )
    ]
}
