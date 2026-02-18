import Foundation

struct SystemSubcategorySetup: Codable, Hashable, Identifiable {
    let id: String
    let categoryType: ExpenseCategoryType
    let name: String
    let percentage: Double
    let minLimit: Double
    let maxLimit: Double?

    init(
        categoryType: ExpenseCategoryType,
        name: String,
        percentage: Double,
        minLimit: Double,
        maxLimit: Double?
    ) {
        self.id = "\(categoryType.rawValue)::\(name)"
        self.categoryType = categoryType
        self.name = name
        self.percentage = percentage
        self.minLimit = minLimit
        self.maxLimit = maxLimit
    }
}
