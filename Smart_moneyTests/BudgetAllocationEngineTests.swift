import XCTest
final class BudgetAllocationEngineTests: XCTestCase {
    func testGoalSystemKeyProvidesStableMetadata() {
        XCTAssertEqual(SystemSubcategoryKey.goal.defaultName, "Цель")
        XCTAssertEqual(SystemSubcategoryKey.goal.defaultIconName, "target")
        XCTAssertEqual(SystemSubcategoryKey.inferred(from: "Цель", isSystem: true), .goal)
    }

    func testSystemCardCatalogDefinesEverySystemCardOnce() {
        let catalog = SystemCardCatalog.standard
        let keys = catalog.definitions.map(\.systemKey)

        XCTAssertEqual(keys.count, SystemSubcategoryKey.allCases.count)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(
            Set(catalog.recommendedDefinitions.map(\.systemKey)),
            Set([
                .hobby,
                .travel,
                .restaurants,
                .gifts,
                .sport,
                .beauty,
                .subscriptions,
                .investments,
                .business,
                .currency,
                .goal
            ])
        )

        let currencyDefinition = catalog.definition(for: .currency)
        XCTAssertEqual(currencyDefinition.defaultPercentage, 0, accuracy: 0.0001)
        XCTAssertEqual(currencyDefinition.defaultMinLimit, 0, accuracy: 0.0001)
        XCTAssertEqual(currencyDefinition.fundingMode, .manualOnly)
    }

    func testIncomeDistributionIgnoresManualCurrencyCardBalance() {
        let engine = BudgetAllocationEngine()
        let automaticCard = Subcategory(
            name: "Automatic",
            percentage: 100,
            priority: 2
        )
        let currencyCard = Subcategory(
            name: "Currency",
            isSystem: true,
            systemKey: .currency,
            percentage: 0,
            priority: 2,
            fundingMode: .manualOnly,
            balanceCurrencyCode: ForeignCurrencyType.usd.rawValue
        )
        let category = ExpenseCategory(
            type: .savings,
            percentage: 100,
            subcategories: [automaticCard, currencyCard]
        )
        let settings = BudgetSettings(categories: [category], currencyCode: "UAH")

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [
            automaticCard.id: 0,
            currencyCard.id: 1_000
        ]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            10_000,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankDistribution
        )

        XCTAssertEqual(allocated[automaticCard.id, default: 0], 10_000, accuracy: 0.0001)
        XCTAssertEqual(allocated[currencyCard.id, default: 0], 1_000, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testCoveragePolicySeparatesCardDeficitsFromEmergencyFund() {
        let engine = BudgetAllocationEngine()
        let essential = Subcategory(
            name: "Essential",
            percentage: 100,
            minLimit: 50,
            priority: 3
        )
        let emergency = Subcategory(
            name: "Emergency",
            isSystem: true,
            systemKey: .emergencyFund,
            percentage: 100,
            minLimit: 50,
            maxLimit: 50,
            priority: 3
        )
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(
                    type: .essentials,
                    percentage: 50,
                    subcategories: [essential]
                ),
                ExpenseCategory(
                    type: .savings,
                    percentage: 50,
                    subcategories: [emergency]
                )
            ],
            currencyCode: "UAH"
        )

        var disabledAllocations: [UUID: Double] = [:]
        var disabledBank: Double = 100
        var disabledDistribution: [UUID: Double] = [:]
        engine.coverOnboardingDeficitsFromBank(
            settings: settings,
            policy: .none,
            allocatedBySubcategoryID: &disabledAllocations,
            bankBalance: &disabledBank,
            distributedBySubcategoryID: &disabledDistribution
        )

        XCTAssertEqual(disabledAllocations[essential.id, default: 0], 0, accuracy: 0.0001)
        XCTAssertEqual(disabledAllocations[emergency.id, default: 0], 0, accuracy: 0.0001)
        XCTAssertEqual(disabledBank, 100, accuracy: 0.0001)

        var emergencyOnlyAllocations: [UUID: Double] = [:]
        var emergencyOnlyBank: Double = 50
        var emergencyOnlyDistribution: [UUID: Double] = [:]
        engine.coverOnboardingDeficitsFromBank(
            settings: settings,
            policy: .emergencyFundOnly,
            allocatedBySubcategoryID: &emergencyOnlyAllocations,
            bankBalance: &emergencyOnlyBank,
            distributedBySubcategoryID: &emergencyOnlyDistribution
        )

        XCTAssertEqual(emergencyOnlyAllocations[essential.id, default: 0], 0, accuracy: 0.0001)
        XCTAssertEqual(emergencyOnlyAllocations[emergency.id, default: 0], 50, accuracy: 0.0001)

        var cardOnlyAllocations: [UUID: Double] = [:]
        var cardOnlyBank: Double = 50
        var cardOnlyDistribution: [UUID: Double] = [:]
        engine.coverOnboardingDeficitsFromBank(
            settings: settings,
            policy: .cardDeficitsOnly,
            allocatedBySubcategoryID: &cardOnlyAllocations,
            bankBalance: &cardOnlyBank,
            distributedBySubcategoryID: &cardOnlyDistribution
        )

        XCTAssertEqual(cardOnlyAllocations[essential.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(cardOnlyAllocations[emergency.id, default: 0], 0, accuracy: 0.0001)

        var allAllocations: [UUID: Double] = [:]
        var allBank: Double = 100
        var allDistribution: [UUID: Double] = [:]
        engine.coverOnboardingDeficitsFromBank(
            settings: settings,
            policy: .allOnboardingDeficits,
            allocatedBySubcategoryID: &allAllocations,
            bankBalance: &allBank,
            distributedBySubcategoryID: &allDistribution
        )

        XCTAssertEqual(allAllocations[essential.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allAllocations[emergency.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allBank, 0, accuracy: 0.0001)

        XCTAssertEqual(
            FreeCapitalCoveragePolicy.none
                .settingCardDeficitsCoverage(true)
                .settingEmergencyFundCoverage(true),
            .allOnboardingDeficits
        )
        XCTAssertEqual(
            FreeCapitalCoveragePolicy.allOnboardingDeficits
                .settingEmergencyFundCoverage(false),
            .cardDeficitsOnly
        )
    }

    func testApplyIncomeDeltaAllocatesByBasePercent() {
        let engine = BudgetAllocationEngine()
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(
                    type: .essentials,
                    percentage: 100,
                    subcategories: [
                        Subcategory(name: "A", percentage: 50, minLimit: nil, priority: 1),
                        Subcategory(name: "B", percentage: 50, minLimit: nil, priority: 1)
                    ]
                )
            ],
            currencyCode: "UAH"
        )

        var baselineByCategoryID: [UUID: Double] = [settings.categories[0].id: 0]
        var allocatedBySubcategoryID: [UUID: Double] = [
            settings.categories[0].subcategories[0].id: 0,
            settings.categories[0].subcategories[1].id: 0
        ]
        var bankBalance: Double = 0
        var lastIncomeToBankByCategoryID: [UUID: Double] = [settings.categories[0].id: 0]
        var autoDistributedBySubcategoryID: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselineByCategoryID,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance,
            lastIncomeToBankByCategoryID: &lastIncomeToBankByCategoryID,
            lastBankAutoDistributedBySubcategoryID: &autoDistributedBySubcategoryID
        )

        XCTAssertEqual(allocatedBySubcategoryID[settings.categories[0].subcategories[0].id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allocatedBySubcategoryID[settings.categories[0].subcategories[1].id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(bankBalance, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaKeepsCategoryQuotasWhenMinimumCannotBeCovered() {
        let engine = BudgetAllocationEngine()
        let essentialsCard = Subcategory(
            name: "Essentials",
            percentage: 100,
            minLimit: 60,
            priority: 3
        )
        let wantsCard = Subcategory(
            name: "Wants",
            percentage: 100,
            minLimit: 10,
            priority: 2
        )
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(
                    type: .essentials,
                    percentage: 50,
                    subcategories: [essentialsCard]
                ),
                ExpenseCategory(
                    type: .wants,
                    percentage: 50,
                    subcategories: [wantsCard]
                )
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [
            essentialsCard.id: 0,
            wantsCard.id: 0
        ]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[essentialsCard.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allocated[wantsCard.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaUsesPriorityInsideCategoryWhenIncomeCannotCoverMinimums() {
        let engine = BudgetAllocationEngine()
        let high = Subcategory(name: "High", percentage: 100, minLimit: 80, priority: 3)
        let medium = Subcategory(name: "Medium", percentage: 100, minLimit: 80, priority: 2)
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(
                    type: .essentials,
                    percentage: 100,
                    subcategories: [high, medium]
                )
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [high.id: 0, medium.id: 0]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[high.id, default: 0], 80, accuracy: 0.0001)
        XCTAssertEqual(allocated[medium.id, default: 0], 20, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testEssentialsHighMinimumCannotStarveOtherMandatoryCards() {
        let engine = BudgetAllocationEngine()
        let housing = Subcategory(
            name: "Housing",
            percentage: 25,
            minLimit: 100,
            priority: 3
        )
        let food = Subcategory(
            name: "Food",
            percentage: 20,
            minLimit: 20,
            priority: 2
        )
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(
                    type: .essentials,
                    percentage: 100,
                    subcategories: [housing, food]
                )
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [:]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            60,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[housing.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allocated[food.id, default: 0], 10, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaFundsEmergencyTargetOnlyFromFinanceQuota() {
        let engine = BudgetAllocationEngine()
        let essentialsCard = Subcategory(
            name: "Essentials",
            percentage: 100,
            minLimit: 40,
            priority: 3
        )
        let emergencyFund = Subcategory(
            name: "Emergency",
            isSystem: true,
            systemKey: .emergencyFund,
            percentage: 100,
            minLimit: 300,
            priority: 3
        )
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(
                    type: .essentials,
                    percentage: 50,
                    subcategories: [essentialsCard]
                ),
                ExpenseCategory(
                    type: .savings,
                    percentage: 50,
                    subcategories: [emergencyFund]
                )
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [
            essentialsCard.id: 0,
            emergencyFund.id: 0
        ]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[essentialsCard.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allocated[emergencyFund.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaUsesExactStrategyQuotas() {
        let engine = BudgetAllocationEngine()
        let essentials = Subcategory(name: "Essentials", percentage: 100, priority: 3)
        let wants = Subcategory(name: "Wants", percentage: 100, priority: 2)
        let finance = Subcategory(name: "Finance", percentage: 100, priority: 3)
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(type: .essentials, percentage: 50, subcategories: [essentials]),
                ExpenseCategory(type: .wants, percentage: 15, subcategories: [wants]),
                ExpenseCategory(type: .savings, percentage: 35, subcategories: [finance])
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [:]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100_000,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[essentials.id, default: 0], 50_000, accuracy: 0.0001)
        XCTAssertEqual(allocated[wants.id, default: 0], 15_000, accuracy: 0.0001)
        XCTAssertEqual(allocated[finance.id, default: 0], 35_000, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaNormalizesCardPercentageWeights() {
        let engine = BudgetAllocationEngine()
        let first = Subcategory(name: "First", percentage: 15, priority: 2)
        let second = Subcategory(name: "Second", percentage: 10, priority: 2)
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(type: .wants, percentage: 100, subcategories: [first, second])
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [:]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[first.id, default: 0], 60, accuracy: 0.0001)
        XCTAssertEqual(allocated[second.id, default: 0], 40, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaRedistributesRemainderAfterMaximum() {
        let engine = BudgetAllocationEngine()
        let capped = Subcategory(
            name: "Capped",
            percentage: 50,
            maxLimit: 20,
            priority: 2
        )
        let unlimited = Subcategory(name: "Unlimited", percentage: 50, priority: 2)
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(type: .wants, percentage: 100, subcategories: [capped, unlimited])
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [:]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[capped.id, default: 0], 20, accuracy: 0.0001)
        XCTAssertEqual(allocated[unlimited.id, default: 0], 80, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaMovesOnlyUnallocatableRemainderToBank() {
        let engine = BudgetAllocationEngine()
        let first = Subcategory(
            name: "First",
            percentage: 50,
            maxLimit: 20,
            priority: 2
        )
        let second = Subcategory(
            name: "Second",
            percentage: 50,
            maxLimit: 30,
            priority: 2
        )
        let category = ExpenseCategory(
            type: .wants,
            percentage: 100,
            subcategories: [first, second]
        )
        let settings = BudgetSettings(categories: [category], currencyCode: "UAH")

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [:]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[first.id, default: 0], 20, accuracy: 0.0001)
        XCTAssertEqual(allocated[second.id, default: 0], 30, accuracy: 0.0001)
        XCTAssertEqual(bank, 50, accuracy: 0.0001)
        XCTAssertEqual(incomeToBank[category.id, default: 0], 50, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaDistributesAfterMinimumsByWeights() {
        let engine = BudgetAllocationEngine()
        let high = Subcategory(name: "High", percentage: 10, minLimit: 60, priority: 3)
        let medium = Subcategory(name: "Medium", percentage: 90, minLimit: 10, priority: 2)
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(type: .essentials, percentage: 100, subcategories: [high, medium])
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [:]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[high.id, default: 0], 63, accuracy: 0.0001)
        XCTAssertEqual(allocated[medium.id, default: 0], 37, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaSplitsSamePriorityMinimumsProportionally() {
        let engine = BudgetAllocationEngine()
        let first = Subcategory(name: "First", percentage: 50, minLimit: 80, priority: 2)
        let second = Subcategory(name: "Second", percentage: 50, minLimit: 20, priority: 2)
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(type: .essentials, percentage: 100, subcategories: [first, second])
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [:]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            50,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[first.id, default: 0], 40, accuracy: 0.0001)
        XCTAssertEqual(allocated[second.id, default: 0], 10, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testApplyIncomeDeltaFundsDebtBeforeOtherFinanceCardsAndStopsAtMaximum() {
        let engine = BudgetAllocationEngine()
        let debt = Subcategory(
            name: "Debt",
            isSystem: true,
            systemKey: .debt,
            percentage: 100,
            minLimit: 60,
            maxLimit: 60,
            priority: 3
        )
        let emergency = Subcategory(
            name: "Emergency",
            isSystem: true,
            systemKey: .emergencyFund,
            percentage: 50,
            minLimit: 100,
            maxLimit: 100,
            priority: 2
        )
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(type: .savings, percentage: 100, subcategories: [debt, emergency])
            ],
            currencyCode: "UAH"
        )

        var baselines: [UUID: Double] = [:]
        var allocated: [UUID: Double] = [:]
        var bank: Double = 0
        var incomeToBank: [UUID: Double] = [:]
        var bankAutoDistribution: [UUID: Double] = [:]

        engine.applyIncomeDelta(
            100,
            settings: settings,
            categoryTargetBaselineByID: &baselines,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastIncomeToBankByCategoryID: &incomeToBank,
            lastBankAutoDistributedBySubcategoryID: &bankAutoDistribution
        )

        XCTAssertEqual(allocated[debt.id, default: 0], 60, accuracy: 0.0001)
        XCTAssertEqual(allocated[emergency.id, default: 0], 40, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testOnboardingCoverageUsesConfirmedStageOrderAndProportionalRemainder() {
        let engine = BudgetAllocationEngine()
        let housing = Subcategory(
            name: "Housing",
            isSystem: true,
            systemKey: .housing,
            percentage: 50,
            minLimit: 30,
            priority: 3
        )
        let food = Subcategory(
            name: "Food",
            isSystem: true,
            systemKey: .food,
            percentage: 50,
            minLimit: 10,
            priority: 3
        )
        let debt = Subcategory(
            name: "Debt",
            isSystem: true,
            systemKey: .debt,
            percentage: 100,
            minLimit: 30,
            maxLimit: 30,
            priority: 3
        )
        let emergency = Subcategory(
            name: "Emergency",
            isSystem: true,
            systemKey: .emergencyFund,
            percentage: 50,
            minLimit: 20,
            maxLimit: 20,
            priority: 2
        )
        let firstOther = Subcategory(
            name: "First other",
            percentage: 50,
            minLimit: 50,
            priority: 3
        )
        let secondOther = Subcategory(
            name: "Second other",
            percentage: 50,
            minLimit: 50,
            priority: 3
        )
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(
                    type: .essentials,
                    percentage: 50,
                    subcategories: [housing, food]
                ),
                ExpenseCategory(
                    type: .wants,
                    percentage: 15,
                    subcategories: [firstOther, secondOther]
                ),
                ExpenseCategory(
                    type: .savings,
                    percentage: 35,
                    subcategories: [debt, emergency]
                )
            ],
            currencyCode: "UAH"
        )

        var allocated: [UUID: Double] = [:]
        var bank: Double = 100
        var distributed: [UUID: Double] = [:]

        engine.coverOnboardingDeficitsFromBank(
            settings: settings,
            policy: .allOnboardingDeficits,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            distributedBySubcategoryID: &distributed
        )

        XCTAssertEqual(allocated[housing.id, default: 0], 30, accuracy: 0.0001)
        XCTAssertEqual(allocated[food.id, default: 0], 10, accuracy: 0.0001)
        XCTAssertEqual(allocated[debt.id, default: 0], 30, accuracy: 0.0001)
        XCTAssertEqual(allocated[emergency.id, default: 0], 20, accuracy: 0.0001)
        XCTAssertEqual(allocated[firstOther.id, default: 0], 5, accuracy: 0.0001)
        XCTAssertEqual(allocated[secondOther.id, default: 0], 5, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
        XCTAssertEqual(distributed.values.reduce(0, +), 100, accuracy: 0.0001)
    }

    func testOnboardingCoverageSplitsEssentialsOfSamePriorityByDeficit() {
        let engine = BudgetAllocationEngine()
        let largerDeficit = Subcategory(
            name: "Larger",
            percentage: 50,
            minLimit: 30,
            priority: 2
        )
        let smallerDeficit = Subcategory(
            name: "Smaller",
            percentage: 50,
            minLimit: 10,
            priority: 2
        )
        let debt = Subcategory(
            name: "Debt",
            isSystem: true,
            systemKey: .debt,
            percentage: 100,
            minLimit: 100,
            maxLimit: 100,
            priority: 3
        )
        let settings = BudgetSettings(
            categories: [
                ExpenseCategory(
                    type: .essentials,
                    percentage: 50,
                    subcategories: [largerDeficit, smallerDeficit]
                ),
                ExpenseCategory(
                    type: .savings,
                    percentage: 50,
                    subcategories: [debt]
                )
            ],
            currencyCode: "UAH"
        )

        var allocated: [UUID: Double] = [:]
        var bank: Double = 20
        var distributed: [UUID: Double] = [:]

        engine.coverOnboardingDeficitsFromBank(
            settings: settings,
            policy: .allOnboardingDeficits,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            distributedBySubcategoryID: &distributed
        )

        XCTAssertEqual(allocated[largerDeficit.id, default: 0], 15, accuracy: 0.0001)
        XCTAssertEqual(allocated[smallerDeficit.id, default: 0], 5, accuracy: 0.0001)
        XCTAssertEqual(allocated[debt.id, default: 0], 0, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testResolveMinimumDeficitsFromBankRespectsPriority() {
        let engine = BudgetAllocationEngine()
        let high = Subcategory(name: "High", percentage: 1, minLimit: 100, priority: 3)
        let medium = Subcategory(name: "Medium", percentage: 1, minLimit: 100, priority: 2)
        let low = Subcategory(name: "Low", percentage: 1, minLimit: 100, priority: 1)

        let settings = BudgetSettings(
            categories: [ExpenseCategory(type: .essentials, percentage: 100, subcategories: [high, medium, low])],
            currencyCode: "UAH"
        )

        var allocated: [UUID: Double] = [high.id: 0, medium.id: 0, low.id: 0]
        var bank: Double = 150
        var distributed: [UUID: Double] = [:]

        engine.resolveMinimumDeficitsFromBank(
            settings: settings,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastBankAutoDistributedBySubcategoryID: &distributed,
            trackAutoDistribution: true
        )

        XCTAssertEqual(allocated[high.id, default: 0], 100, accuracy: 0.0001)
        XCTAssertEqual(allocated[medium.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allocated[low.id, default: 0], 0, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
    }

    func testMoveExcessAboveMaxMovesDifferenceToBank() {
        let engine = BudgetAllocationEngine()
        let sub = Subcategory(name: "Cap", percentage: 100, minLimit: nil, maxLimit: 100, priority: 1)
        let settings = BudgetSettings(
            categories: [ExpenseCategory(type: .essentials, percentage: 100, subcategories: [sub])],
            currencyCode: "UAH"
        )

        var allocated: [UUID: Double] = [sub.id: 180]
        var bank: Double = 20

        engine.moveExcessAboveMaxToBank(
            categoryType: .essentials,
            subcategoryID: sub.id,
            settings: settings,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank
        )

        XCTAssertEqual(allocated[sub.id, default: 0], 100, accuracy: 0.0001)
        XCTAssertEqual(bank, 100, accuracy: 0.0001)
    }

    func testRebalanceForNewSubcategoryMinimumUsesLowPriorityFirst() {
        let engine = BudgetAllocationEngine()

        let donorLow = Subcategory(name: "LowDonor", percentage: 40, minLimit: 20, priority: 1)
        let donorHigh = Subcategory(name: "HighDonor", percentage: 40, minLimit: 90, priority: 3)
        let newCard = Subcategory(name: "New", percentage: 20, minLimit: 50, priority: 1)

        let settings = BudgetSettings(
            categories: [ExpenseCategory(type: .essentials, percentage: 100, subcategories: [donorLow, donorHigh, newCard])],
            currencyCode: "UAH"
        )

        var allocated: [UUID: Double] = [
            donorLow.id: 100,
            donorHigh.id: 100,
            newCard.id: 0
        ]

        engine.rebalanceForNewSubcategoryMinimum(
            in: 0,
            newSubcategoryID: newCard.id,
            settings: settings,
            allocatedBySubcategoryID: &allocated
        )

        XCTAssertEqual(allocated[newCard.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allocated[donorLow.id, default: 0], 50, accuracy: 0.0001)
        XCTAssertEqual(allocated[donorHigh.id, default: 0], 100, accuracy: 0.0001)
    }

    func testEmergencyReserveLookupUsesSystemKeyNotDisplayName() {
        let engine = BudgetAllocationEngine()
        let renamedEmergencyFund = Subcategory(
            name: "Фонд безопасности",
            isSystem: true,
            systemKey: .emergencyFund,
            percentage: 100,
            minLimit: 100,
            priority: 3
        )
        let settings = BudgetSettings(
            categories: [ExpenseCategory(type: .savings, percentage: 100, subcategories: [renamedEmergencyFund])],
            currencyCode: "UAH"
        )

        var allocated: [UUID: Double] = [renamedEmergencyFund.id: 0]
        var bank: Double = 100
        var distributed: [UUID: Double] = [:]

        engine.resolveEmergencyReserveMinimumFromBank(
            settings: settings,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastBankAutoDistributedBySubcategoryID: &distributed,
            trackAutoDistribution: true
        )

        XCTAssertEqual(allocated[renamedEmergencyFund.id, default: 0], 100, accuracy: 0.0001)
        XCTAssertEqual(bank, 0, accuracy: 0.0001)
        XCTAssertEqual(distributed[renamedEmergencyFund.id, default: 0], 100, accuracy: 0.0001)
    }

    func testEmergencyReserveDoesNotAutoTopUpWhileDebtNeedsFunding() {
        let engine = BudgetAllocationEngine()
        let emergencyFund = Subcategory(
            name: "Подушка",
            isSystem: true,
            systemKey: .emergencyFund,
            percentage: 50,
            minLimit: 300,
            priority: 2
        )
        let debt = Subcategory(
            name: "Долг",
            isSystem: true,
            systemKey: .debt,
            iconName: "banknote.fill",
            percentage: 100,
            minLimit: 500,
            maxLimit: 500,
            priority: 3
        )
        let settings = BudgetSettings(
            categories: [ExpenseCategory(type: .savings, percentage: 100, subcategories: [emergencyFund, debt])],
            currencyCode: "UAH"
        )

        var allocated: [UUID: Double] = [
            emergencyFund.id: 0,
            debt.id: 0
        ]
        var bank: Double = 400
        var distributed: [UUID: Double] = [:]

        engine.resolveEmergencyReserveMinimumFromBank(
            settings: settings,
            allocatedBySubcategoryID: &allocated,
            bankBalance: &bank,
            lastBankAutoDistributedBySubcategoryID: &distributed,
            trackAutoDistribution: true
        )

        XCTAssertEqual(allocated[emergencyFund.id, default: 0], 0, accuracy: 0.0001)
        XCTAssertEqual(allocated[debt.id, default: 0], 0, accuracy: 0.0001)
        XCTAssertEqual(bank, 400, accuracy: 0.0001)
        XCTAssertTrue(distributed.isEmpty)
    }
}
