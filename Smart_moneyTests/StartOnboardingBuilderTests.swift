import XCTest

final class StartOnboardingBuilderTests: XCTestCase {
    func testDebtCardUsesFullDebtAndEmergencyTargetIgnoresDebt() {
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
        XCTAssertEqual(debt.minLimit, 120_000, accuracy: 0.0001)
        XCTAssertEqual(debt.maxLimit, 120_000, accuracy: 0.0001)
        XCTAssertEqual(debt.priority, SubcategoryPriorityLevel.high.rawValue)
        XCTAssertEqual(emergencyFund.priority, SubcategoryPriorityLevel.medium.rawValue)

        XCTAssertEqual(preview.configuration.mandatoryLivingMonthly, 22_150, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.emergencyTarget, 132_900, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.monthlyMinimumExcludingEmergency, 22_150, accuracy: 0.0001)
    }
}
