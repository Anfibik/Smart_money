import Foundation

enum SubcategoryPriorityLevel: Int, Codable, CaseIterable, Hashable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .high: return "Высокий"
        case .medium: return "Средний"
        case .low: return "Низкий"
        }
    }
}

enum SubcategoryFundingMode: String, Codable, Hashable {
    case automatic
    case manualOnly
}

enum ForeignCurrencyType: String, Codable, CaseIterable, Hashable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case chf = "CHF"
    case pln = "PLN"
    case cad = "CAD"
    case jpy = "JPY"
    case cny = "CNY"
    case rub = "RUB"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd:
            return "USD - Доллар США"
        case .eur:
            return "EUR - Евро"
        case .gbp:
            return "GBP - Фунт стерлингов"
        case .chf:
            return "CHF - Швейцарский франк"
        case .pln:
            return "PLN - Польский злотый"
        case .cad:
            return "CAD - Канадский доллар"
        case .jpy:
            return "JPY - Японская иена"
        case .cny:
            return "CNY - Китайский юань"
        case .rub:
            return "RUB - Российский рубль"
        }
    }
}

enum SystemSubcategoryKey: String, Codable, CaseIterable, Hashable {
    case housing
    case food
    case health
    case hygiene
    case children
    case animals
    case transport
    case shopping
    case hobby
    case travel
    case restaurants
    case gifts
    case sport
    case beauty
    case subscriptions
    case entertainment
    case emergencyFund
    case debt
    case credit
    case investments
    case business
    case currency
    case goal

    var defaultName: String {
        switch self {
        case .housing:
            return "Жилье"
        case .food:
            return "Питание"
        case .health:
            return "Здоровье"
        case .hygiene:
            return "Гигиена"
        case .children:
            return "Дети"
        case .animals:
            return "Животные"
        case .transport:
            return "Транспорт"
        case .shopping:
            return "Шопинг"
        case .hobby:
            return "Хобби"
        case .travel:
            return "Путешествия"
        case .restaurants:
            return "Рестораны"
        case .gifts:
            return "Подарки"
        case .sport:
            return "Спорт"
        case .beauty:
            return "Красота"
        case .subscriptions:
            return "Подписки"
        case .entertainment:
            return "Досуг"
        case .emergencyFund:
            return "Подушка"
        case .debt:
            return "Долг"
        case .credit:
            return "Кредит"
        case .investments:
            return "Инвестиции"
        case .business:
            return "Бизнес"
        case .currency:
            return "Валюта"
        case .goal:
            return "Цель"
        }
    }

    var defaultIconName: String {
        switch self {
        case .housing:
            return "house.fill"
        case .food:
            return "fork.knife"
        case .health:
            return "cross.case.fill"
        case .hygiene:
            return "drop.fill"
        case .children:
            return "figure.2.and.child.holdinghands"
        case .animals:
            return "pawprint.fill"
        case .transport:
            return "car.fill"
        case .shopping:
            return "cart.fill"
        case .hobby:
            return "gamecontroller.fill"
        case .travel:
            return "airplane"
        case .restaurants:
            return "fork.knife.circle.fill"
        case .gifts:
            return "gift.fill"
        case .sport:
            return "figure.run"
        case .beauty:
            return "sparkles.rectangle.stack.fill"
        case .subscriptions:
            return "play.rectangle.on.rectangle.fill"
        case .entertainment:
            return "sparkles"
        case .emergencyFund:
            return "shield.fill"
        case .debt:
            return "banknote.fill"
        case .credit:
            return "creditcard.fill"
        case .investments:
            return "chart.line.uptrend.xyaxis"
        case .business:
            return "briefcase.fill"
        case .currency:
            return "dollarsign.arrow.circlepath"
        case .goal:
            return "target"
        }
    }

    static func inferred(from name: String, isSystem: Bool) -> SystemSubcategoryKey? {
        guard isSystem else { return nil }

        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "жилье":
            return .housing
        case "питание":
            return .food
        case "здоровье":
            return .health
        case "гигиена":
            return .hygiene
        case "дети":
            return .children
        case "животные":
            return .animals
        case "транспорт":
            return .transport
        case "шопинг":
            return .shopping
        case "хобби":
            return .hobby
        case "путешествия", "путешествие":
            return .travel
        case "рестораны":
            return .restaurants
        case "подарки":
            return .gifts
        case "спорт":
            return .sport
        case "красота":
            return .beauty
        case "подписки":
            return .subscriptions
        case "развлечения", "досуг":
            return .entertainment
        case "подушка":
            return .emergencyFund
        case "долг":
            return .debt
        case "кредит":
            return .credit
        case "инвестиции":
            return .investments
        case "бизнес":
            return .business
        case "валюта":
            return .currency
        case "цель":
            return .goal
        default:
            return nil
        }
    }
}

struct Subcategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isSystem: Bool
    var systemKey: SystemSubcategoryKey?
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

    /// Ручные карточки не участвуют в автоматическом распределении гривневого бюджета.
    var fundingMode: SubcategoryFundingMode

    /// Валюта остатка ручной карточки. Для обычных карточек используется валюта бюджета.
    var balanceCurrencyCode: String?

    /// Уже потрачено в этой подкатегории
    var spentAmount: Double

    init(
        id: UUID = UUID(),
        name: String,
        isSystem: Bool = false,
        systemKey: SystemSubcategoryKey? = nil,
        iconName: String = SubcategoryIconCatalog.fallbackSymbol,
        percentage: Double,
        fixedMinimumPercentage: Double? = nil,
        minLimit: Double? = nil,
        maxLimit: Double? = nil,
        priority: Int = 1,
        fundingMode: SubcategoryFundingMode = .automatic,
        balanceCurrencyCode: String? = nil,
        spentAmount: Double = 0
    ) {
        self.id = id
        self.name = name
        self.isSystem = isSystem
        let resolvedSystemKey = systemKey ?? SystemSubcategoryKey.inferred(from: name, isSystem: isSystem)
        self.systemKey = resolvedSystemKey
        let normalizedIcon = SubcategoryIconCatalog.normalized(iconName)
        if normalizedIcon == SubcategoryIconCatalog.fallbackSymbol,
           let resolvedSystemKey {
            self.iconName = resolvedSystemKey.defaultIconName
        } else {
            self.iconName = normalizedIcon
        }
        let isCurrencyCard = resolvedSystemKey == .currency
        self.percentage = isCurrencyCard ? 0 : percentage
        self.fixedMinimumPercentage = isCurrencyCard ? nil : fixedMinimumPercentage
        self.minLimit = isCurrencyCard ? nil : minLimit
        self.maxLimit = isCurrencyCard ? nil : maxLimit
        self.priority = priority
        self.fundingMode = isCurrencyCard ? .manualOnly : fundingMode
        self.balanceCurrencyCode = isCurrencyCard
            ? (balanceCurrencyCode ?? ForeignCurrencyType.usd.rawValue)
            : balanceCurrencyCode
        self.spentAmount = spentAmount
    }

    var participatesInAutomaticAllocation: Bool {
        fundingMode == .automatic
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isSystem
        case systemKey
        case iconName
        case percentage
        case fixedMinimumPercentage
        case minLimit
        case maxLimit
        case priority
        case fundingMode
        case balanceCurrencyCode
        case spentAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        isSystem = try container.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false
        systemKey = try container.decodeIfPresent(SystemSubcategoryKey.self, forKey: .systemKey)
            ?? SystemSubcategoryKey.inferred(from: name, isSystem: isSystem)
        percentage = try container.decodeIfPresent(Double.self, forKey: .percentage) ?? 0
        fixedMinimumPercentage = try container.decodeIfPresent(Double.self, forKey: .fixedMinimumPercentage)
        minLimit = try container.decodeIfPresent(Double.self, forKey: .minLimit)
        maxLimit = try container.decodeIfPresent(Double.self, forKey: .maxLimit)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 1
        fundingMode = try container.decodeIfPresent(SubcategoryFundingMode.self, forKey: .fundingMode) ?? .automatic
        balanceCurrencyCode = try container.decodeIfPresent(String.self, forKey: .balanceCurrencyCode)
        spentAmount = try container.decodeIfPresent(Double.self, forKey: .spentAmount) ?? 0

        if let decodedIconName = try container.decodeIfPresent(String.self, forKey: .iconName) {
            iconName = SubcategoryIconCatalog.normalized(decodedIconName)
        } else {
            iconName = SubcategoryIconCatalog.defaultSystemIcon(
                for: systemKey,
                fallbackName: name,
                isSystem: isSystem
            )
        }

        if systemKey == .currency {
            percentage = 0
            fixedMinimumPercentage = nil
            minLimit = nil
            maxLimit = nil
            fundingMode = .manualOnly
            balanceCurrencyCode = balanceCurrencyCode ?? ForeignCurrencyType.usd.rawValue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isSystem, forKey: .isSystem)
        try container.encodeIfPresent(systemKey, forKey: .systemKey)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(percentage, forKey: .percentage)
        try container.encodeIfPresent(fixedMinimumPercentage, forKey: .fixedMinimumPercentage)
        try container.encodeIfPresent(minLimit, forKey: .minLimit)
        try container.encodeIfPresent(maxLimit, forKey: .maxLimit)
        try container.encode(priority, forKey: .priority)
        try container.encode(fundingMode, forKey: .fundingMode)
        try container.encodeIfPresent(balanceCurrencyCode, forKey: .balanceCurrencyCode)
        try container.encode(spentAmount, forKey: .spentAmount)
    }
}

enum SubcategoryIconCatalog {
    static let selectableSymbols: [String] = [
        "house.fill",
        "fork.knife",
        "drop.fill",
        "cart.fill",
        "gamecontroller.fill",
        "shield.fill",
        "car.fill",
        "figure.2.and.child.holdinghands",
        "cross.case.fill",
        "creditcard.fill",
        "banknote.fill",
        "sparkles",
        "tram.fill",
        "dumbbell.fill",
        "wifi",
        "phone.fill",
        "bag.fill",
        "airplane",
        "music.note.house.fill",
        "film.fill",
        "cup.and.saucer.fill",
        "chart.line.uptrend.xyaxis",
        "briefcase.fill",
        "dollarsign.circle.fill",
        "target",
        "fork.knife.circle.fill",
        "beach.umbrella.fill"
    ]


    static let fallbackSymbol = "circle.grid.2x2.fill"

    static func normalized(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallbackSymbol : trimmed
    }

    static func defaultSystemIcon(
        for systemKey: SystemSubcategoryKey?,
        fallbackName: String? = nil,
        isSystem: Bool
    ) -> String {
        guard isSystem else { return fallbackSymbol }
        if let systemKey {
            return systemKey.defaultIconName
        }
        guard let fallbackName else { return fallbackSymbol }
        return SystemSubcategoryKey.inferred(from: fallbackName, isSystem: isSystem)?.defaultIconName ?? fallbackSymbol
    }

    static func defaultSystemIcon(for subcategoryName: String, isSystem: Bool) -> String {
        defaultSystemIcon(
            for: SystemSubcategoryKey.inferred(from: subcategoryName, isSystem: isSystem),
            fallbackName: subcategoryName,
            isSystem: isSystem
        )
    }
}
