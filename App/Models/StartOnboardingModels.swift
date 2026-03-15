import Foundation

enum SetupHousingType: String, Codable, CaseIterable, Hashable, Identifiable {
    case rented
    case owned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rented:
            return "Арендное"
        case .owned:
            return "Своё"
        }
    }

    var costTitle: String {
        switch self {
        case .rented:
            return "Аренда + налоги"
        case .owned:
            return "Налоги / обслуживание"
        }
    }
}

enum StartStrategyType: String, Codable, CaseIterable, Hashable, Identifiable {
    case stability
    case balance
    case capitalGrowth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stability:
            return "Стабильность"
        case .balance:
            return "Баланс"
        case .capitalGrowth:
            return "Рост Капитала"
        }
    }

    var summary: String {
        switch self {
        case .stability:
            return "Упор на основные потребности и уверенность в завтрашнем дне."
        case .balance:
            return "Сбалансированная стратегия для большей свободы в своих желаниях"
        case .capitalGrowth:
            return "Стратегия для инвестиций, открытия бизнеса или накоплений под крупные покупки"
        }
    }

    var categoryPercentages: [ExpenseCategoryType: Double] {
        switch self {
        case .stability:
            return [
                .essentials: 60,
                .wants: 15,
                .savings: 25
            ]
        case .balance:
            return [
                .essentials: 55,
                .wants: 20,
                .savings: 25
            ]
        case .capitalGrowth:
            return [
                .essentials: 50,
                .wants: 15,
                .savings: 35
            ]
        }
    }
}

struct StartCustomCardInput: Codable, Hashable, Identifiable {
    let id: UUID
    let categoryType: ExpenseCategoryType
    let name: String
    let iconName: String
    let minLimit: Double
    let percentage: Double?

    init(
        id: UUID = UUID(),
        categoryType: ExpenseCategoryType,
        name: String,
        iconName: String,
        minLimit: Double,
        percentage: Double? = nil
    ) {
        self.id = id
        self.categoryType = categoryType
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iconName = SubcategoryIconCatalog.normalized(iconName)
        self.minLimit = max(0, minLimit)
        if let percentage, percentage > 0 {
            self.percentage = percentage
        } else {
            self.percentage = nil
        }
    }
}

struct StartOnboardingDraft: Hashable {
    var monthlyIncome: Double = 0
    var capital: Double = 0
    var housingType: SetupHousingType = .rented
    var housingCost: Double = 0
    var hasCar: Bool = false
    var dependentsCount: Int = 0
    var elderlyDependentsCount: Int = 0
    var childrenCount: Int = 0
    var petsCount: Int = 0
    var hasCredit: Bool = false
    var creditMonthlyPayment: Double = 0
    var strategy: StartStrategyType = .stability
    var customCards: [StartCustomCardInput] = []

    func resolvedInput() -> StartOnboardingInput {
        StartOnboardingInput(
            monthlyIncome: monthlyIncome,
            capital: capital,
            housingType: housingType,
            housingCost: housingCost,
            hasCar: hasCar,
            dependentsCount: dependentsCount,
            elderlyDependentsCount: elderlyDependentsCount,
            childrenCount: childrenCount,
            petsCount: petsCount,
            hasCredit: hasCredit,
            creditMonthlyPayment: creditMonthlyPayment,
            strategy: strategy,
            customCards: customCards
        )
    }
}

struct StartOnboardingInput: Codable, Hashable {
    let monthlyIncome: Double
    let capital: Double
    let housingType: SetupHousingType
    let housingCost: Double
    let hasCar: Bool
    let dependentsCount: Int
    let elderlyDependentsCount: Int
    let childrenCount: Int
    let petsCount: Int
    let hasCredit: Bool
    let creditMonthlyPayment: Double
    let strategy: StartStrategyType
    let customCards: [StartCustomCardInput]

    init(
        monthlyIncome: Double,
        capital: Double,
        housingType: SetupHousingType,
        housingCost: Double,
        hasCar: Bool,
        dependentsCount: Int,
        elderlyDependentsCount: Int,
        childrenCount: Int,
        petsCount: Int,
        hasCredit: Bool,
        creditMonthlyPayment: Double,
        strategy: StartStrategyType,
        customCards: [StartCustomCardInput]
    ) {
        self.monthlyIncome = max(0, monthlyIncome)
        self.capital = capital
        self.housingType = housingType
        self.housingCost = max(0, housingCost)
        self.hasCar = hasCar
        self.dependentsCount = max(0, dependentsCount)
        self.elderlyDependentsCount = max(0, elderlyDependentsCount)
        self.childrenCount = max(0, childrenCount)
        self.petsCount = max(0, petsCount)
        self.hasCredit = hasCredit
        self.creditMonthlyPayment = hasCredit ? max(0, creditMonthlyPayment) : 0
        self.strategy = strategy
        self.customCards = Self.normalizedCustomCards(customCards)
    }

    var adultDependentsCount: Int {
        dependentsCount + elderlyDependentsCount
    }

    var adultsIncludingUserCount: Int {
        1 + adultDependentsCount
    }

    var totalPeopleCount: Int {
        adultsIncludingUserCount + childrenCount
    }

    var positiveCapital: Double {
        max(0, capital)
    }

    private static func normalizedCustomCards(_ source: [StartCustomCardInput]) -> [StartCustomCardInput] {
        var result: [StartCustomCardInput] = []

        for item in source {
            let normalized = StartCustomCardInput(
                id: item.id,
                categoryType: item.categoryType,
                name: item.name,
                iconName: item.iconName,
                minLimit: item.minLimit,
                percentage: item.percentage
            )
            guard !normalized.name.isEmpty, normalized.minLimit > 0 else { continue }
            result.append(normalized)
        }

        return result
    }
}

struct StartSystemCardDescriptor: Identifiable, Hashable {
    let categoryType: ExpenseCategoryType
    let name: String
    let iconName: String
    let note: String?

    var id: String {
        "\(categoryType.rawValue)::\(name)"
    }
}

struct StartCategoryBudget: Codable, Hashable, Identifiable {
    let type: ExpenseCategoryType
    let percentage: Double
    let monthlyAmount: Double

    var id: String { type.rawValue }
}

struct StartOnboardingConfiguration: Codable, Hashable {
    let input: StartOnboardingInput
    let settings: BudgetSettings
    let categoryBudgets: [StartCategoryBudget]
    let mandatoryLivingMonthly: Double
    let monthlyMinimumExcludingEmergency: Double
    let emergencyTarget: Double
    let capitalAppliedToMinimums: Double
    let remainingFreeCapital: Double
    let freeCapitalCoverageMonths: Double?
    let totalDeficit: Double
}

struct StartOnboardingPreview: Hashable {
    let configuration: StartOnboardingConfiguration
    let distribution: BudgetDistribution
    let warnings: [String]
}
