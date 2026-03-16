import XCTest
final class BudgetAllocationEngineTests: XCTestCase {
    func testApplyIncomeDeltaAllocatesByBasePercent() {
        let engine = BudgetAllocationEngine()
        var settings = BudgetSettings(
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

        var settings = BudgetSettings(
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
