import Foundation

struct SystemSubcategorySetup: Codable, Hashable, Identifiable {
    let id: String
    let categoryType: ExpenseCategoryType
    let systemKey: SystemSubcategoryKey
    let name: String
    let percentage: Double
    let minLimit: Double
    let maxLimit: Double?

    init(
        categoryType: ExpenseCategoryType,
        systemKey: SystemSubcategoryKey,
        name: String,
        percentage: Double,
        minLimit: Double,
        maxLimit: Double?
    ) {
        self.id = "\(categoryType.rawValue)::\(systemKey.rawValue)"
        self.categoryType = categoryType
        self.systemKey = systemKey
        self.name = name
        self.percentage = percentage
        self.minLimit = minLimit
        self.maxLimit = maxLimit
    }
}
