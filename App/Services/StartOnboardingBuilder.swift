import Foundation

struct StartOnboardingBuilder {
    private let allocationEngine: BudgetAllocationEngine
    private let cardCatalog: SystemCardCatalog

    init(
        allocationEngine: BudgetAllocationEngine = BudgetAllocationEngine(),
        cardCatalog: SystemCardCatalog = .standard
    ) {
        self.allocationEngine = allocationEngine
        self.cardCatalog = cardCatalog
    }

    func buildPreview(
        input: StartOnboardingInput,
        capitalCoveragePolicy: FreeCapitalCoveragePolicy = .none
    ) -> StartOnboardingPreview {
        let input = input.roundedForInitialFormation()
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
        seedManualBalances(
            input: input,
            settings: settings,
            allocatedBySubcategoryID: &allocatedBySubcategoryID
        )
        var lastIncomeToBankByCategoryID = Dictionary(
            uniqueKeysWithValues: settings.categories.map { ($0.id, 0.0) }
        )
        var lastBankAutoDistributedBySubcategoryID: [UUID: Double] = [:]
        let initialDistributionAmount = min(input.monthlyIncome, input.positiveCapital)
        var bankBalance = max(0, input.positiveCapital - initialDistributionAmount)

        if initialDistributionAmount > 0 {
            allocationEngine.applyIncomeDelta(
                initialDistributionAmount,
                settings: settings,
                categoryTargetBaselineByID: &categoryTargetBaselineByID,
                allocatedBySubcategoryID: &allocatedBySubcategoryID,
                bankBalance: &bankBalance,
                lastIncomeToBankByCategoryID: &lastIncomeToBankByCategoryID,
                lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID
            )
        }
        roundInitialFormationMoney(
            settings: settings,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance,
            lastIncomeToBankByCategoryID: &lastIncomeToBankByCategoryID,
            lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID
        )

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
        let shouldApplyCoverage = capitalCoveragePolicy.isEnabled
            && bankBalance > 0.0001
            && deficitBeforeCoverage > 0.01
        let freeCapitalBeforeCoverage = bankBalance

        if shouldApplyCoverage {
            allocationEngine.coverOnboardingDeficitsFromBank(
                settings: settings,
                policy: capitalCoveragePolicy,
                allocatedBySubcategoryID: &allocatedBySubcategoryID,
                bankBalance: &bankBalance,
                distributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID
            )
            roundInitialFormationMoney(
                settings: settings,
                allocatedBySubcategoryID: &allocatedBySubcategoryID,
                bankBalance: &bankBalance,
                lastIncomeToBankByCategoryID: &lastIncomeToBankByCategoryID,
                lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID
            )
        }

        let distribution = shouldApplyCoverage
            ? buildDistribution(
                input: input,
                settings: settings,
                allocatedBySubcategoryID: allocatedBySubcategoryID,
                lastIncomeToBankByCategoryID: lastIncomeToBankByCategoryID,
                lastBankAutoDistributedBySubcategoryID: lastBankAutoDistributedBySubcategoryID,
                bankBalance: bankBalance
            )
            : distributionBeforeCoverage

        let mandatoryLivingMonthly = roundToWholeHryvnia(computeMandatoryLivingMonthly(from: settings))
        let monthlyMinimumExcludingEmergency = roundToWholeHryvnia(computeMonthlyMinimumExcludingEmergency(from: settings))
        let emergencyTarget = roundToWholeHryvnia(mandatoryLivingMonthly * 6)
        let remainingFreeCapital = roundToWholeHryvnia(max(0, bankBalance))
        let capitalAppliedToMinimums = roundToWholeHryvnia(
            max(0, freeCapitalBeforeCoverage - bankBalance)
        )
        let appliedCoveragePolicy = capitalAppliedToMinimums > 0.01
            ? capitalCoveragePolicy
            : .none
        let totalDeficit = roundToWholeHryvnia(distribution.categoryAllocations.reduce(0) { $0 + $1.deficitAmount })
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
            capitalCoveragePolicy: appliedCoveragePolicy,
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
                monthlyAmount: roundToWholeHryvnia(input.monthlyIncome * (percentage / 100.0))
            )
        }
    }

    private func buildSettings(
        for input: StartOnboardingInput,
        categoryBudgets: [StartCategoryBudget]
    ) -> BudgetSettings {
        let budgetsByType = Dictionary(uniqueKeysWithValues: categoryBudgets.map { ($0.type, $0.monthlyAmount) })
        let descriptors = onboardingCardDescriptors(for: input, categoryBudgets: categoryBudgets)
        let activeDescriptorsByCategory = Dictionary(
            grouping: descriptors.filter(\.isActive),
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

        let recommendationTemplates = descriptors
            .filter(\.isRecommended)
            .map { descriptor in
                RecommendedCardTemplate(
                    systemKey: descriptor.systemKey,
                    categoryType: descriptor.categoryType,
                    name: descriptor.name,
                    iconName: descriptor.iconName,
                    description: descriptor.note
                        ?? cardCatalog.description(for: descriptor.systemKey),
                    percentage: descriptor.basePercentage,
                    minLimit: descriptor.minLimit > 0 ? descriptor.minLimit : nil,
                    maxLimit: descriptor.maxLimit,
                    priority: descriptor.priority.rawValue,
                    fundingMode: descriptor.fundingMode,
                    balanceCurrencyCode: descriptor.balanceCurrencyCode
                )
            }

        return BudgetSettings(
            categories: categories,
            currencyCode: "UAH",
            recommendationTemplates: recommendationTemplates
        )
    }

    private func onboardingCardDescriptors(
        for input: StartOnboardingInput,
        categoryBudgets: [StartCategoryBudget]
    ) -> [StartSystemCardDescriptor] {
        let budgetsByType = Dictionary(uniqueKeysWithValues: categoryBudgets.map { ($0.type, $0.monthlyAmount) })
        let essentialsBudget = budgetsByType[.essentials, default: 0]
        let selectedRecommendations = Set(input.selectedRecommendationKeys)
        let presentationContext = SystemCardPresentationContext(
            housingIsRented: input.housingType == .rented,
            hasCar: input.hasCar
        )

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

        let housingMin = roundToWholeHryvnia(input.housingCost)
        let foodMin = roundToWholeHryvnia(
            8000.0 * (1.0 + (Double(input.adultDependentsCount) * 0.8))
                + (Double(input.childrenCount) * 5000.0)
        )
        let healthMin = roundToWholeHryvnia(
            max(
                essentialsBudget * (healthPercentage / 100.0),
                Double(input.totalPeopleCount) * 500.0
            )
        )
        let hygieneMin = 500.0
        let childrenMin = roundToWholeHryvnia(essentialsBudget * ((childrenPercentage ?? 0) / 100.0))
        let animalsMin = roundToWholeHryvnia(Double(input.petsCount) * 1000.0)
        let transportMin = input.hasCar ? 2000.0 : 1000.0
        let creditMin = roundToWholeHryvnia(input.creditMonthlyPayment)

        let mandatoryLivingMonthly = housingMin + foodMin + healthMin + hygieneMin + childrenMin + animalsMin + transportMin + creditMin
        let emergencyTarget = roundToWholeHryvnia(mandatoryLivingMonthly * 6.0)

        var cards: [StartSystemCardDescriptor] = [
            activeDescriptor(
                systemKey: .housing,
                percentage: housingPercentage,
                minLimit: housingMin,
                priority: housingPercentage > 10.0001 ? .high : .medium,
                context: presentationContext
            ),
            activeDescriptor(
                systemKey: .food,
                percentage: foodPercentage,
                minLimit: foodMin,
                priority: housingPercentage > 10.0001 ? .medium : .high,
                context: presentationContext
            ),
            activeDescriptor(
                systemKey: .health,
                percentage: healthPercentage,
                minLimit: healthMin,
                context: presentationContext
            ),
            activeDescriptor(
                systemKey: .hygiene,
                percentage: hygienePercentage,
                minLimit: hygieneMin,
                context: presentationContext
            ),
            activeDescriptor(
                systemKey: .transport,
                percentage: transportPercentage,
                minLimit: transportMin,
                iconName: input.hasCar ? "car.fill" : "tram.fill",
                context: presentationContext
            ),
            activeDescriptor(
                systemKey: .shopping,
                context: presentationContext
            ),
            activeDescriptor(
                systemKey: .entertainment,
                context: presentationContext
            ),
            activeDescriptor(
                systemKey: .emergencyFund,
                minLimit: emergencyTarget,
                maxLimit: emergencyTarget,
                priority: hasDebt ? .medium : .high,
                context: presentationContext
            )
        ]

        cards += cardCatalog.recommendedDefinitions.map { definition in
            recommendationDescriptor(
                definition: definition,
                maxLimit: definition.systemKey == .goal && input.goalTargetAmount > 0
                    ? input.goalTargetAmount
                    : nil,
                balanceCurrencyCode: definition.systemKey == .currency
                    ? input.foreignCurrency.rawValue
                    : nil,
                selectedRecommendations: selectedRecommendations
            )
        }

        if let childrenPercentage {
            cards.append(
                activeDescriptor(
                    systemKey: .children,
                    percentage: childrenPercentage,
                    minLimit: childrenMin,
                    context: presentationContext
                )
            )
        }

        if let animalsPercentage {
            cards.append(
                activeDescriptor(
                    systemKey: .animals,
                    percentage: animalsPercentage,
                    minLimit: animalsMin,
                    context: presentationContext
                )
            )
        }

        if hasDebt {
            let debtAmount = roundToWholeHryvnia(abs(min(0, input.capital)))
            cards.append(
                activeDescriptor(
                    systemKey: .debt,
                    percentage: 100,
                    minLimit: debtAmount,
                    maxLimit: debtAmount,
                    priority: .high,
                    context: presentationContext
                )
            )
        }

        if input.hasCredit {
            cards.append(
                activeDescriptor(
                    systemKey: .credit,
                    percentage: 10,
                    minLimit: creditMin,
                    context: presentationContext
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
                    minLimit: roundToWholeHryvnia(custom.minLimit),
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
        priority: SubcategoryPriorityLevel,
        fundingMode: SubcategoryFundingMode = .automatic,
        balanceCurrencyCode: String? = nil,
        isRequired: Bool = true
    ) -> Subcategory {
        Subcategory(
            name: systemKey.defaultName,
            isSystem: true,
            isRequired: isRequired,
            systemKey: systemKey,
            iconName: iconName ?? cardCatalog.definition(for: systemKey).iconName,
            percentage: percentage,
            fixedMinimumPercentage: nil,
            minLimit: minLimit > 0 ? minLimit : nil,
            maxLimit: maxLimit.map { max(0, $0) },
            priority: priority.rawValue,
            fundingMode: fundingMode,
            balanceCurrencyCode: balanceCurrencyCode,
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
            priority: descriptor.priority,
            fundingMode: descriptor.fundingMode,
            balanceCurrencyCode: descriptor.balanceCurrencyCode,
            isRequired: !descriptor.isRecommended
        )
    }

    private func activeDescriptor(
        systemKey: SystemSubcategoryKey,
        percentage: Double? = nil,
        minLimit: Double? = nil,
        maxLimit: Double? = nil,
        priority: SubcategoryPriorityLevel? = nil,
        iconName: String? = nil,
        context: SystemCardPresentationContext
    ) -> StartSystemCardDescriptor {
        let definition = cardCatalog.definition(for: systemKey)

        return StartSystemCardDescriptor(
            categoryType: definition.categoryType,
            systemKey: systemKey,
            name: definition.name,
            iconName: iconName ?? definition.iconName,
            note: cardCatalog.description(for: systemKey, context: context),
            basePercentage: percentage ?? definition.defaultPercentage,
            minLimit: minLimit ?? definition.defaultMinLimit,
            maxLimit: maxLimit,
            priority: priority ?? definition.defaultPriority,
            fundingMode: definition.fundingMode,
            balanceCurrencyCode: nil,
            isRecommended: false,
            isActive: true
        )
    }

    private func recommendationDescriptor(
        definition: SystemCardDefinition,
        maxLimit: Double? = nil,
        balanceCurrencyCode: String? = nil,
        selectedRecommendations: Set<SystemSubcategoryKey>
    ) -> StartSystemCardDescriptor {
        StartSystemCardDescriptor(
            categoryType: definition.categoryType,
            systemKey: definition.systemKey,
            name: definition.name,
            iconName: definition.iconName,
            note: definition.description,
            basePercentage: definition.defaultPercentage,
            minLimit: definition.defaultMinLimit,
            maxLimit: maxLimit,
            priority: definition.defaultPriority,
            fundingMode: definition.fundingMode,
            balanceCurrencyCode: balanceCurrencyCode,
            isRecommended: true,
            isActive: selectedRecommendations.contains(definition.systemKey)
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
        } else if input.positiveCapital + 0.01 < input.monthlyIncome {
            let shortfall = input.monthlyIncome - input.positiveCapital
            warnings.append(
                "Для полного стартового распределения не хватает \(formattedWarningCurrency(shortfall)) текущего капитала."
            )
        }

        var seen = Set<String>()
        return warnings.filter { seen.insert($0).inserted }
    }

    private func formattedWarningCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        formatter.decimalSeparator = ","

        let amount = formatter.string(from: NSNumber(value: roundToWholeHryvnia(max(0, value))))
            ?? String(format: "%.0f", max(0, value))
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
            let categoryAllocatedAmount = category.subcategories
                .filter(\.participatesInAutomaticAllocation)
                .reduce(0.0) { partialResult, subcategory in
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
                    isRequired: subcategory.isRequired,
                    systemKey: subcategory.systemKey,
                    iconName: subcategory.iconName,
                    basePercentage: subcategory.percentage,
                    fixedMinimumPercentage: subcategory.fixedMinimumPercentage,
                    minLimit: subcategory.minLimit,
                    maxLimit: subcategory.maxLimit,
                    priority: subcategory.priority,
                    fundingMode: subcategory.fundingMode,
                    balanceCurrencyCode: subcategory.balanceCurrencyCode,
                    percentage: subcategory.participatesInAutomaticAllocation && categoryAllocatedAmount > 0
                        ? (allocated / categoryAllocatedAmount) * 100.0
                        : 0,
                    allocatedAmount: roundToWholeHryvnia(allocated),
                    spentAmount: roundToWholeHryvnia(subcategory.spentAmount),
                    remainingAmount: roundToWholeHryvnia(remaining),
                    deficitAmount: roundToWholeHryvnia(deficit),
                    monthlyIncomeAmount: subcategory.participatesInAutomaticAllocation ? roundToWholeHryvnia(allocated) : 0,
                    monthlyIncomeDistributionAmount: subcategory.participatesInAutomaticAllocation ? roundToWholeHryvnia(allocated) : 0,
                    monthlyOtherIncomingAmount: 0,
                    monthlyExpenseAmount: roundToWholeHryvnia(subcategory.spentAmount),
                    monthlyOtherOutgoingAmount: 0
                )
            }

            return CategoryAllocation(
                id: category.id,
                type: category.type,
                percentage: category.percentage,
                allocatedAmount: roundToWholeHryvnia(categoryAllocatedAmount),
                lastIncomeToBankAmount: roundToWholeHryvnia(lastIncomeToBankByCategoryID[category.id, default: 0]),
                subcategoryAllocations: subcategoryAllocations,
                deficitAmount: roundToWholeHryvnia(subcategoryAllocations.reduce(0) { $0 + $1.deficitAmount })
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
                    amount: roundToWholeHryvnia(amount)
                )
            }
            .sorted { $0.amount > $1.amount }

        return BudgetDistribution(
            income: roundToWholeHryvnia(input.monthlyIncome),
            categoryAllocations: categoryAllocations,
            bankAmount: roundToWholeHryvnia(max(0, bankBalance)),
            lastBankAutoDistributions: bankAutoLines
        )
    }

    private func roundToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private func roundToWholeHryvnia(_ value: Double) -> Double {
        value.rounded()
    }

    private func roundInitialFormationMoney(
        settings: BudgetSettings,
        allocatedBySubcategoryID: inout [UUID: Double],
        bankBalance: inout Double,
        lastIncomeToBankByCategoryID: inout [UUID: Double],
        lastBankAutoDistributedBySubcategoryID: inout [UUID: Double]
    ) {
        let allocationTotalBefore = allocatedBySubcategoryID.values.reduce(0, +)

        InitialFormationMoneyRounder.roundAllocations(
            settings: settings,
            allocations: &allocatedBySubcategoryID
        )

        let allocationTotalAfter = allocatedBySubcategoryID.values.reduce(0, +)
        bankBalance = roundToWholeHryvnia(max(0, bankBalance + allocationTotalBefore - allocationTotalAfter))
        lastIncomeToBankByCategoryID = lastIncomeToBankByCategoryID.mapValues(roundToWholeHryvnia)
        lastBankAutoDistributedBySubcategoryID = lastBankAutoDistributedBySubcategoryID.mapValues(roundToWholeHryvnia)
    }

    private func seedManualBalances(
        input: StartOnboardingInput,
        settings: BudgetSettings,
        allocatedBySubcategoryID: inout [UUID: Double]
    ) {
        guard input.foreignCurrencyAmount > 0 else { return }
        guard let currencyCard = settings.categories
            .flatMap(\.subcategories)
            .first(where: { $0.systemKey == .currency && $0.fundingMode == .manualOnly }) else {
            return
        }

        allocatedBySubcategoryID[currencyCard.id] = roundToWholeHryvnia(input.foreignCurrencyAmount)
    }

    private var mandatoryLivingSystemKeys: Set<SystemSubcategoryKey> {
        [.housing, .food, .health, .hygiene, .children, .animals, .transport, .credit]
    }
}
