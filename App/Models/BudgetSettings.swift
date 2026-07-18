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
                    name: SystemSubcategoryKey.housing.defaultName,
                    isSystem: true,
                    systemKey: .housing,
                    iconName: SystemSubcategoryKey.housing.defaultIconName,
                    percentage: 30,
                    minLimit: 0,
                    priority: 3
                ),
                Subcategory(
                    name: SystemSubcategoryKey.food.defaultName,
                    isSystem: true,
                    systemKey: .food,
                    iconName: SystemSubcategoryKey.food.defaultIconName,
                    percentage: 10,
                    minLimit: 0,
                    priority: 2
                ),
                Subcategory(
                    name: SystemSubcategoryKey.health.defaultName,
                    isSystem: true,
                    systemKey: .health,
                    iconName: SystemSubcategoryKey.health.defaultIconName,
                    percentage: 5,
                    minLimit: 0,
                    priority: 2
                ),
                Subcategory(
                    name: SystemSubcategoryKey.hygiene.defaultName,
                    isSystem: true,
                    systemKey: .hygiene,
                    iconName: SystemSubcategoryKey.hygiene.defaultIconName,
                    percentage: 5,
                    minLimit: 500,
                    priority: 2
                ),
                Subcategory(
                    name: SystemSubcategoryKey.transport.defaultName,
                    isSystem: true,
                    systemKey: .transport,
                    iconName: "tram.fill",
                    percentage: 10,
                    minLimit: 1000,
                    priority: 2
                ),
            ]
        ),

        ExpenseCategory(
            type: .wants,
            percentage: 15,
            subcategories: [
                Subcategory(
                    name: SystemSubcategoryKey.shopping.defaultName,
                    isSystem: true,
                    systemKey: .shopping,
                    iconName: SystemSubcategoryKey.shopping.defaultIconName,
                    percentage: 30,
                    minLimit: 0,
                    priority: 3
                ),
                Subcategory(
                    name: SystemSubcategoryKey.hobby.defaultName,
                    isSystem: true,
                    systemKey: .hobby,
                    iconName: SystemSubcategoryKey.hobby.defaultIconName,
                    percentage: 20,
                    minLimit: 0,
                    priority: 2
                ),
                Subcategory(
                    name: SystemSubcategoryKey.entertainment.defaultName,
                    isSystem: true,
                    systemKey: .entertainment,
                    iconName: SystemSubcategoryKey.entertainment.defaultIconName,
                    percentage: 20,
                    minLimit: 0,
                    priority: 2
                ),
                Subcategory(
                    name: SystemSubcategoryKey.travel.defaultName,
                    isSystem: true,
                    systemKey: .travel,
                    iconName: SystemSubcategoryKey.travel.defaultIconName,
                    percentage: 10,
                    minLimit: 0,
                    priority: 2
                ),
                Subcategory(
                    name: SystemSubcategoryKey.gifts.defaultName,
                    isSystem: true,
                    systemKey: .gifts,
                    iconName: SystemSubcategoryKey.gifts.defaultIconName,
                    percentage: 5,
                    minLimit: 0,
                    priority: 2
                ),
                Subcategory(
                    name: SystemSubcategoryKey.sport.defaultName,
                    isSystem: true,
                    systemKey: .sport,
                    iconName: SystemSubcategoryKey.sport.defaultIconName,
                    percentage: 5,
                    minLimit: 0,
                    priority: 2
                ),
            ]
        ),

        ExpenseCategory(
            type: .savings,
            percentage: 25,
            subcategories: [
                Subcategory(
                    name: SystemSubcategoryKey.emergencyFund.defaultName,
                    isSystem: true,
                    systemKey: .emergencyFund,
                    iconName: SystemSubcategoryKey.emergencyFund.defaultIconName,
                    percentage: 50,
                    minLimit: 0,
                    priority: 3
                ),

            ]
        )
    ]
}
