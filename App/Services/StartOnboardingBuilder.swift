import Foundation

struct StartOnboardingBuilder {
    private let allocationEngine = BudgetAllocationEngine()

    func buildPreview(
        input: StartOnboardingInput,
        coverDeficitsFromFreeCapital: Bool = false
    ) -> StartOnboardingPreview {
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

        let distributionBeforeCoverage = buildDistribution(
            input: input,
            settings: settings,
            allocatedBySubcategoryID: allocatedBySubcategoryID,
            lastIncomeToBankByCategoryID: lastIncomeToBankByCategoryID,
            lastBankAutoDistributedBySubcategoryID: lastBankAutoDistributedBySubcategoryID,
            bankBalance: bankBalance
        )
        let deficitBeforeCoverage = distributionBeforeCoverage.categoryAllocations.reduce(0) {
            $0 + $1.deficitAmount
        }
        let shouldCoverDeficits = coverDeficitsFromFreeCapital
            && bankBalance > 0.0001
            && deficitBeforeCoverage > 0.01
        let freeCapitalBeforeCoverage = bankBalance

        if shouldCoverDeficits {
            allocationEngine.coverOnboardingDeficitsFromBank(
                settings: settings,
                allocatedBySubcategoryID: &allocatedBySubcategoryID,
                bankBalance: &bankBalance,
                distributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID
            )
        }

        let distribution = shouldCoverDeficits
            ? buildDistribution(
                input: input,
                settings: settings,
                allocatedBySubcategoryID: allocatedBySubcategoryID,
                lastIncomeToBankByCategoryID: lastIncomeToBankByCategoryID,
                lastBankAutoDistributedBySubcategoryID: lastBankAutoDistributedBySubcategoryID,
                bankBalance: bankBalance
            )
            : distributionBeforeCoverage

        let mandatoryLivingMonthly = roundToCents(computeMandatoryLivingMonthly(from: settings))
        let monthlyMinimumExcludingEmergency = roundToCents(computeMonthlyMinimumExcludingEmergency(from: settings))
        let emergencyTarget = roundToCents(mandatoryLivingMonthly * 6)
        let remainingFreeCapital = roundToCents(max(0, bankBalance))
        let capitalAppliedToMinimums = roundToCents(
            max(0, freeCapitalBeforeCoverage - bankBalance)
        )
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
            coversDeficitsFromFreeCapital: shouldCoverDeficits,
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
                totalDeficit: totalDeficit,
                remainingFreeCapital: remainingFreeCapital
            )
        )
    }

    func onboardingCardDescriptors(for input: StartOnboardingInput) -> [StartSystemCardDescriptor] {
        onboardingCardDescriptors(for: input, categoryBudgets: buildCategoryBudgets(for: input))
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
        let activeDescriptorsByCategory = Dictionary(
            grouping: onboardingCardDescriptors(for: input, categoryBudgets: categoryBudgets).filter(\.isActive),
            by: \.categoryType
        )

        var categories = ExpenseCategoryType.allCases.map { categoryType in
            ExpenseCategory(
                type: categoryType,
                percentage: input.strategy.categoryPercentages[categoryType, default: 0],
                subcategories: activeDescriptorsByCategory[categoryType, default: []].map(subcategory(from:))
                    + buildCustomSubcategories(
                        for: categoryType,
                        input: input,
                        categoryBudget: budgetsByType[categoryType, default: 0]
                    )
            )
        }

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

    private func onboardingCardDescriptors(
        for input: StartOnboardingInput,
        categoryBudgets: [StartCategoryBudget]
    ) -> [StartSystemCardDescriptor] {
        let budgetsByType = Dictionary(uniqueKeysWithValues: categoryBudgets.map { ($0.type, $0.monthlyAmount) })
        let essentialsBudget = budgetsByType[.essentials, default: 0]
        let selectedRecommendations = Set(input.selectedRecommendationKeys)

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
        let animalsPercentage = input.petsCount > 0 ? 3.0 : nil
        let transportPercentage = input.hasCar ? 10.0 : 5.0
        let hasDebt = input.capital < 0

        let housingMin = roundToCents(input.housingCost)
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
        let creditMin = roundToCents(input.creditMonthlyPayment)

        let mandatoryLivingMonthly = housingMin + foodMin + healthMin + hygieneMin + childrenMin + animalsMin + transportMin + creditMin
        let emergencyTarget = roundToCents(mandatoryLivingMonthly * 6.0)

        var cards: [StartSystemCardDescriptor] = [
            StartSystemCardDescriptor(
                categoryType: .essentials,
                systemKey: .housing,
                name: SystemSubcategoryKey.housing.defaultName,
                iconName: Self.defaultSystemIcon(for: .housing),
                note: input.housingType == .rented ? "Аренда, коммунальные, ремонт, клининг..." : "Коммунальные, ремонт, клининг...",
                basePercentage: housingPercentage,
                minLimit: housingMin,
                maxLimit: nil,
                priority: housingPercentage > 10.0001 ? .high : .medium,
                isRecommended: false,
                isActive: true
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                systemKey: .food,
                name: SystemSubcategoryKey.food.defaultName,
                iconName: Self.defaultSystemIcon(for: .food),
                note: "Продукты, кафе, столовые, фастфуд...",
                basePercentage: foodPercentage,
                minLimit: foodMin,
                maxLimit: nil,
                priority: housingPercentage > 10.0001 ? .medium : .high,
                isRecommended: false,
                isActive: true
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                systemKey: .health,
                name: SystemSubcategoryKey.health.defaultName,
                iconName: Self.defaultSystemIcon(for: .health),
                note: "Лекарства, витамины, бады, больницы, стоматология, пансионаты, процедуры",
                basePercentage: healthPercentage,
                minLimit: healthMin,
                maxLimit: nil,
                priority: .medium,
                isRecommended: false,
                isActive: true
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                systemKey: .hygiene,
                name: SystemSubcategoryKey.hygiene.defaultName,
                iconName: Self.defaultSystemIcon(for: .hygiene),
                note: "Парикмахерские, уход за телом и зубами...",
                basePercentage: hygienePercentage,
                minLimit: hygieneMin,
                maxLimit: nil,
                priority: .medium,
                isRecommended: false,
                isActive: true
            ),
            StartSystemCardDescriptor(
                categoryType: .essentials,
                systemKey: .transport,
                name: SystemSubcategoryKey.transport.defaultName,
                iconName: input.hasCar ? "car.fill" : "tram.fill",
                note: input.hasCar ? "Бензин, ТО, ремонт, обслуживание, тюнинг" : "Общественный транспорт, такси",
                basePercentage: transportPercentage,
                minLimit: transportMin,
                maxLimit: nil,
                priority: .medium,
                isRecommended: false,
                isActive: true
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                systemKey: .shopping,
                name: SystemSubcategoryKey.shopping.defaultName,
                iconName: Self.defaultSystemIcon(for: .shopping),
                note: "Торговые центы, одежда, любой вид покупок",
                basePercentage: 15,
                minLimit: 0,
                maxLimit: nil,
                priority: .high,
                isRecommended: false,
                isActive: true
            ),
            StartSystemCardDescriptor(
                categoryType: .wants,
                systemKey: .entertainment,
                name: SystemSubcategoryKey.entertainment.defaultName,
                iconName: Self.defaultSystemIcon(for: .entertainment),
                note: "Театры, прогулки, концерты, клубы...",
                basePercentage: 10,
                minLimit: 0,
                maxLimit: nil,
                priority: .medium,
                isRecommended: false,
                isActive: true
            ),
            StartSystemCardDescriptor(
                categoryType: .savings,
                systemKey: .emergencyFund,
                name: SystemSubcategoryKey.emergencyFund.defaultName,
                iconName: Self.defaultSystemIcon(for: .emergencyFund),
                note: "Финансовая продушка на 6 месяцев проживания",
                basePercentage: 50,
                minLimit: emergencyTarget,
                maxLimit: emergencyTarget,
                priority: hasDebt ? .medium : .high,
                isRecommended: false,
                isActive: true
            ),
            recommendationDescriptor(
                categoryType: .wants,
                systemKey: .hobby,
                note: "Затраты на любимое дело",
                basePercentage: 5,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .wants,
                systemKey: .travel,
                note: "Поездки, билеты, отпуск",
                basePercentage: 10,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .wants,
                systemKey: .restaurants,
                note: "Кафе, рестораны, доставки и встречи вне дома",
                basePercentage: 20,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .wants,
                systemKey: .gifts,
                note: "Праздники, сюрпризы, внимание близким",
                basePercentage: 5,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .wants,
                systemKey: .sport,
                note: "Зал, секции, инвентарь",
                basePercentage: 20,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .wants,
                systemKey: .beauty,
                note: "Косметика, уход, салоны и процедуры",
                basePercentage: 5,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .wants,
                systemKey: .subscriptions,
                note: "Сервисы, приложения и регулярные подписки",
                basePercentage: 5,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .savings,
                systemKey: .investments,
                note: "Инвестиционные цели и долгосрочный рост капитала",
                basePercentage: 10,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .savings,
                systemKey: .business,
                note: "Запуск и развитие собственного дела",
                basePercentage: 20,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .savings,
                systemKey: .currency,
                note: "Валютная подушка и защита от курсовых рисков",
                basePercentage: 20,
                minLimit: 0,
                selectedRecommendations: selectedRecommendations
            ),
            recommendationDescriptor(
                categoryType: .savings,
                systemKey: .goal,
                note: "Крупная цель: квартира, дом, автомобиль или обучение ребёнка",
                basePercentage: 20,
                minLimit: 0,
                maxLimit: input.goalTargetAmount > 0 ? input.goalTargetAmount : nil,
                selectedRecommendations: selectedRecommendations
            )
        ]

        if let childrenPercentage {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .essentials,
                    systemKey: .children,
                    name: SystemSubcategoryKey.children.defaultName,
                    iconName: Self.defaultSystemIcon(for: .children),
                    note: "Все детские расходы, кроме питания и здоровья",
                    basePercentage: childrenPercentage,
                    minLimit: childrenMin,
                    maxLimit: nil,
                    priority: .medium,
                    isRecommended: false,
                    isActive: true
                )
            )
        }

        if let animalsPercentage {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .essentials,
                    systemKey: .animals,
                    name: SystemSubcategoryKey.animals.defaultName,
                    iconName: Self.defaultSystemIcon(for: .animals),
                    note: "Корм, уход, ветврач",
                    basePercentage: animalsPercentage,
                    minLimit: animalsMin,
                    maxLimit: nil,
                    priority: .medium,
                    isRecommended: false,
                    isActive: true
                )
            )
        }

        if hasDebt {
            let debtAmount = roundToCents(abs(min(0, input.capital)))
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .savings,
                    systemKey: .debt,
                    name: SystemSubcategoryKey.debt.defaultName,
                    iconName: Self.defaultSystemIcon(for: .debt),
                    note: "Создается при отрицательном капитале",
                    basePercentage: 100,
                    minLimit: debtAmount,
                    maxLimit: debtAmount,
                    priority: .high,
                    isRecommended: false,
                    isActive: true
                )
            )
        }

        if input.hasCredit {
            cards.append(
                StartSystemCardDescriptor(
                    categoryType: .savings,
                    systemKey: .credit,
                    name: SystemSubcategoryKey.credit.defaultName,
                    iconName: Self.defaultSystemIcon(for: .credit),
                    note: "Создается при наличии ежемесячного платежа",
                    basePercentage: 10,
                    minLimit: creditMin,
                    maxLimit: nil,
                    priority: .medium,
                    isRecommended: false,
                    isActive: true
                )
            )
        }

        return ExpenseCategoryType.allCases.flatMap { categoryType in
            cards.filter { $0.categoryType == categoryType }
        }
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
            minLimit: minLimit > 0 ? minLimit : nil,
            maxLimit: maxLimit.map { max(0, $0) },
            priority: priority.rawValue,
            spentAmount: 0
        )
    }

    private func subcategory(from descriptor: StartSystemCardDescriptor) -> Subcategory {
        systemSubcategory(
            systemKey: descriptor.systemKey,
            percentage: descriptor.basePercentage,
            minLimit: descriptor.minLimit,
            maxLimit: descriptor.maxLimit,
            iconName: descriptor.iconName,
            priority: descriptor.priority
        )
    }

    private func recommendationDescriptor(
        categoryType: ExpenseCategoryType,
        systemKey: SystemSubcategoryKey,
        note: String,
        basePercentage: Double,
        minLimit: Double,
        maxLimit: Double? = nil,
        selectedRecommendations: Set<SystemSubcategoryKey>
    ) -> StartSystemCardDescriptor {
        StartSystemCardDescriptor(
            categoryType: categoryType,
            systemKey: systemKey,
            name: systemKey.defaultName,
            iconName: Self.defaultSystemIcon(for: systemKey),
            note: note,
            basePercentage: basePercentage,
            minLimit: minLimit,
            maxLimit: maxLimit,
            priority: .medium,
            isRecommended: true,
            isActive: selectedRecommendations.contains(systemKey)
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
                if category.type == .savings
                    && (subcategory.systemKey == .emergencyFund || subcategory.systemKey == .debt) {
                    return subTotal
                }
                return subTotal + max(0, subcategory.minLimit ?? 0)
            }
        }
    }

    private func buildWarnings(
        input: StartOnboardingInput,
        settings: BudgetSettings,
        totalDeficit: Double,
        remainingFreeCapital: Double
    ) -> [String] {
        var warnings: [String] = []
        let monthlyMinimum = roundToCents(computeMonthlyMinimumExcludingEmergency(from: settings))
        if monthlyMinimum > input.monthlyIncome + 0.01 {
            let shortfall = roundToCents(monthlyMinimum - input.monthlyIncome)
            warnings.append(
                "Доход ниже общей суммы обязательных минимумов на \(formattedWarningCurrency(shortfall)) в месяц."
            )
        }

        if totalDeficit > 0.01 {
            if remainingFreeCapital > 0.01 {
                warnings.append(
                    "Не покрыты минимальные суммы на \(formattedWarningCurrency(totalDeficit)). Их можно покрыть из свободного капитала на итоговом экране."
                )
            } else {
                warnings.append(
                    "После распределения не покрыты минимальные суммы на \(formattedWarningCurrency(totalDeficit)). Скорректируйте стратегию, минимумы или доход."
                )
            }
        }

        if input.capital < 0 {
            warnings.append("Отрицательный капитал не идет в свободный капитал. Он учитывается через карточку «Долг».")
        }

        var seen = Set<String>()
        return warnings.filter { seen.insert($0).inserted }
    }

    private func formattedWarningCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","

        let amount = formatter.string(from: NSNumber(value: roundToCents(max(0, value))))
            ?? String(format: "%.2f", max(0, value))
        return "\(amount) ₴"
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
                    systemKey: subcategory.systemKey,
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
                    monthlyIncomeDistributionAmount: roundToCents(allocated),
                    monthlyOtherIncomingAmount: 0,
                    monthlyExpenseAmount: roundToCents(subcategory.spentAmount),
                    monthlyOtherOutgoingAmount: 0
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
        [.housing, .food, .health, .hygiene, .children, .animals, .transport, .credit]
    }
}
