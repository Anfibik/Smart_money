import Foundation

struct StartOnboardingBuilder {
    private let allocationEngine = BudgetAllocationEngine()

    func buildPreview(input: StartOnboardingInput) -> StartOnboardingPreview {
        let categoryBudgets = buildCategoryBudgets(for: input)
        let settings = buildSettings(for: input, categoryBudgets: categoryBudgets)

        var categoryTargetBaselineByID = Dictionary(
            uniqueKeysWithValues: settings.categories.map { ($0.id, 0.0) }
        )
        var allocatedBySubcategoryID = Dictionary(
            uniqueKeysWithValues: settings.categories.flatMap { category in
                category.subcategories.map { ($0.id, 0.0) }
            }
        )
        var lastIncomeToBankByCategoryID = Dictionary(
            uniqueKeysWithValues: settings.categories.map { ($0.id, 0.0) }
        )
        var lastBankAutoDistributedBySubcategoryID: [UUID: Double] = [:]
        var bankBalance = input.positiveCapital

        if input.monthlyIncome > 0 {
            allocationEngine.applyIncomeDelta(
                input.monthlyIncome,
                settings: settings,
                categoryTargetBaselineByID: &categoryTargetBaselineByID,
                allocatedBySubcategoryID: &allocatedBySubcategoryID,
                bankBalance: &bankBalance,
                lastIncomeToBankByCategoryID: &lastIncomeToBankByCategoryID,
                lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID
            )
        }

        allocationEngine.resolveMinimumDeficitsFromBank(
            settings: settings,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance,
            lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID,
            trackAutoDistribution: true
        )

        let distribution = buildDistribution(
            input: input,
            settings: settings,
            allocatedBySubcategoryID: allocatedBySubcategoryID,
            lastIncomeToBankByCategoryID: lastIncomeToBankByCategoryID,
            lastBankAutoDistributedBySubcategoryID: lastBankAutoDistributedBySubcategoryID,
            bankBalance: bankBalance
        )

        let mandatoryLivingMonthly = roundToCents(computeMandatoryLivingMonthly(from: settings))
        let monthlyMinimumExcludingEmergency = roundToCents(computeMonthlyMinimumExcludingEmergency(from: settings))
        let emergencyTarget = roundToCents(mandatoryLivingMonthly * 6)
        let remainingFreeCapital = roundToCents(max(0, bankBalance))
        let capitalAppliedToMinimums = roundToCents(max(0, input.positiveCapital - remainingFreeCapital))
        let totalDeficit = roundToCents(distribution.categoryAllocations.reduce(0) { $0 + $1.deficitAmount })
        let coverageMonths: Double?
        if monthlyMinimumExcludingEmergency > 0 {
            coverageMonths = roundToCents(remainingFreeCapital / monthlyMinimumExcludingEmergency)
        } else {
            coverageMonths = nil
        }

        let configuration = StartOnboardingConfiguration(
            input: input,
            settings: settings,
            categoryBudgets: categoryBudgets,
            mandatoryLivingMonthly: mandatoryLivingMonthly,
            monthlyMinimumExcludingEmergency: monthlyMinimumExcludingEmergency,
            emergencyTarget: emergencyTarget,
            capitalAppliedToMinimums: capitalAppliedToMinimums,
            remainingFreeCapital: remainingFreeCapital,
            freeCapitalCoverageMonths: coverageMonths,
            totalDeficit: totalDeficit
        )

        return StartOnboardingPreview(
            configuration: configuration,
            distribution: distribution,
            warnings: buildWarnings(
                input: input,
                settings: settings,
                categoryBudgets: categoryBudgets,
                totalDeficit: totalDeficit
            )
        )
    }

    static func systemCardDescriptors(
        housingType: SetupHousingType,
        carsCount: Int,
        childrenCount: Int,
        capital: Double,
        hasCredit: Bool
    ) -> [StartSystemCardDescriptor] {
        var cards: [StartSystemCardDescriptor] = [
            StartSystemCardDescriptor(
                categoryType: .essentials,
                name: "Жилье",
                iconName: defaultSystemIcon(for: "Жилье"),
                note: housingType == .rented ? "Аренда" : "Своё жилье"
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                name: "Питание",
                iconName: defaultSystemIcon(for: "Питание"),
                note: "Обязательная карта"
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                name: "Здоровье",
                iconName: defaultSystemIcon(for: "Здоровье"),
                note: "Обязательная карта"
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: "Шопинг",
                iconName: defaultSystemIcon(for: "Шопинг"),
                note: "Создается всегда"
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: "Хобби",
                iconName: defaultSystemIcon(for: "Хобби"),
                note: "Создается всегда"
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: "Развлечения",
                iconName: defaultSystemIcon(for: "Развлечения"),
                note: "Создается всегда"
            ),
            StartSystemCardDescriptor(
                categoryType: .savings,
                name: "Подушка",
                iconName: defaultSystemIcon(for: "Подушка"),
                note: "Цель 6 месяцев"
            )
        ]

        if childrenCount > 0 {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .essentials,
                    name: "Дети",
                    iconName: defaultSystemIcon(for: "Дети"),
                    note: "Все детские расходы, кроме питания и здоровья"
                )
            )
        }

        if carsCount > 0 {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .essentials,
                    name: "Транспорт",
                    iconName: defaultSystemIcon(for: "Транспорт"),
                    note: "Создается по числу авто"
                )
            )
        }

        if capital < 0 {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .savings,
                    name: "Долг",
                    iconName: defaultSystemIcon(for: "Долг"),
                    note: "Создается при отрицательном капитале"
                )
            )
        }

        if hasCredit {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .savings,
                    name: "Кредит",
                    iconName: defaultSystemIcon(for: "Кредит"),
                    note: "Создается при наличии ежемесячного платежа"
                )
            )
        }

        return ExpenseCategoryType.allCases.flatMap { categoryType in
            cards.filter { $0.categoryType == categoryType }
        }
    }

    private func buildCategoryBudgets(for input: StartOnboardingInput) -> [StartCategoryBudget] {
        ExpenseCategoryType.allCases.map { type in
            let percentage = input.strategy.categoryPercentages[type, default: 0]
            return StartCategoryBudget(
                type: type,
                percentage: percentage,
                monthlyAmount: roundToCents(input.monthlyIncome * (percentage / 100.0))
            )
        }
    }

    private func buildSettings(
        for input: StartOnboardingInput,
        categoryBudgets: [StartCategoryBudget]
    ) -> BudgetSettings {
        let budgetsByType = Dictionary(uniqueKeysWithValues: categoryBudgets.map { ($0.type, $0.monthlyAmount) })
        let essentialsBudget = budgetsByType[.essentials, default: 0]
        let wantsBudget = budgetsByType[.wants, default: 0]
        let savingsBudget = budgetsByType[.savings, default: 0]

        let housingPercentage = input.housingType == .rented ? 30.0 : 5.0
        let foodPercentage = 10.0
            + (Double(input.adultDependentsCount) * 5.0)
            + (Double(input.childrenCount) * 4.0)
        let healthPercentage = 5.0
            + (Double(input.adultDependentsCount) * 2.0)
            + (Double(input.childrenCount) * 3.0)
        let childrenPercentage = input.childrenCount > 0 ? 10.0 : nil
        let transportPercentage = input.carsCount > 0 ? 10.0 : nil
        let debtPercentage = input.capital < 0 ? 50.0 : nil
        let creditPercentage = input.hasCredit ? 10.0 : nil

        let housingMin = roundToCents(input.housingCost * 1.10)
        let foodMin = roundToCents(
            (Double(input.adultsIncludingUserCount) * 9000.0)
                + (Double(input.childrenCount) * 6000.0)
        )
        let healthMin = roundToCents(
            max(
                essentialsBudget * (healthPercentage / 100.0),
                Double(input.totalPeopleCount) * 500.0
            )
        )
        let childrenMin = roundToCents(essentialsBudget * ((childrenPercentage ?? 0) / 100.0))
        let transportMin = roundToCents(essentialsBudget * ((transportPercentage ?? 0) / 100.0))
        let shoppingMin = roundToCents(wantsBudget * 0.05)
        let hobbyMin = roundToCents(wantsBudget * 0.10)
        let entertainmentMin = roundToCents(wantsBudget * 0.10)
        let debtMin = roundToCents(max(savingsBudget * 0.50, abs(min(0, input.capital)) / 24.0))
        let creditMin = roundToCents(max(input.creditMonthlyPayment, savingsBudget * 0.10))

        let mandatoryLivingMonthly = housingMin + foodMin + healthMin + childrenMin + transportMin + debtMin + creditMin
        let emergencyTarget = roundToCents(mandatoryLivingMonthly * 6.0)
        let emergencyMin = roundToCents(max(0, emergencyTarget - input.positiveCapital) / 12.0)

        var categories: [ExpenseCategory] = [
            ExpenseCategory(
                type: .essentials,
                percentage: input.strategy.categoryPercentages[.essentials, default: 0],
                subcategories: essentialsSubcategories(
                    housingPercentage: housingPercentage,
                    housingMin: housingMin,
                    foodPercentage: foodPercentage,
                    foodMin: foodMin,
                    healthPercentage: healthPercentage,
                    healthMin: healthMin,
                    childrenPercentage: childrenPercentage,
                    childrenMin: childrenMin,
                    transportPercentage: transportPercentage,
                    transportMin: transportMin
                ) + buildCustomSubcategories(for: .essentials, input: input, categoryBudget: essentialsBudget)
            ),
            ExpenseCategory(
                type: .wants,
                percentage: input.strategy.categoryPercentages[.wants, default: 0],
                subcategories: wantsSubcategories(
                    shoppingMin: shoppingMin,
                    hobbyMin: hobbyMin,
                    entertainmentMin: entertainmentMin
                ) + buildCustomSubcategories(for: .wants, input: input, categoryBudget: wantsBudget)
            ),
            ExpenseCategory(
                type: .savings,
                percentage: input.strategy.categoryPercentages[.savings, default: 0],
                subcategories: savingsSubcategories(
                    emergencyMin: emergencyMin,
                    debtPercentage: debtPercentage,
                    debtMin: debtMin,
                    creditPercentage: creditPercentage,
                    creditMin: creditMin
                ) + buildCustomSubcategories(for: .savings, input: input, categoryBudget: savingsBudget)
            )
        ]

        categories = categories.map { category in
            var copy = category
            copy.subcategories = copy.subcategories.map { subcategory in
                var editable = subcategory
                editable.iconName = SubcategoryIconCatalog.normalized(editable.iconName)
                return editable
            }
            return copy
        }

        return BudgetSettings(categories: categories, currencyCode: "UAH")
    }

    private func essentialsSubcategories(
        housingPercentage: Double,
        housingMin: Double,
        foodPercentage: Double,
        foodMin: Double,
        healthPercentage: Double,
        healthMin: Double,
        childrenPercentage: Double?,
        childrenMin: Double,
        transportPercentage: Double?,
        transportMin: Double
    ) -> [Subcategory] {
        var cards: [Subcategory] = [
            systemSubcategory(
                name: "Жилье",
                percentage: housingPercentage,
                minLimit: housingMin,
                priority: .high
            ),
            systemSubcategory(
                name: "Питание",
                percentage: foodPercentage,
                minLimit: foodMin,
                priority: .high
            ),
            systemSubcategory(
                name: "Здоровье",
                percentage: healthPercentage,
                minLimit: healthMin,
                priority: .high
            )
        ]

        if let childrenPercentage {
            cards.append(
                systemSubcategory(
                    name: "Дети",
                    percentage: childrenPercentage,
                    minLimit: childrenMin,
                    priority: .medium
                )
            )
        }

        if let transportPercentage {
            cards.append(
                systemSubcategory(
                    name: "Транспорт",
                    percentage: transportPercentage,
                    minLimit: transportMin,
                    priority: .medium
                )
            )
        }

        return cards
    }

    private func wantsSubcategories(
        shoppingMin: Double,
        hobbyMin: Double,
        entertainmentMin: Double
    ) -> [Subcategory] {
        [
            systemSubcategory(
                name: "Шопинг",
                percentage: 5,
                minLimit: shoppingMin,
                priority: .low
            ),
            systemSubcategory(
                name: "Хобби",
                percentage: 10,
                minLimit: hobbyMin,
                priority: .low
            ),
            systemSubcategory(
                name: "Развлечения",
                percentage: 10,
                minLimit: entertainmentMin,
                priority: .low
            )
        ]
    }

    private func savingsSubcategories(
        emergencyMin: Double,
        debtPercentage: Double?,
        debtMin: Double,
        creditPercentage: Double?,
        creditMin: Double
    ) -> [Subcategory] {
        var cards: [Subcategory] = [
            systemSubcategory(
                name: "Подушка",
                percentage: 25,
                minLimit: emergencyMin,
                priority: .medium
            )
        ]

        if let debtPercentage {
            cards.append(
                systemSubcategory(
                    name: "Долг",
                    percentage: debtPercentage,
                    minLimit: debtMin,
                    priority: .high
                )
            )
        }

        if let creditPercentage {
            cards.append(
                systemSubcategory(
                    name: "Кредит",
                    percentage: creditPercentage,
                    minLimit: creditMin,
                    priority: .high
                )
            )
        }

        return cards
    }

    private func buildCustomSubcategories(
        for categoryType: ExpenseCategoryType,
        input: StartOnboardingInput,
        categoryBudget: Double
    ) -> [Subcategory] {
        input.customCards
            .filter { $0.categoryType == categoryType }
            .map { custom in
                let derivedPercentage: Double
                if let percentage = custom.percentage {
                    derivedPercentage = percentage
                } else if categoryBudget > 0 {
                    derivedPercentage = roundToCents((custom.minLimit / categoryBudget) * 100.0)
                } else {
                    derivedPercentage = 0
                }

                return Subcategory(
                    id: custom.id,
                    name: custom.name,
                    isSystem: false,
                    iconName: custom.iconName,
                    percentage: max(0, derivedPercentage),
                    fixedMinimumPercentage: nil,
                    minLimit: custom.minLimit,
                    maxLimit: nil,
                    priority: SubcategoryPriorityLevel.low.rawValue,
                    spentAmount: 0
                )
            }
    }

    private func systemSubcategory(
        name: String,
        percentage: Double,
        minLimit: Double,
        priority: SubcategoryPriorityLevel
    ) -> Subcategory {
        Subcategory(
            name: name,
            isSystem: true,
            iconName: Self.defaultSystemIcon(for: name),
            percentage: percentage,
            fixedMinimumPercentage: nil,
            minLimit: max(0, minLimit),
            maxLimit: nil,
            priority: priority.rawValue,
            spentAmount: 0
        )
    }

    private func computeMandatoryLivingMonthly(from settings: BudgetSettings) -> Double {
        settings.categories
            .flatMap(\.subcategories)
            .filter { mandatoryLivingCardNames.contains($0.name) }
            .reduce(0) { $0 + max(0, $1.minLimit ?? 0) }
    }

    private func computeMonthlyMinimumExcludingEmergency(from settings: BudgetSettings) -> Double {
        settings.categories.reduce(0.0) { partialResult, category in
            partialResult + category.subcategories.reduce(0.0) { subTotal, subcategory in
                if category.type == .savings && subcategory.name == "Подушка" {
                    return subTotal
                }
                return subTotal + max(0, subcategory.minLimit ?? 0)
            }
        }
    }

    private func buildWarnings(
        input: StartOnboardingInput,
        settings: BudgetSettings,
        categoryBudgets: [StartCategoryBudget],
        totalDeficit: Double
    ) -> [String] {
        var warnings: [String] = []
        let budgetsByType = Dictionary(uniqueKeysWithValues: categoryBudgets.map { ($0.type, $0.monthlyAmount) })

        for category in settings.categories {
            let minimumSum = category.subcategories.reduce(0.0) { $0 + max(0, $1.minLimit ?? 0) }
            let categoryBudget = budgetsByType[category.type, default: 0]
            if minimumSum > categoryBudget + 0.01 {
                warnings.append("Минимумы категории «\(category.type.title)» выше ее месячного бюджета. Разница будет покрываться из свободного капитала.")
            }
        }

        if totalDeficit > 0.01 {
            warnings.append("Текущего дохода и свободного капитала недостаточно, чтобы закрыть все обязательные минимумы сразу.")
        }

        if input.capital < 0 {
            warnings.append("Отрицательный капитал не идет в свободный капитал. Он учитывается через карточку «Долг».")
        }

        var seen = Set<String>()
        return warnings.filter { seen.insert($0).inserted }
    }

    private func buildDistribution(
        input: StartOnboardingInput,
        settings: BudgetSettings,
        allocatedBySubcategoryID: [UUID: Double],
        lastIncomeToBankByCategoryID: [UUID: Double],
        lastBankAutoDistributedBySubcategoryID: [UUID: Double],
        bankBalance: Double
    ) -> BudgetDistribution {
        let categoryAllocations: [CategoryAllocation] = settings.categories.map { category in
            let categoryAllocatedAmount = category.subcategories.reduce(0.0) { partialResult, subcategory in
                partialResult + allocatedBySubcategoryID[subcategory.id, default: 0]
            }

            let subcategoryAllocations: [SubcategoryAllocation] = category.subcategories.map { subcategory in
                let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
                let remaining = max(0, allocated - subcategory.spentAmount)
                let minimumTarget = allocationEngine.minimumFloorForRebalance(for: subcategory)
                let deficit = max(0, minimumTarget - remaining)

                return SubcategoryAllocation(
                    id: subcategory.id,
                    name: subcategory.name,
                    isSystem: subcategory.isSystem,
                    iconName: subcategory.iconName,
                    basePercentage: subcategory.percentage,
                    fixedMinimumPercentage: subcategory.fixedMinimumPercentage,
                    minLimit: subcategory.minLimit,
                    maxLimit: subcategory.maxLimit,
                    priority: subcategory.priority,
                    percentage: categoryAllocatedAmount > 0 ? (allocated / categoryAllocatedAmount) * 100.0 : 0,
                    allocatedAmount: roundToCents(allocated),
                    spentAmount: roundToCents(subcategory.spentAmount),
                    remainingAmount: roundToCents(remaining),
                    deficitAmount: roundToCents(deficit)
                )
            }

            return CategoryAllocation(
                id: category.id,
                type: category.type,
                percentage: category.percentage,
                allocatedAmount: roundToCents(categoryAllocatedAmount),
                lastIncomeToBankAmount: roundToCents(lastIncomeToBankByCategoryID[category.id, default: 0]),
                subcategoryAllocations: subcategoryAllocations,
                deficitAmount: roundToCents(subcategoryAllocations.reduce(0) { $0 + $1.deficitAmount })
            )
        }

        let subcategoryNameByID: [UUID: String] = settings.categories
            .flatMap(\.subcategories)
            .reduce(into: [:]) { partialResult, subcategory in
                partialResult[subcategory.id] = subcategory.name
            }

        let bankAutoLines = lastBankAutoDistributedBySubcategoryID
            .compactMap { (subcategoryID, amount) -> BankAutoDistributionLine? in
                guard amount > 0.0001, let name = subcategoryNameByID[subcategoryID] else { return nil }
                return BankAutoDistributionLine(
                    id: subcategoryID,
                    name: name,
                    amount: roundToCents(amount)
                )
            }
            .sorted { $0.amount > $1.amount }

        return BudgetDistribution(
            income: roundToCents(input.monthlyIncome),
            categoryAllocations: categoryAllocations,
            bankAmount: roundToCents(max(0, bankBalance)),
            lastBankAutoDistributions: bankAutoLines
        )
    }

    private func roundToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private static func defaultSystemIcon(for name: String) -> String {
        SubcategoryIconCatalog.defaultSystemIcon(for: name, isSystem: true)
    }

    private var mandatoryLivingCardNames: Set<String> {
        ["Жилье", "Питание", "Здоровье", "Дети", "Транспорт", "Долг", "Кредит"]
    }
}
