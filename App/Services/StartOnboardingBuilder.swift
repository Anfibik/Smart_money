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
        hasCar: Bool,
        childrenCount: Int,
        petsCount: Int,
        capital: Double,
        hasCredit: Bool
    ) -> [StartSystemCardDescriptor] {
        var cards: [StartSystemCardDescriptor] = [
            StartSystemCardDescriptor(
                categoryType: .essentials,
                name: SystemSubcategoryKey.housing.defaultName,
                iconName: defaultSystemIcon(for: .housing),
                note: housingType == .rented ? "Аренда, коммунальные, ремонт, клининг..." : "Коммунальные, ремонт, клининг..."
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                name: SystemSubcategoryKey.food.defaultName,
                iconName: defaultSystemIcon(for: .food),
                note: "Продукты, кафе, столовые, фастфуд..."
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                name: SystemSubcategoryKey.health.defaultName,
                iconName: defaultSystemIcon(for: .health),
                note: "Лекарства, витамины, бады, больницы, стоматология, пансионаты, процедуры"
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                name: SystemSubcategoryKey.hygiene.defaultName,
                iconName: defaultSystemIcon(for: .hygiene),
                note: "Парикмахерские, уход за телом и зубами..."
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: SystemSubcategoryKey.shopping.defaultName,
                iconName: defaultSystemIcon(for: .shopping),
                note: "Торговые центы, одежда, любой вид покупок"
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: SystemSubcategoryKey.hobby.defaultName,
                iconName: defaultSystemIcon(for: .hobby),
                note: "Затраты на любимое дело"
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: SystemSubcategoryKey.entertainment.defaultName,
                iconName: defaultSystemIcon(for: .entertainment),
                note: "Театры, прогулки, концерты, клубы..."
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: SystemSubcategoryKey.travel.defaultName,
                iconName: defaultSystemIcon(for: .travel),
                note: "Поездки, билеты, отпуск"
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: SystemSubcategoryKey.gifts.defaultName,
                iconName: defaultSystemIcon(for: .gifts),
                note: "Праздники, сюрпризы, внимание близким"
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                name: SystemSubcategoryKey.sport.defaultName,
                iconName: defaultSystemIcon(for: .sport),
                note: "Зал, секции, инвентарь"
            ),
            StartSystemCardDescriptor(
                categoryType: .savings,
                name: SystemSubcategoryKey.emergencyFund.defaultName,
                iconName: defaultSystemIcon(for: .emergencyFund),
                note: "Финансовая продушка на 6 месяцев проживания"
            )
        ]

        if childrenCount > 0 {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .essentials,
                    name: SystemSubcategoryKey.children.defaultName,
                    iconName: defaultSystemIcon(for: .children),
                    note: "Все детские расходы, кроме питания и здоровья"
                )
            )
        }

        cards.append(
            StartSystemCardDescriptor(
                categoryType: .essentials,
                name: SystemSubcategoryKey.transport.defaultName,
                iconName: hasCar ? "car.fill" : "tram.fill",
                note: hasCar ? "Бензин, ТО, ремонт, обслуживание, тюнинг" : "Общественный транспорт, такси"
            )
        )

        if petsCount > 0 {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .essentials,
                    name: SystemSubcategoryKey.animals.defaultName,
                    iconName: defaultSystemIcon(for: .animals),
                    note: "Корм, уход, ветврач"
                )
            )
        }

        if capital < 0 {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .savings,
                    name: SystemSubcategoryKey.debt.defaultName,
                    iconName: defaultSystemIcon(for: .debt),
                    note: "Создается при отрицательном капитале"
                )
            )
        }

        if hasCredit {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .savings,
                    name: SystemSubcategoryKey.credit.defaultName,
                    iconName: defaultSystemIcon(for: .credit),
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

        let housingPercentage = input.housingType == .rented ? 25.0 : 10.0
        let foodPercentage = 20.0
            + (Double(input.adultDependentsCount) * 4.0)
            + (Double(input.childrenCount) * 2.0)
        let healthPercentage = 3.0
        + (Double(input.adultDependentsCount) * 0.5)
        + (Double(input.childrenCount) * 1.0)
        + (Double(input.elderlyDependentsCount) * 5.0)
        let hygienePercentage = 5.0
        let childrenPercentage = input.childrenCount > 0 ? 10.0 : nil
        let animalsPercentage = input.petsCount > 0 ? 5.0 : nil
        let transportPercentage = input.hasCar ? 15.0 : 5.0
        let debtPercentage = input.capital < 0 ? 50.0 : nil
        let creditPercentage = input.hasCredit ? 10.0 : nil

        let housingMin = roundToCents(input.housingCost * 1.10)
        let foodMin = roundToCents(
            8000.0 * (1.0 + (Double(input.adultDependentsCount) * 0.8))
                + (Double(input.childrenCount) * 5000.0)
        )
        let healthMin = roundToCents(
            max(
                essentialsBudget * (healthPercentage / 100.0),
                Double(input.totalPeopleCount) * 500.0
            )
        )
        let hygieneMin = 500.0
        let childrenMin = roundToCents(essentialsBudget * ((childrenPercentage ?? 0) / 100.0))
        let animalsMin = roundToCents(Double(input.petsCount) * 1000.0)
        let transportMin = input.hasCar ? 2000.0 : 1000.0
        let shoppingMin = roundToCents(max(500.0, wantsBudget * 0.30))
        let hobbyMin = roundToCents(max(500.0, wantsBudget * 0.20))
        let entertainmentMin = roundToCents(wantsBudget * 0.20)
        let travelMin = 1000.0
        let giftsMin = 200.0
        let sportMin = 500.0
        let debtMin = roundToCents(max(savingsBudget * 0.50, abs(min(0, input.capital)) / 24.0))
        let creditMin = roundToCents(max(input.creditMonthlyPayment, savingsBudget * 0.10))

        let mandatoryLivingMonthly = housingMin + foodMin + healthMin + hygieneMin + childrenMin + animalsMin + transportMin + debtMin + creditMin
        let emergencyTarget = roundToCents(mandatoryLivingMonthly * 6.0)
        let emergencyMin = emergencyTarget
        let emergencyMaxLimit = roundToCents(mandatoryLivingMonthly * 12.0)

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
                    hygienePercentage: hygienePercentage,
                    hygieneMin: hygieneMin,
                    childrenPercentage: childrenPercentage,
                    childrenMin: childrenMin,
                    animalsPercentage: animalsPercentage,
                    animalsMin: animalsMin,
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
                    entertainmentMin: entertainmentMin,
                    travelMin: travelMin,
                    giftsMin: giftsMin,
                    sportMin: sportMin
                ) + buildCustomSubcategories(for: .wants, input: input, categoryBudget: wantsBudget)
            ),
            ExpenseCategory(
                type: .savings,
                percentage: input.strategy.categoryPercentages[.savings, default: 0],
                subcategories: savingsSubcategories(
                    emergencyMin: emergencyMin,
                    emergencyMaxLimit: emergencyMaxLimit,
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
        hygienePercentage: Double,
        hygieneMin: Double,
        childrenPercentage: Double?,
        childrenMin: Double,
        animalsPercentage: Double?,
        animalsMin: Double,
        transportPercentage: Double,
        transportMin: Double
    ) -> [Subcategory] {
        let housingPriority: SubcategoryPriorityLevel = housingPercentage > 10.0001 ? .high : .medium
        let foodPriority: SubcategoryPriorityLevel = housingPercentage > 10.0001 ? .medium : .high

        var cards: [Subcategory] = [
            systemSubcategory(
                systemKey: .housing,
                percentage: housingPercentage,
                minLimit: housingMin,
                priority: housingPriority
            ),
            systemSubcategory(
                systemKey: .food,
                percentage: foodPercentage,
                minLimit: foodMin,
                priority: foodPriority
            ),
            systemSubcategory(
                systemKey: .health,
                percentage: healthPercentage,
                minLimit: healthMin,
                priority: .medium
            ),
            systemSubcategory(
                systemKey: .hygiene,
                percentage: hygienePercentage,
                minLimit: hygieneMin,
                priority: .medium
            )
        ]

        if let childrenPercentage {
            cards.append(
                systemSubcategory(
                    systemKey: .children,
                    percentage: childrenPercentage,
                    minLimit: childrenMin,
                    priority: .medium
                )
            )
        }

        if let animalsPercentage {
            cards.append(
                systemSubcategory(
                    systemKey: .animals,
                    percentage: animalsPercentage,
                    minLimit: animalsMin,
                    priority: .medium
                )
            )
        }

        cards.append(
            systemSubcategory(
                systemKey: .transport,
                percentage: transportPercentage,
                minLimit: transportMin,
                iconName: transportPercentage >= 15 ? "car.fill" : "tram.fill",
                priority: .medium
            )
        )

        return cards
    }

    private func wantsSubcategories(
        shoppingMin: Double,
        hobbyMin: Double,
        entertainmentMin: Double,
        travelMin: Double,
        giftsMin: Double,
        sportMin: Double
    ) -> [Subcategory] {
        [
            systemSubcategory(
                systemKey: .shopping,
                percentage: 30,
                minLimit: shoppingMin,
                priority: .high
            ),
            systemSubcategory(
                systemKey: .hobby,
                percentage: 20,
                minLimit: hobbyMin,
                priority: .medium
            ),
            systemSubcategory(
                systemKey: .entertainment,
                percentage: 20,
                minLimit: entertainmentMin,
                priority: .medium
            ),
            systemSubcategory(
                systemKey: .travel,
                percentage: 10,
                minLimit: travelMin,
                priority: .medium
            ),
            systemSubcategory(
                systemKey: .gifts,
                percentage: 5,
                minLimit: giftsMin,
                priority: .medium
            ),
            systemSubcategory(
                systemKey: .sport,
                percentage: 5,
                minLimit: sportMin,
                priority: .medium
            )
        ]
    }

    private func savingsSubcategories(
        emergencyMin: Double,
        emergencyMaxLimit: Double,
        debtPercentage: Double?,
        debtMin: Double,
        creditPercentage: Double?,
        creditMin: Double
    ) -> [Subcategory] {
        var cards: [Subcategory] = [
            systemSubcategory(
                systemKey: .emergencyFund,
                percentage: 50,
                minLimit: emergencyMin,
                maxLimit: emergencyMaxLimit,
                priority: .high
            )
        ]

        if let debtPercentage {
            cards.append(
                systemSubcategory(
                    systemKey: .debt,
                    percentage: debtPercentage,
                    minLimit: debtMin,
                    priority: .medium
                )
            )
        }

        if let creditPercentage {
            cards.append(
                systemSubcategory(
                    systemKey: .credit,
                    percentage: creditPercentage,
                    minLimit: creditMin,
                    priority: .medium
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
        systemKey: SystemSubcategoryKey,
        percentage: Double,
        minLimit: Double,
        maxLimit: Double? = nil,
        iconName: String? = nil,
        priority: SubcategoryPriorityLevel
    ) -> Subcategory {
        Subcategory(
            name: systemKey.defaultName,
            isSystem: true,
            systemKey: systemKey,
            iconName: iconName ?? Self.defaultSystemIcon(for: systemKey),
            percentage: percentage,
            fixedMinimumPercentage: nil,
            minLimit: max(0, minLimit),
            maxLimit: maxLimit.map { max(0, $0) },
            priority: priority.rawValue,
            spentAmount: 0
        )
    }

    private func computeMandatoryLivingMonthly(from settings: BudgetSettings) -> Double {
        settings.categories
            .flatMap(\.subcategories)
            .filter { subcategory in
                guard let systemKey = subcategory.systemKey else { return false }
                return mandatoryLivingSystemKeys.contains(systemKey)
            }
            .reduce(0) { $0 + max(0, $1.minLimit ?? 0) }
    }

    private func computeMonthlyMinimumExcludingEmergency(from settings: BudgetSettings) -> Double {
        settings.categories.reduce(0.0) { partialResult, category in
            partialResult + category.subcategories.reduce(0.0) { subTotal, subcategory in
                if category.type == .savings && subcategory.systemKey == .emergencyFund {
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
            let minimumSum = category.subcategories.reduce(0.0) { partialResult, subcategory in
                if category.type == .savings && subcategory.systemKey == .emergencyFund {
                    return partialResult
                }
                return partialResult + max(0, subcategory.minLimit ?? 0)
            }
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
                    deficitAmount: roundToCents(deficit),
                    monthlyIncomeAmount: roundToCents(allocated),
                    monthlyExpenseAmount: roundToCents(subcategory.spentAmount)
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

    private static func defaultSystemIcon(for systemKey: SystemSubcategoryKey) -> String {
        SubcategoryIconCatalog.defaultSystemIcon(for: systemKey, isSystem: true)
    }

    private var mandatoryLivingSystemKeys: Set<SystemSubcategoryKey> {
        [.housing, .food, .health, .hygiene, .children, .animals, .transport, .debt, .credit]
    }
}
