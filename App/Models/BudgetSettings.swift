import Foundation

struct RecommendedCardTemplate: Codable, Hashable, Identifiable {
    let systemKey: SystemSubcategoryKey
    let categoryType: ExpenseCategoryType
    let name: String
    let iconName: String
    let description: String
    let percentage: Double
    let minLimit: Double?
    let maxLimit: Double?
    let priority: Int
    let fundingMode: SubcategoryFundingMode
    let balanceCurrencyCode: String?

    var id: SystemSubcategoryKey { systemKey }

    func makeSubcategory() -> Subcategory {
        Subcategory(
            name: name,
            isSystem: true,
            isRequired: false,
            systemKey: systemKey,
            iconName: iconName,
            percentage: percentage,
            minLimit: minLimit,
            maxLimit: maxLimit,
            priority: priority,
            fundingMode: fundingMode,
            balanceCurrencyCode: balanceCurrencyCode
        )
    }

    static let standard: [RecommendedCardTemplate] = SystemCardCatalog.standard.recommendedDefinitions.map {
        RecommendedCardTemplate(
            systemKey: $0.systemKey,
            categoryType: $0.categoryType,
            name: $0.name,
            iconName: $0.iconName,
            description: $0.description,
            percentage: $0.defaultPercentage,
            minLimit: $0.defaultMinLimit > 0 ? $0.defaultMinLimit : nil,
            maxLimit: nil,
            priority: $0.defaultPriority.rawValue,
            fundingMode: $0.fundingMode,
            balanceCurrencyCode: $0.systemKey == .currency ? ForeignCurrencyType.usd.rawValue : nil
        )
    }
}

struct BudgetSettings: Codable, Hashable {
    var categories: [ExpenseCategory]
    var currencyCode: String
    var recommendationTemplates: [RecommendedCardTemplate]

    init(
        categories: [ExpenseCategory] = BudgetSettings.defaultCategories,
        currencyCode: String = "UAH",
        recommendationTemplates: [RecommendedCardTemplate] = RecommendedCardTemplate.standard
    ) {
        self.categories = categories
        self.currencyCode = currencyCode
        self.recommendationTemplates = recommendationTemplates
    }

    enum CodingKeys: String, CodingKey {
        case categories
        case currencyCode
        case recommendationTemplates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = try container.decodeIfPresent([ExpenseCategory].self, forKey: .categories)
            ?? Self.defaultCategories
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "UAH"
        let decodedTemplates = try container.decodeIfPresent(
            [RecommendedCardTemplate].self,
            forKey: .recommendationTemplates
        )
        recommendationTemplates = decodedTemplates
            ?? Self.migratedRecommendationTemplates(from: categories)
    }

    private static func migratedRecommendationTemplates(
        from categories: [ExpenseCategory]
    ) -> [RecommendedCardTemplate] {
        let activeRecommendations = categories
            .flatMap(\.subcategories)
            .reduce(into: [SystemSubcategoryKey: Subcategory]()) { result, subcategory in
                guard let key = subcategory.systemKey,
                      SystemCardCatalog.standard.definition(for: key).availability == .recommended else {
                    return
                }
                result[key] = subcategory
            }

        return RecommendedCardTemplate.standard.map { template in
            guard let active = activeRecommendations[template.systemKey] else {
                return template
            }
            return RecommendedCardTemplate(
                systemKey: template.systemKey,
                categoryType: template.categoryType,
                name: template.name,
                iconName: template.iconName,
                description: template.description,
                percentage: active.percentage,
                minLimit: active.minLimit,
                maxLimit: active.maxLimit,
                priority: active.priority,
                fundingMode: active.fundingMode,
                balanceCurrencyCode: active.balanceCurrencyCode
            )
        }
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
