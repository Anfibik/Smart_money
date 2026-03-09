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
                Subcategory(
                    name: "Жилье",
                    isSystem: true,
                    iconName: "house.fill",
                    percentage: 30,
                    minLimit: 0,
                    priority: 3
                ),
                Subcategory(
                    name: "Питание",
                    isSystem: true,
                    iconName: "fork.knife",
                    percentage: 10,
                    minLimit: 0,
                    priority: 3
                ),
                Subcategory(
                    name: "Здоровье",
                    isSystem: true,
                    iconName: "cross.case.fill",
                    percentage: 5,
                    minLimit: 0,
                    priority: 3
                ),
            ]
        ),

        ExpenseCategory(
            type: .wants,
            percentage: 15,
            subcategories: [
                Subcategory(
                    name: "Шопинг",
                    isSystem: true,
                    iconName: "cart.fill",
                    percentage: 5,
                    minLimit: 0,
                    priority: 1
                ),
                Subcategory(
                    name: "Хобби",
                    isSystem: true,
                    iconName: "gamecontroller.fill",
                    percentage: 10,
                    minLimit: 0,
                    priority: 1
                ),
                Subcategory(
                    name: "Развлечения",
                    isSystem: true,
                    iconName: "sparkles",
                    percentage: 10,
                    minLimit: 0,
                    priority: 1
                ),
            ]
        ),

        ExpenseCategory(
            type: .savings,
            percentage: 25,
            subcategories: [
                Subcategory(
                    name: "Подушка",
                    isSystem: true,
                    iconName: "shield.fill",
                    percentage: 25,
                    minLimit: 0,
                    priority: 2
                ),

            ]
        )
    ]
}
