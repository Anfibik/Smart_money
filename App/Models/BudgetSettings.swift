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
                defaultSystemCard(.housing),
                defaultSystemCard(.food),
                defaultSystemCard(.health),
                defaultSystemCard(.hygiene),
                defaultSystemCard(.transport, iconName: "tram.fill")
            ]
        ),

        ExpenseCategory(
            type: .wants,
            percentage: 15,
            subcategories: [
                defaultSystemCard(.shopping),
                defaultSystemCard(.entertainment)
            ]
        ),

        ExpenseCategory(
            type: .savings,
            percentage: 25,
            subcategories: [
                defaultSystemCard(.emergencyFund)
            ]
        )
    ]

    private static func defaultSystemCard(
        _ systemKey: SystemSubcategoryKey,
        iconName: String? = nil
    ) -> Subcategory {
        let definition = SystemCardCatalog.standard.definition(for: systemKey)
        return Subcategory(
            name: definition.name,
            isSystem: true,
            systemKey: systemKey,
            iconName: iconName ?? definition.iconName,
            percentage: definition.defaultPercentage,
            minLimit: definition.defaultMinLimit > 0 ? definition.defaultMinLimit : nil,
            priority: definition.defaultPriority.rawValue
        )
    }
}
