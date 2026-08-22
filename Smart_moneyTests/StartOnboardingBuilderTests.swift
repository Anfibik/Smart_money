import XCTest

final class StartOnboardingBuilderTests: XCTestCase {
    func testDebtCardUsesFullDebtAndEmergencyTargetIgnoresDebt() throws {
        let builder = StartOnboardingBuilder()
        let input = StartOnboardingInput(
            monthlyIncome: 100_000,
            capital: -120_000,
            housingType: .owned,
            housingCost: 10_000,
            hasCar: false,
            dependentsCount: 0,
            elderlyDependentsCount: 0,
            childrenCount: 0,
            petsCount: 0,
            hasCredit: false,
            creditMonthlyPayment: 0,
            strategy: .balance,
            customCards: []
        )

        let preview = builder.buildPreview(input: input)
        let savings = try XCTUnwrap(
            preview.configuration.settings.categories.first(where: { $0.type == .savings })
        )
        let debt = try XCTUnwrap(savings.subcategories.first(where: { $0.systemKey == .debt }))
        let emergencyFund = try XCTUnwrap(
            savings.subcategories.first(where: { $0.systemKey == .emergencyFund })
        )

        XCTAssertEqual(debt.percentage, 100, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(debt.minLimit), 120_000, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(debt.maxLimit), 120_000, accuracy: 0.0001)
        XCTAssertEqual(debt.priority, SubcategoryPriorityLevel.high.rawValue)
        XCTAssertEqual(emergencyFund.priority, SubcategoryPriorityLevel.medium.rawValue)
        XCTAssertEqual(emergencyFund.minLimit, emergencyFund.maxLimit)

        XCTAssertEqual(preview.configuration.mandatoryLivingMonthly, 21_150, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.emergencyTarget, 126_900, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.monthlyMinimumExcludingEmergency, 21_150, accuracy: 0.0001)
    }

    func testDiscretionaryAndRecommendedCardsHaveNoMandatoryMinimum() {
        let builder = StartOnboardingBuilder()
        let input = StartOnboardingInput(
            monthlyIncome: 100_000,
            capital: 0,
            housingType: .rented,
            housingCost: 20_000,
            hasCar: false,
            dependentsCount: 0,
            elderlyDependentsCount: 0,
            childrenCount: 0,
            petsCount: 0,
            hasCredit: false,
            creditMonthlyPayment: 0,
            strategy: .balance,
            customCards: [],
            selectedRecommendationKeys: [.hobby, .investments, .goal],
            goalTargetAmount: 750_000
        )

        let descriptors = builder.onboardingCardDescriptors(for: input)
        let keysWithoutMandatoryMinimum: Set<SystemSubcategoryKey> = [
            .shopping,
            .entertainment,
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
        ]

        for descriptor in descriptors where keysWithoutMandatoryMinimum.contains(descriptor.systemKey) {
            XCTAssertEqual(descriptor.minLimit, 0, accuracy: 0.0001)
        }

        let goal = descriptors.first(where: { $0.systemKey == .goal })
        XCTAssertEqual(goal?.categoryType, .savings)
        XCTAssertEqual(goal?.basePercentage, 20)
        XCTAssertEqual(goal?.priority, .medium)
        XCTAssertEqual(goal?.isRecommended, true)
        XCTAssertEqual(goal?.isActive, true)
        XCTAssertEqual(goal?.maxLimit, 750_000)
    }

    func testGoalWithoutAmountCannotBecomeActive() {
        let input = StartOnboardingInput(
            monthlyIncome: 100_000,
            capital: 0,
            housingType: .owned,
            housingCost: 5_000,
            hasCar: false,
            dependentsCount: 0,
            elderlyDependentsCount: 0,
            childrenCount: 0,
            petsCount: 0,
            hasCredit: false,
            creditMonthlyPayment: 0,
            strategy: .capitalGrowth,
            customCards: [],
            selectedRecommendationKeys: [.goal],
            goalTargetAmount: 0
        )

        XCTAssertFalse(input.selectedRecommendationKeys.contains(.goal))
    }

    func testPreviewUsesStartingCapitalForInitialDistribution() {
        let builder = StartOnboardingBuilder()
        let input = StartOnboardingInput(
            monthlyIncome: 10_000,
            capital: 50_000,
            housingType: .rented,
            housingCost: 20_000,
            hasCar: false,
            dependentsCount: 0,
            elderlyDependentsCount: 0,
            childrenCount: 0,
            petsCount: 0,
            hasCredit: false,
            creditMonthlyPayment: 0,
            strategy: .capitalGrowth,
            customCards: []
        )

        let preview = builder.buildPreview(input: input)

        XCTAssertEqual(preview.configuration.capitalAppliedToMinimums, 0, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.initialDistributionAmount, 10_000, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.remainingFreeCapital, 40_000, accuracy: 0.0001)
        XCTAssertTrue(preview.distribution.lastBankAutoDistributions.isEmpty)
    }

    func testInitialFormationPreviewUsesWholeHryvniaAmounts() {
        let builder = StartOnboardingBuilder()
        let input = StartOnboardingInput(
            monthlyIncome: 120_000.02,
            capital: 399_999.51,
            housingType: .rented,
            housingCost: 20_000.49,
            hasCar: true,
            dependentsCount: 1,
            elderlyDependentsCount: 0,
            childrenCount: 1,
            petsCount: 1,
            hasCredit: true,
            creditMonthlyPayment: 7_500.75,
            strategy: .stability,
            customCards: [],
            selectedRecommendationKeys: [.currency],
            foreignCurrencyAmount: 1_234.56
        )

        let preview = builder.buildPreview(input: input)
        let distribution = preview.distribution

        XCTAssertWholeHryvnia(distribution.income)
        XCTAssertWholeHryvnia(distribution.bankAmount)
        XCTAssertWholeHryvnia(preview.configuration.input.monthlyIncome)
        XCTAssertWholeHryvnia(preview.configuration.remainingFreeCapital)

        for category in distribution.categoryAllocations {
            XCTAssertWholeHryvnia(category.allocatedAmount)
            XCTAssertWholeHryvnia(category.lastIncomeToBankAmount)
            XCTAssertWholeHryvnia(category.deficitAmount)

            for subcategory in category.subcategoryAllocations {
                XCTAssertWholeHryvnia(subcategory.allocatedAmount)
                XCTAssertWholeHryvnia(subcategory.remainingAmount)
                XCTAssertWholeHryvnia(subcategory.monthlyIncomeAmount)
                XCTAssertWholeHryvnia(subcategory.monthlyIncomeDistributionAmount)
            }
        }
    }

    private func XCTAssertWholeHryvnia(
        _ value: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(value, value.rounded(), accuracy: 0.0001, file: file, line: line)
    }
}
