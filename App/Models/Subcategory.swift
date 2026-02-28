import Foundation

struct Subcategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isSystem: Bool
    var iconName: String

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
        iconName: String = SubcategoryIconCatalog.fallbackSymbol,
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
        self.iconName = SubcategoryIconCatalog.normalized(iconName)
        self.percentage = percentage
        self.fixedMinimumPercentage = fixedMinimumPercentage
        self.minLimit = minLimit
        self.maxLimit = maxLimit
        self.priority = priority
        self.spentAmount = spentAmount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isSystem
        case iconName
        case percentage
        case fixedMinimumPercentage
        case minLimit
        case maxLimit
        case priority
        case spentAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        isSystem = try container.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false
        percentage = try container.decodeIfPresent(Double.self, forKey: .percentage) ?? 0
        fixedMinimumPercentage = try container.decodeIfPresent(Double.self, forKey: .fixedMinimumPercentage)
        minLimit = try container.decodeIfPresent(Double.self, forKey: .minLimit)
        maxLimit = try container.decodeIfPresent(Double.self, forKey: .maxLimit)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 1
        spentAmount = try container.decodeIfPresent(Double.self, forKey: .spentAmount) ?? 0

        if let decodedIconName = try container.decodeIfPresent(String.self, forKey: .iconName) {
            iconName = SubcategoryIconCatalog.normalized(decodedIconName)
        } else {
            iconName = SubcategoryIconCatalog.defaultSystemIcon(for: name, isSystem: isSystem)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isSystem, forKey: .isSystem)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(percentage, forKey: .percentage)
        try container.encodeIfPresent(fixedMinimumPercentage, forKey: .fixedMinimumPercentage)
        try container.encodeIfPresent(minLimit, forKey: .minLimit)
        try container.encodeIfPresent(maxLimit, forKey: .maxLimit)
        try container.encode(priority, forKey: .priority)
        try container.encode(spentAmount, forKey: .spentAmount)
    }
}

enum SubcategoryIconCatalog {
    static let selectableSymbols: [String] = [
        "house.fill",
        "fork.knife",
        "cart.fill",
        "gamecontroller.fill",
        "shield.fill",
        "car.fill",
        "tram.fill",
        "cross.case.fill",
        "figure.2.and.child.holdinghands",
        "dumbbell.fill",
        "wifi",
        "phone.fill",
        "bag.fill",
        "airplane",
        "music.note.house.fill",
        "film.fill",
        "cup.and.saucer.fill",
        "banknote.fill",
        "chart.line.uptrend.xyaxis",
        "briefcase.fill",
        "dollarsign.circle.fill",
        "fork.knife.circle.fill",
        "beach.umbrella.fill"
    ]


    static let fallbackSymbol = "circle.grid.2x2.fill"

    static func normalized(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackSymbol : trimmed
    }

    static func defaultSystemIcon(for subcategoryName: String, isSystem: Bool) -> String {
        guard isSystem else { return fallbackSymbol }

        switch subcategoryName.lowercased() {
        case "жилье":
            return "house.fill"
        case "питание":
            return "fork.knife"
        case "шопинг":
            return "cart.fill"
        case "хобби":
            return "gamecontroller.fill"
        case "подушка":
            return "shield.fill"

        default:
            return fallbackSymbol
        }
    }
}
