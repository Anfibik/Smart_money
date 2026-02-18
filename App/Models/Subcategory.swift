import Foundation

struct Subcategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isSystem: Bool

    /// Процент от суммы родительской категории (0...100)
    var percentage: Double

    /// Минимальный процент для фиксированных подкатегорий (если есть)
    var fixedMinimumPercentage: Double?

    /// Минимальный лимит в деньгах (если есть)
    var minLimit: Double?

    /// Максимальный лимит в деньгах (если есть)
    var maxLimit: Double?

    /// Приоритет для распределения (чем больше, тем выше приоритет)
    var priority: Int

    /// Уже потрачено в этой подкатегории
    var spentAmount: Double

    init(
        id: UUID = UUID(),
        name: String,
        isSystem: Bool = false,
        percentage: Double,
        fixedMinimumPercentage: Double? = nil,
        minLimit: Double? = nil,
        maxLimit: Double? = nil,
        priority: Int = 1,
        spentAmount: Double = 0
    ) {
        self.id = id
        self.name = name
        self.isSystem = isSystem
        self.percentage = percentage
        self.fixedMinimumPercentage = fixedMinimumPercentage
        self.minLimit = minLimit
        self.maxLimit = maxLimit
        self.priority = priority
        self.spentAmount = spentAmount
    }
}
