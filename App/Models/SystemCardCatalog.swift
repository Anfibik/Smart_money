import Foundation

enum SystemCardAvailability: String, Codable, Hashable {
    case active
    case conditional
    case recommended
}

struct SystemCardDefinition: Identifiable, Hashable {
    let systemKey: SystemSubcategoryKey
    let categoryType: ExpenseCategoryType
    let description: String
    let defaultPercentage: Double
    let defaultMinLimit: Double
    let defaultPriority: SubcategoryPriorityLevel
    let availability: SystemCardAvailability
    let fundingMode: SubcategoryFundingMode

    var id: SystemSubcategoryKey { systemKey }
    var name: String { systemKey.defaultName }
    var iconName: String { systemKey.defaultIconName }
}

struct SystemCardPresentationContext: Hashable {
    var housingIsRented = false
    var hasCar = false
}

struct SystemCardCatalog {
    static let standard = SystemCardCatalog()

    let definitions: [SystemCardDefinition]

    init(definitions: [SystemCardDefinition] = Self.standardDefinitions) {
        self.definitions = definitions
    }

    var recommendedDefinitions: [SystemCardDefinition] {
        definitions.filter { $0.availability == .recommended }
    }

    func recommendedDefinitions(
        for categoryType: ExpenseCategoryType
    ) -> [SystemCardDefinition] {
        recommendedDefinitions.filter { $0.categoryType == categoryType }
    }

    func definition(for systemKey: SystemSubcategoryKey) -> SystemCardDefinition {
        guard let definition = definitions.first(where: { $0.systemKey == systemKey }) else {
            preconditionFailure("Missing system card definition for \(systemKey.rawValue)")
        }
        return definition
    }

    func description(
        for systemKey: SystemSubcategoryKey,
        context: SystemCardPresentationContext = SystemCardPresentationContext()
    ) -> String {
        switch systemKey {
        case .housing:
            return context.housingIsRented
                ? "Аренда, коммунальные, ремонт, клининг..."
                : "Коммунальные, ремонт, клининг..."
        case .transport:
            return context.hasCar
                ? "Бензин, ТО, ремонт, обслуживание, тюнинг"
                : "Общественный транспорт, такси"
        default:
            return definition(for: systemKey).description
        }
    }

    private static let standardDefinitions: [SystemCardDefinition] = [
        definition(.housing, .essentials, "Коммунальные, ремонт, клининг...", 10, 0, .medium, .active),
        definition(.food, .essentials, "Продукты, кафе, столовые, фастфуд...", 20, 0, .high, .active),
        definition(.health, .essentials, "Лекарства, витамины, БАДы, больницы, стоматология и процедуры", 3, 0, .medium, .active),
        definition(.hygiene, .essentials, "Парикмахерские, уход за телом и зубами...", 5, 500, .medium, .active),
        definition(.children, .essentials, "Все детские расходы, кроме питания и здоровья", 10, 0, .medium, .conditional),
        definition(.animals, .essentials, "Корм, уход, ветеринар", 3, 0, .medium, .conditional),
        definition(.transport, .essentials, "Общественный транспорт, такси", 5, 1_000, .medium, .active),
        definition(.shopping, .wants, "Торговые центры, одежда и другие покупки", 15, 0, .high, .active),
        definition(.entertainment, .wants, "Театры, прогулки, концерты, клубы...", 10, 0, .medium, .active),
        definition(.hobby, .wants, "Затраты на любимое дело", 5, 0, .medium, .recommended),
        definition(.travel, .wants, "Поездки, билеты, отпуск", 10, 0, .medium, .recommended),
        definition(.restaurants, .wants, "Кафе, рестораны, доставки и встречи вне дома", 20, 0, .medium, .recommended),
        definition(.gifts, .wants, "Праздники, сюрпризы, внимание близким", 5, 0, .medium, .recommended),
        definition(.sport, .wants, "Зал, секции, инвентарь", 20, 0, .medium, .recommended),
        definition(.beauty, .wants, "Косметика, уход, салоны и процедуры", 5, 0, .medium, .recommended),
        definition(.subscriptions, .wants, "Сервисы, приложения и регулярные подписки", 5, 0, .medium, .recommended),
        definition(.emergencyFund, .savings, "Финансовая подушка на 6 месяцев проживания", 50, 0, .high, .active),
        definition(.debt, .savings, "Создаётся при отрицательном капитале", 100, 0, .high, .conditional),
        definition(.credit, .savings, "Создаётся при наличии ежемесячного платежа", 10, 0, .medium, .conditional),
        definition(.investments, .savings, "Инвестиционные цели и долгосрочный рост капитала", 10, 0, .medium, .recommended),
        definition(.business, .savings, "Запуск и развитие собственного дела", 20, 0, .medium, .recommended),
        definition(.currency, .savings, "Валютные накопления с ручным пополнением и расходами", 0, 0, .medium, .recommended, .manualOnly),
        definition(.goal, .savings, "Крупная цель: квартира, дом, автомобиль или обучение ребёнка", 20, 0, .medium, .recommended)
    ]

    private static func definition(
        _ systemKey: SystemSubcategoryKey,
        _ categoryType: ExpenseCategoryType,
        _ description: String,
        _ percentage: Double,
        _ minLimit: Double,
        _ priority: SubcategoryPriorityLevel,
        _ availability: SystemCardAvailability,
        _ fundingMode: SubcategoryFundingMode = .automatic
    ) -> SystemCardDefinition {
        SystemCardDefinition(
            systemKey: systemKey,
            categoryType: categoryType,
            description: description,
            defaultPercentage: percentage,
            defaultMinLimit: minLimit,
            defaultPriority: priority,
            availability: availability,
            fundingMode: fundingMode
        )
    }
}
