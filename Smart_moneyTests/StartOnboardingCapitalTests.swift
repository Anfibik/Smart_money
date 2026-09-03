import XCTest
@testable import Smart_money

@MainActor
final class StartOnboardingCapitalTests: XCTestCase {
    func testInitialDistributionUsesCapitalWithoutCreatingIncomeHistory() throws {
        let input = makeInput(monthlyIncome: 120_000, capital: 400_000)
        let preview = Smart_money.StartOnboardingBuilder().buildPreview(input: input)

        XCTAssertEqual(preview.configuration.initialDistributionAmount, 120_000, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.initialDistributionShortfall, 0, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.remainingFreeCapital, 280_000, accuracy: 0.0001)
        XCTAssertEqual(categoryAmount(.essentials, in: preview.distribution), 72_000, accuracy: 0.0001)
        XCTAssertEqual(categoryAmount(.wants, in: preview.distribution), 18_000, accuracy: 0.0001)
        XCTAssertEqual(categoryAmount(.savings, in: preview.distribution), 30_000, accuracy: 0.0001)

        let viewModel = makeViewModel()
        viewModel.applyStartOnboardingConfiguration(preview.configuration)

        XCTAssertEqual(viewModel.income, 120_000, accuracy: 0.0001)
        XCTAssertEqual(viewModel.lastIncomeAmount, 120_000, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bankAvailableAmount, 280_000, accuracy: 0.0001)
        XCTAssertTrue(viewModel.historyEvents.isEmpty)

        let displayedInitialIncome = viewModel.distribution.categoryAllocations
            .flatMap(\.subcategoryAllocations)
            .reduce(0) { $0 + $1.monthlyIncomeDistributionAmount }
        XCTAssertEqual(displayedInitialIncome, 120_000, accuracy: 0.0001)
    }

    func testInitialDistributionIsLimitedByAvailableCapital() {
        let input = makeInput(monthlyIncome: 120_000, capital: 50_000)
        let preview = Smart_money.StartOnboardingBuilder().buildPreview(input: input)

        XCTAssertEqual(preview.configuration.initialDistributionAmount, 50_000, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.initialDistributionShortfall, 70_000, accuracy: 0.0001)
        XCTAssertEqual(preview.configuration.remainingFreeCapital, 0, accuracy: 0.0001)

        let distributedAmount = preview.distribution.categoryAllocations
            .reduce(0) { $0 + $1.allocatedAmount }
        XCTAssertEqual(distributedAmount, 50_000, accuracy: 0.0001)

        let viewModel = makeViewModel()
        viewModel.applyStartOnboardingConfiguration(preview.configuration)

        XCTAssertEqual(viewModel.income, 50_000, accuracy: 0.0001)
        XCTAssertEqual(viewModel.bankAvailableAmount, 0, accuracy: 0.0001)
        XCTAssertTrue(viewModel.historyEvents.isEmpty)
    }

    private func makeInput(
        monthlyIncome: Double,
        capital: Double
    ) -> Smart_money.StartOnboardingInput {
        Smart_money.StartOnboardingInput(
            monthlyIncome: monthlyIncome,
            capital: capital,
            housingType: .rented,
            housingCost: 20_000,
            hasCar: false,
            dependentsCount: 0,
            elderlyDependentsCount: 0,
            childrenCount: 0,
            petsCount: 0,
            hasCredit: false,
            creditMonthlyPayment: 0,
            strategy: .stability,
            customCards: []
        )
    }

    private func makeViewModel() -> Smart_money.BudgetViewModel {
        let suiteName = "StartOnboardingCapitalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let persistenceService = Smart_money.PersistenceService(
            defaults: defaults,
            storageKey: "budget-state-\(UUID().uuidString)"
        )
        let historyDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        let historyStorage = Smart_money.BudgetHistoryStorage(
            directoryURL: historyDirectory,
            fileName: "history.json"
        )

        return Smart_money.BudgetViewModel(
            income: 0,
            settings: Smart_money.BudgetSettings(),
            persistenceService: persistenceService,
            allocationEngine: Smart_money.BudgetAllocationEngine(),
            historyStorage: historyStorage
        )
    }

    private func categoryAmount(
        _ type: Smart_money.ExpenseCategoryType,
        in distribution: Smart_money.BudgetDistribution
    ) -> Double {
        distribution.categoryAllocations
            .first(where: { $0.type == type })?
            .allocatedAmount ?? 0
    }
}
