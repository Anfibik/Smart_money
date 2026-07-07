import Foundation
import Combine

enum SubcategoryPriorityLevel: Int, CaseIterable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .high: return "Высокий"
        case .medium: return "Средний"
        case .low: return "Низкий"
        }
    }
}

struct CategoryCoverageCandidate: Identifiable, Hashable {
    let subcategoryID: UUID
    let name: String
    let iconName: String
    let availableAmount: Double

    var id: UUID { subcategoryID }
}

struct CategoryCoverageRequirement: Identifiable, Hashable {
    let id = UUID()
    let categoryType: ExpenseCategoryType
    let shortageAmount: Double
    let totalAvailableAmount: Double
    let automaticCategoryAmount: Double
    let bankContributionAmount: Double
    let candidates: [CategoryCoverageCandidate]

    var canCover: Bool {
        totalAvailableAmount + 0.0001 >= shortageAmount
    }
}

enum ExpenseFundingKind: String, Hashable {
    case selectedCard
    case automaticCategoryCard
    case freeCapital
    case confirmedCategoryCard
}

enum ExpenseFundingStrategy: String, CaseIterable, Identifiable, Hashable {
    case categoryFirst
    case freeCapitalFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categoryFirst: return "Карточки сначала"
        case .freeCapitalFirst: return "Капитал сначала"
        }
    }

    var explanation: String {
        switch self {
        case .categoryFirst:
            return "Сначала деньги выбранной категории, затем свободный капитал."
        case .freeCapitalFirst:
            return "Сначала свободный капитал, затем деньги выбранной категории."
        }
    }
}

struct ExpenseFundingLine: Identifiable, Hashable {
    let subcategoryID: UUID?
    let title: String
    let iconName: String
    let amount: Double
    let kind: ExpenseFundingKind

    var id: String {
        "\(kind.rawValue)-\(subcategoryID?.uuidString ?? "free-capital")"
    }
}

struct ExpenseFundingPreview: Hashable {
    let amount: Double
    let immediateLines: [ExpenseFundingLine]
    let confirmationLines: [ExpenseFundingLine]
    let uncoveredAmount: Double

    var canPay: Bool {
        uncoveredAmount <= 0.0001
    }
}

private struct BudgetOperationStateSnapshot {
    let income: Double
    let bankBalance: Double
    let allocatedBySubcategoryID: [UUID: Double]
    let spentBySubcategoryID: [UUID: Double]
    let monthlyIncomeBySubcategoryID: [UUID: Double]
    let monthlyIncomeDistributionBySubcategoryID: [UUID: Double]
    let monthlyOtherIncomingBySubcategoryID: [UUID: Double]
    let monthlyOtherOutgoingBySubcategoryID: [UUID: Double]
    let categoryTargetBaselineByID: [UUID: Double]
}

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published private(set) var income: Double
    @Published private(set) var lastIncomeAmount: Double = 0
    @Published private(set) var settings: BudgetSettings
    @Published private(set) var distribution: BudgetDistribution
    @Published private(set) var historyEvents: [BudgetHistoryEvent]

    private var allocatedBySubcategoryID: [UUID: Double] = [:]
    private var categoryTargetBaselineByID: [UUID: Double] = [:]
    private var lastIncomeToBankByCategoryID: [UUID: Double] = [:]
    private var lastBankAutoDistributedBySubcategoryID: [UUID: Double] = [:]
    private var monthlyIncomeBySubcategoryID: [UUID: Double] = [:]
    private var monthlyIncomeDistributionBySubcategoryID: [UUID: Double] = [:]
    private var monthlyOtherIncomingBySubcategoryID: [UUID: Double] = [:]
    private var monthlyOtherOutgoingBySubcategoryID: [UUID: Double] = [:]
    private var monthlyTrackingMonthKey: String = ""
    private var bankBalance: Double = 0
    private let persistenceService: PersistenceService
    private let allocationEngine: BudgetAllocationEngine
    private let historyStorage: BudgetHistoryStorage
    private let calendar = Calendar.current

    init(
        income: Double,
        settings: BudgetSettings,
        persistenceService: PersistenceService,
        allocationEngine: BudgetAllocationEngine,
        historyStorage: BudgetHistoryStorage
    ) {
        self.persistenceService = persistenceService
        self.allocationEngine = allocationEngine
        self.historyStorage = historyStorage
        self.income = 0
        self.settings = settings
        self.historyEvents = historyStorage.loadEvents().sorted { $0.createdAt > $1.createdAt }
        self.distribution = BudgetDistribution(
            income: 0,
            categoryAllocations: [],
            bankAmount: 0,
            lastBankAutoDistributions: []
        )

        normalizePriorityRules()
        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()
        if let persistedState = persistenceService.loadBudgetState() {
            restoreFromPersistedState(persistedState)
            recalculate()
            return
        }

        let initialIncome = max(0, income)
        if initialIncome > 0 {
            self.income = initialIncome
            applyIncomeDelta(initialIncome)
        }

        recalculate()
    }

    convenience init(income: Double = 0, settings: BudgetSettings) {
        self.init(
            income: income,
            settings: settings,
            persistenceService: PersistenceService(),
            allocationEngine: BudgetAllocationEngine(),
            historyStorage: BudgetHistoryStorage()
        )
    }

    convenience init() {
        self.init(income: 0, settings: BudgetSettings())
    }

    func recalculate() {
        rolloverMonthlyTrackingIfNeeded()
        distribution = buildDistribution()
        persistCurrentState()
    }

    func setIncome(_ newValue: Double) {
        let normalized = max(0, newValue)

        income = 0
        bankBalance = 0
        lastIncomeAmount = 0
        allocatedBySubcategoryID = [:]
        categoryTargetBaselineByID = [:]
        lastIncomeToBankByCategoryID = [:]
        lastBankAutoDistributedBySubcategoryID = [:]
        clearMonthlyTracking()
        monthlyTrackingMonthKey = Self.makeMonthKey()
        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()
        if normalized > 0 {
            income = normalized
            applyIncomeDelta(normalized)
        }

        recalculate()
    }

    func addIncome(_ value: Double) {
        let normalized = max(0, value)
        guard normalized > 0 else { return }

        let operationBefore = makeOperationSnapshot()
        lastIncomeAmount = normalized
        income += normalized
        lastIncomeToBankByCategoryID = [:]
        lastBankAutoDistributedBySubcategoryID = [:]
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()
        applyIncomeDelta(normalized)
        appendHistoryEvent(
            BudgetHistoryEvent(
                type: .income,
                amount: normalized,
                currencyCode: settings.currencyCode,
                undoDelta: makeOperationDelta(from: operationBefore, to: makeOperationSnapshot())
            )
        )
        recalculate()
    }

    func resetMoneyData() {
        income = 0
        lastIncomeAmount = 0
        bankBalance = 0

        allocatedBySubcategoryID = [:]
        categoryTargetBaselineByID = [:]
        lastIncomeToBankByCategoryID = [:]
        lastBankAutoDistributedBySubcategoryID = [:]
        clearMonthlyTracking()
        monthlyTrackingMonthKey = Self.makeMonthKey()

        for categoryIndex in settings.categories.indices {
            for subcategoryIndex in settings.categories[categoryIndex].subcategories.indices {
                settings.categories[categoryIndex].subcategories[subcategoryIndex].spentAmount = 0
            }
        }

        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()

        clearHistory()
        persistenceService.clearBudgetState()
        recalculate()
    }

    func resetToInitialSystemState() {
        settings = BudgetSettings()
        resetMoneyData()
    }

    @discardableResult
    func revertHistoryEvent(id eventID: UUID) -> Bool {
        guard let eventIndex = historyEvents.firstIndex(where: { $0.id == eventID }),
              let undoDelta = historyEvents[eventIndex].undoDelta else {
            return false
        }

        let rollbackSnapshot = makeOperationSnapshot()
        guard applyReverseOperationDelta(undoDelta) else {
            restoreOperationSnapshot(rollbackSnapshot)
            return false
        }

        historyEvents.remove(at: eventIndex)
        historyStorage.replaceAll(historyEvents.sorted { $0.createdAt < $1.createdAt })
        refreshLastIncomeAmountFromHistory()
        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()
        recalculate()
        return true
    }

    func updateSettings(_ newSettings: BudgetSettings) {
        settings = newSettings
        normalizePriorityRules()
        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()
        recalculate()
    }

    func addExpense(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double,
        useBankIfNeeded: Bool
    ) {
        _ = useBankIfNeeded
        _ = performExpense(
            categoryType: categoryType,
            subcategoryID: subcategoryID,
            amount: amount,
            forcedAllocations: nil,
            useAutomaticForcedCoverage: false,
            fundingStrategy: .categoryFirst
        )
    }

    func addExpense(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double,
        fundingStrategy: ExpenseFundingStrategy
    ) {
        _ = performExpense(
            categoryType: categoryType,
            subcategoryID: subcategoryID,
            amount: amount,
            forcedAllocations: nil,
            useAutomaticForcedCoverage: false,
            fundingStrategy: fundingStrategy
        )
    }

    func expenseCoverageRequirement(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double
    ) -> CategoryCoverageRequirement? {
        let normalizedAmount = roundToCents(max(0, amount))
        guard normalizedAmount > 0 else { return nil }
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return nil }
        guard let subcategoryIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return nil }

        let category = settings.categories[categoryIndex]
        let target = category.subcategories[subcategoryIndex]
        let targetRemaining = availableBalance(for: target)
        let automaticCategoryAmount = automaticCategoryCoverageAmount(
            in: category,
            excluding: subcategoryID
        )
        let bankContribution = min(
            bankAvailableAmount,
            max(0, normalizedAmount - targetRemaining - automaticCategoryAmount)
        )
        let shortage = max(0, normalizedAmount - targetRemaining - automaticCategoryAmount - bankContribution)

        guard shortage > 0.0001 else { return nil }

        let candidates = forcedCoverageCandidates(
            in: category,
            excluding: subcategoryID
        )

        return CategoryCoverageRequirement(
            categoryType: categoryType,
            shortageAmount: roundToCents(shortage),
            totalAvailableAmount: roundToCents(candidates.reduce(0) { $0 + $1.availableAmount }),
            automaticCategoryAmount: roundToCents(automaticCategoryAmount),
            bankContributionAmount: roundToCents(bankContribution),
            candidates: candidates
        )
    }

    func expenseFundingPreview(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double,
        fundingStrategy: ExpenseFundingStrategy
    ) -> ExpenseFundingPreview? {
        let normalizedAmount = roundToCents(max(0, amount))
        guard normalizedAmount > 0 else { return nil }
        guard let category = settings.categories.first(where: { $0.type == categoryType }) else { return nil }
        guard let target = category.subcategories.first(where: { $0.id == subcategoryID }) else { return nil }

        var remainingNeed = normalizedAmount
        var immediateLines: [ExpenseFundingLine] = []

        if fundingStrategy == .freeCapitalFirst {
            appendFreeCapitalFundingLine(
                amount: min(bankAvailableAmount, remainingNeed),
                to: &immediateLines,
                remainingNeed: &remainingNeed
            )
        }

        let targetContribution = min(availableBalance(for: target), remainingNeed)
        if targetContribution > 0.0001 {
            immediateLines.append(
                ExpenseFundingLine(
                    subcategoryID: target.id,
                    title: target.name,
                    iconName: target.iconName,
                    amount: roundToCents(targetContribution),
                    kind: .selectedCard
                )
            )
            remainingNeed = max(0, remainingNeed - targetContribution)
        }

        let categoryRemainingAmount = categoryCurrentRemaining(for: category)
        let priorityOrder = [
            SubcategoryPriorityLevel.low.rawValue,
            SubcategoryPriorityLevel.medium.rawValue,
            SubcategoryPriorityLevel.high.rawValue
        ]

        for level in priorityOrder {
            for donor in category.subcategories where donor.id != subcategoryID && donor.priority == level {
                guard remainingNeed > 0.0001 else { break }

                let donorRemaining = availableBalance(for: donor)
                let protectedAmount = minimumCommitment(
                    for: donor,
                    categoryAmount: categoryRemainingAmount
                )
                let transferAmount = min(max(0, donorRemaining - protectedAmount), remainingNeed)
                guard transferAmount > 0.0001 else { continue }

                immediateLines.append(
                    ExpenseFundingLine(
                        subcategoryID: donor.id,
                        title: donor.name,
                        iconName: donor.iconName,
                        amount: roundToCents(transferAmount),
                        kind: .automaticCategoryCard
                    )
                )
                remainingNeed = max(0, remainingNeed - transferAmount)
            }
        }

        if fundingStrategy == .categoryFirst {
            appendFreeCapitalFundingLine(
                amount: min(bankAvailableAmount, remainingNeed),
                to: &immediateLines,
                remainingNeed: &remainingNeed
            )
        }

        let candidates = forcedCoverageCandidates(in: category, excluding: subcategoryID)
        let forcedAllocations = automaticForcedCoverageAllocations(
            candidates: candidates,
            shortageAmount: remainingNeed
        ) ?? Dictionary(uniqueKeysWithValues: candidates.map { ($0.subcategoryID, $0.availableAmount) })

        let confirmationLines = candidates.compactMap { candidate -> ExpenseFundingLine? in
            let contribution = min(candidate.availableAmount, forcedAllocations[candidate.subcategoryID, default: 0])
            guard contribution > 0.0001 else { return nil }

            return ExpenseFundingLine(
                subcategoryID: candidate.subcategoryID,
                title: candidate.name,
                iconName: candidate.iconName,
                amount: roundToCents(contribution),
                kind: .confirmedCategoryCard
            )
        }
        let confirmedAmount = confirmationLines.reduce(0) { $0 + $1.amount }

        return ExpenseFundingPreview(
            amount: normalizedAmount,
            immediateLines: immediateLines,
            confirmationLines: confirmationLines,
            uncoveredAmount: roundToCents(max(0, remainingNeed - confirmedAmount))
        )
    }

    @discardableResult
    func addExpenseWithAutomaticForcedCoverage(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double,
        fundingStrategy: ExpenseFundingStrategy = .categoryFirst
    ) -> Bool {
        performExpense(
            categoryType: categoryType,
            subcategoryID: subcategoryID,
            amount: amount,
            forcedAllocations: nil,
            useAutomaticForcedCoverage: true,
            fundingStrategy: fundingStrategy
        )
    }

    @discardableResult
    func addExpenseWithManualForcedCoverage(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double,
        allocations: [UUID: Double],
        fundingStrategy: ExpenseFundingStrategy = .categoryFirst
    ) -> Bool {
        performExpense(
            categoryType: categoryType,
            subcategoryID: subcategoryID,
            amount: amount,
            forcedAllocations: allocations,
            useAutomaticForcedCoverage: false,
            fundingStrategy: fundingStrategy
        )
    }

    func transferFromSubcategoryToBank(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double
    ) {
        let normalizedAmount = max(0, amount)
        guard normalizedAmount > 0 else { return }

        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }
        guard let subcategoryIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }

        let subcategory = settings.categories[categoryIndex].subcategories[subcategoryIndex]
        let allocated = allocatedBySubcategoryID[subcategoryID, default: 0]
        let spent = subcategory.spentAmount
        let remaining = max(0, allocated - spent)
        let maxWithdrawable = remaining

        guard normalizedAmount <= maxWithdrawable + 0.0001 else { return }

        let operationBefore = makeOperationSnapshot()
        allocatedBySubcategoryID[subcategoryID] = max(0, allocated - normalizedAmount)
        bankBalance += normalizedAmount
        recordMonthlyOtherOutgoing(for: subcategoryID, amount: normalizedAmount)
        topUpEmergencyReserveFromFreeCapital()
        appendHistoryEvent(
            BudgetHistoryEvent(
                type: .transferToFreeCapital,
                amount: normalizedAmount,
                currencyCode: settings.currencyCode,
                categoryType: categoryType,
                categoryTitleSnapshot: categoryType.title,
                subcategoryID: subcategory.id,
                subcategoryNameSnapshot: subcategory.name,
                iconNameSnapshot: subcategory.iconName,
                undoDelta: makeOperationDelta(from: operationBefore, to: makeOperationSnapshot())
            )
        )
        recalculate()
    }

    func transferFromBankToSubcategory(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double
    ) {
        let normalizedAmount = max(0, amount)
        guard normalizedAmount > 0 else { return }
        guard normalizedAmount <= bankAvailableAmount + 0.0001 else { return }

        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }
        guard let subcategoryIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }

        let subcategory = settings.categories[categoryIndex].subcategories[subcategoryIndex]
        let allocated = allocatedBySubcategoryID[subcategoryID, default: 0]
        let spent = subcategory.spentAmount
        let remaining = max(0, allocated - spent)

        let allowedByMax: Double
        if let maxLimit = subcategory.maxLimit, maxLimit > 0 {
            allowedByMax = max(0, maxLimit - remaining)
        } else {
            allowedByMax = bankAvailableAmount
        }

        guard normalizedAmount <= allowedByMax + 0.0001 else { return }

        let operationBefore = makeOperationSnapshot()
        bankBalance -= normalizedAmount
        allocatedBySubcategoryID[subcategoryID, default: 0] += normalizedAmount
        recordMonthlyOtherIncoming(for: subcategoryID, amount: normalizedAmount)
        appendHistoryEvent(
            BudgetHistoryEvent(
                type: .transferFromFreeCapital,
                amount: normalizedAmount,
                currencyCode: settings.currencyCode,
                categoryType: categoryType,
                categoryTitleSnapshot: categoryType.title,
                subcategoryID: subcategory.id,
                subcategoryNameSnapshot: subcategory.name,
                iconNameSnapshot: subcategory.iconName,
                undoDelta: makeOperationDelta(from: operationBefore, to: makeOperationSnapshot())
            )
        )
        recalculate()
    }

    func addCustomSubcategory(
        categoryType: ExpenseCategoryType,
        name: String,
        iconName: String,
        percentage: Double,
        minLimit: Double,
        maxLimit: Double,
        priority: SubcategoryPriorityLevel
    ) {
        _ = performAddCustomSubcategory(
            categoryType: categoryType,
            name: name,
            iconName: iconName,
            percentage: percentage,
            minLimit: minLimit,
            maxLimit: maxLimit,
            priority: priority,
            forcedAllocations: nil,
            useAutomaticForcedCoverage: false
        )
    }

    func newSubcategoryCoverageRequirement(
        categoryType: ExpenseCategoryType,
        minLimit: Double
    ) -> CategoryCoverageRequirement? {
        let normalizedMinLimit = max(0, minLimit)
        guard normalizedMinLimit > 0 else { return nil }
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return nil }

        let category = settings.categories[categoryIndex]
        let automaticCategoryAmount = automaticCategoryCoverageAmount(
            in: category,
            excluding: nil
        )
        let bankContribution = min(
            bankAvailableAmount,
            max(0, normalizedMinLimit - automaticCategoryAmount)
        )
        let shortage = max(0, normalizedMinLimit - automaticCategoryAmount - bankContribution)

        guard shortage > 0.0001 else { return nil }

        let candidates = forcedCoverageCandidates(
            in: category,
            excluding: nil
        )

        return CategoryCoverageRequirement(
            categoryType: categoryType,
            shortageAmount: roundToCents(shortage),
            totalAvailableAmount: roundToCents(candidates.reduce(0) { $0 + $1.availableAmount }),
            automaticCategoryAmount: roundToCents(automaticCategoryAmount),
            bankContributionAmount: roundToCents(bankContribution),
            candidates: candidates
        )
    }

    @discardableResult
    func addCustomSubcategoryWithAutomaticForcedCoverage(
        categoryType: ExpenseCategoryType,
        name: String,
        iconName: String,
        percentage: Double,
        minLimit: Double,
        maxLimit: Double,
        priority: SubcategoryPriorityLevel
    ) -> Bool {
        performAddCustomSubcategory(
            categoryType: categoryType,
            name: name,
            iconName: iconName,
            percentage: percentage,
            minLimit: minLimit,
            maxLimit: maxLimit,
            priority: priority,
            forcedAllocations: nil,
            useAutomaticForcedCoverage: true
        )
    }

    @discardableResult
    func addCustomSubcategoryWithManualForcedCoverage(
        categoryType: ExpenseCategoryType,
        name: String,
        iconName: String,
        percentage: Double,
        minLimit: Double,
        maxLimit: Double,
        priority: SubcategoryPriorityLevel,
        allocations: [UUID: Double]
    ) -> Bool {
        performAddCustomSubcategory(
            categoryType: categoryType,
            name: name,
            iconName: iconName,
            percentage: percentage,
            minLimit: minLimit,
            maxLimit: maxLimit,
            priority: priority,
            forcedAllocations: allocations,
            useAutomaticForcedCoverage: false
        )
    }

    func updateSubcategory(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        name: String,
        iconName: String,
        percentage: Double,
        minLimit: Double,
        maxLimit: Double,
        priority: SubcategoryPriorityLevel
    ) {
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }
        guard let subIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }

        var sub = settings.categories[categoryIndex].subcategories[subIndex]

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPercentage = max(0, percentage)
        guard normalizedPercentage > 0 else { return }

        let totalWithoutCurrent = settings.categories[categoryIndex].subcategories
            .enumerated()
            .filter { $0.offset != subIndex }
            .reduce(0.0) { $0 + $1.element.percentage }

        let availablePercentForCard = max(0, 100 - totalWithoutCurrent)
        guard normalizedPercentage <= availablePercentForCard + 0.0001 else { return }

        var normalizedMaxLimit = max(0, maxLimit)
        var requestedMinLimit = max(0, minLimit)

        if normalizedMaxLimit > 0, requestedMinLimit > normalizedMaxLimit {
            requestedMinLimit = normalizedMaxLimit
        }

        let finalMinLimit = requestedMinLimit

        if normalizedMaxLimit > 0, finalMinLimit > normalizedMaxLimit {
            normalizedMaxLimit = finalMinLimit
        }

        if !sub.isSystem, !normalizedName.isEmpty {
            sub.name = normalizedName
        }

        sub.iconName = SubcategoryIconCatalog.normalized(iconName)
        sub.percentage = normalizedPercentage
        sub.fixedMinimumPercentage = nil
        sub.minLimit = finalMinLimit > 0 ? finalMinLimit : nil
        sub.maxLimit = normalizedMaxLimit > 0 ? normalizedMaxLimit : nil
        settings.categories[categoryIndex].subcategories[subIndex] = sub
        normalizePriorityRules()
        moveExcessAboveMaxToBank(categoryType: categoryType, subcategoryID: subcategoryID)
        recalculate()
    }

    func applySystemSubcategorySetup(_ setups: [SystemSubcategorySetup]) {
        guard !setups.isEmpty else { return }

        var didChange = false

        for setup in setups {
            guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == setup.categoryType }) else { continue }
            guard let subIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: {
                $0.isSystem && $0.systemKey == setup.systemKey
            }) else { continue }

            let normalizedPercentage = max(0, setup.percentage)
            var normalizedMinLimit = max(0, setup.minLimit)
            let normalizedMaxLimit = max(0, setup.maxLimit ?? 0)
            guard normalizedPercentage > 0, normalizedMinLimit > 0 else { continue }

            if normalizedMaxLimit > 0, normalizedMinLimit > normalizedMaxLimit {
                normalizedMinLimit = normalizedMaxLimit
            }

            var subcategory = settings.categories[categoryIndex].subcategories[subIndex]
            subcategory.percentage = normalizedPercentage
            subcategory.fixedMinimumPercentage = nil
            subcategory.minLimit = normalizedMinLimit
            subcategory.maxLimit = normalizedMaxLimit > 0 ? normalizedMaxLimit : nil
            settings.categories[categoryIndex].subcategories[subIndex] = subcategory
            moveExcessAboveMaxToBank(categoryType: setup.categoryType, subcategoryID: subcategory.id)
            didChange = true
        }

        guard didChange else { return }
        normalizePriorityRules()
        recalculate()
    }

    func applyStartOnboardingConfiguration(_ configuration: StartOnboardingConfiguration) {
        settings = configuration.settings
        normalizePriorityRules()
        income = 0
        lastIncomeAmount = max(0, configuration.input.monthlyIncome)
        bankBalance = 0

        allocatedBySubcategoryID = [:]
        categoryTargetBaselineByID = [:]
        lastIncomeToBankByCategoryID = [:]
        lastBankAutoDistributedBySubcategoryID = [:]
        clearMonthlyTracking()
        monthlyTrackingMonthKey = Self.makeMonthKey()

        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()

        if configuration.input.monthlyIncome > 0 {
            income = configuration.input.monthlyIncome
            applyIncomeDelta(configuration.input.monthlyIncome)
        }

        let startingFreeCapital = configuration.input.positiveCapital
        if startingFreeCapital > 0 {
            bankBalance += startingFreeCapital
            let allocationsBefore = allocatedBySubcategoryID
            allocationEngine.resolveMinimumDeficitsFromBank(
                settings: settings,
                allocatedBySubcategoryID: &allocatedBySubcategoryID,
                bankBalance: &bankBalance,
                lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID,
                trackAutoDistribution: true
            )
            recordMonthlyOtherIncomingChanges(from: allocationsBefore, to: allocatedBySubcategoryID)
        }

        recalculate()
    }

    func deleteSubcategory(categoryType: ExpenseCategoryType, subcategoryID: UUID) {
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }
        guard let subIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }

        let subcategory = settings.categories[categoryIndex].subcategories[subIndex]
        guard !subcategory.isSystem else { return }

        let allocated = allocatedBySubcategoryID[subcategoryID, default: 0]
        let remaining = max(0, allocated - subcategory.spentAmount)
        bankBalance += remaining
        topUpEmergencyReserveFromFreeCapital()

        settings.categories[categoryIndex].subcategories.remove(at: subIndex)
        allocatedBySubcategoryID.removeValue(forKey: subcategoryID)
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()
        recalculate()
    }

    func remainingForSubcategory(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID
    ) -> Double {
        distribution.categoryAllocations
            .first(where: { $0.type == categoryType })?
            .subcategoryAllocations
            .first(where: { $0.id == subcategoryID })?
            .remainingAmount ?? 0
    }

    var bankAvailableAmount: Double {
        max(0, bankBalance)
    }

    @discardableResult
    private func performExpense(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double,
        forcedAllocations: [UUID: Double]?,
        useAutomaticForcedCoverage: Bool,
        fundingStrategy: ExpenseFundingStrategy
    ) -> Bool {
        let normalizedAmount = roundToCents(max(0, amount))
        guard normalizedAmount > 0 else { return false }
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return false }
        guard let subcategoryIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return false }

        let category = settings.categories[categoryIndex]
        let target = category.subcategories[subcategoryIndex]
        let upfrontBankContribution = fundingStrategy == .freeCapitalFirst
            ? min(bankAvailableAmount, normalizedAmount)
            : 0
        let categoryChargeAmount = normalizedAmount - upfrontBankContribution

        let currentRemaining = availableBalance(for: target)
        if categoryChargeAmount > currentRemaining + 0.0001 {
            let autoNeeded = categoryChargeAmount - currentRemaining
            _ = autoReallocateExcessWithinCategory(
                categoryIndex: categoryIndex,
                targetSubcategoryID: subcategoryID,
                neededAmount: autoNeeded
            )
        }

        var remainingAfterAuto = availableBalance(for: settings.categories[categoryIndex].subcategories[subcategoryIndex])
        var shortageAfterAuto = max(0, categoryChargeAmount - remainingAfterAuto)

        if fundingStrategy == .categoryFirst, shortageAfterAuto > 0.0001 {
            let bankContribution = min(bankAvailableAmount, shortageAfterAuto)
            shortageAfterAuto = max(0, shortageAfterAuto - bankContribution)
        }

        if shortageAfterAuto > 0.0001 {
            if useAutomaticForcedCoverage {
                guard applyForcedAutomaticCoverage(
                    categoryIndex: categoryIndex,
                    targetSubcategoryID: subcategoryID,
                    shortageAmount: shortageAfterAuto
                ) else {
                    return false
                }
            } else if let forcedAllocations {
                guard applyManualForcedCoverage(
                    categoryIndex: categoryIndex,
                    targetSubcategoryID: subcategoryID,
                    allocations: forcedAllocations
                ) else {
                    return false
                }
            } else {
                return false
            }
        }

        remainingAfterAuto = availableBalance(for: settings.categories[categoryIndex].subcategories[subcategoryIndex])
        let operationBefore = makeOperationSnapshot()

        switch fundingStrategy {
        case .categoryFirst:
            let bankShortage = max(0, normalizedAmount - remainingAfterAuto)
            guard bankShortage <= bankAvailableAmount + 0.0001 else { return false }
            bankBalance -= bankShortage
            allocatedBySubcategoryID[subcategoryID, default: 0] += bankShortage
            recordMonthlyOtherIncoming(for: subcategoryID, amount: bankShortage)
        case .freeCapitalFirst:
            guard remainingAfterAuto + 0.0001 >= categoryChargeAmount else { return false }
            bankBalance -= upfrontBankContribution
            allocatedBySubcategoryID[subcategoryID, default: 0] += upfrontBankContribution
            recordMonthlyOtherIncoming(for: subcategoryID, amount: upfrontBankContribution)
        }

        let subcategory = settings.categories[categoryIndex].subcategories[subcategoryIndex]
        settings.categories[categoryIndex].subcategories[subcategoryIndex].spentAmount += normalizedAmount
        appendHistoryEvent(
            BudgetHistoryEvent(
                type: .expense,
                amount: normalizedAmount,
                currencyCode: settings.currencyCode,
                categoryType: categoryType,
                categoryTitleSnapshot: categoryType.title,
                subcategoryID: subcategory.id,
                subcategoryNameSnapshot: subcategory.name,
                iconNameSnapshot: subcategory.iconName,
                undoDelta: makeOperationDelta(from: operationBefore, to: makeOperationSnapshot())
            )
        )
        recalculate()
        return true
    }

    private func appendFreeCapitalFundingLine(
        amount: Double,
        to lines: inout [ExpenseFundingLine],
        remainingNeed: inout Double
    ) {
        guard amount > 0.0001 else { return }

        lines.append(
            ExpenseFundingLine(
                subcategoryID: nil,
                title: "Свободный капитал",
                iconName: "building.columns.fill",
                amount: roundToCents(amount),
                kind: .freeCapital
            )
        )
        remainingNeed = max(0, remainingNeed - amount)
    }

    @discardableResult
    private func performAddCustomSubcategory(
        categoryType: ExpenseCategoryType,
        name: String,
        iconName: String,
        percentage: Double,
        minLimit: Double,
        maxLimit: Double,
        priority: SubcategoryPriorityLevel,
        forcedAllocations: [UUID: Double]?,
        useAutomaticForcedCoverage: Bool
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPercentage = max(0, percentage)
        guard !trimmedName.isEmpty, normalizedPercentage > 0 else { return false }
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return false }

        let currentTotal = settings.categories[categoryIndex].subcategories.reduce(0) { $0 + $1.percentage }
        let freePercent = max(0, 100 - currentTotal)
        guard normalizedPercentage <= freePercent + 0.0001 else { return false }

        let normalizedMaxLimit = max(0, maxLimit)
        var normalizedMinLimit = max(0, minLimit)
        guard normalizedMinLimit > 0 else { return false }
        if normalizedMaxLimit > 0, normalizedMinLimit > normalizedMaxLimit {
            normalizedMinLimit = normalizedMaxLimit
        }

        let requirement = newSubcategoryCoverageRequirement(
            categoryType: categoryType,
            minLimit: normalizedMinLimit
        )
        if let requirement {
            guard requirement.canCover else { return false }
            if !useAutomaticForcedCoverage && forcedAllocations == nil {
                return false
            }
        }

        let newSubcategoryID = UUID()
        let subcategory = Subcategory(
            id: newSubcategoryID,
            name: trimmedName,
            iconName: SubcategoryIconCatalog.normalized(iconName),
            percentage: normalizedPercentage,
            fixedMinimumPercentage: nil,
            minLimit: normalizedMinLimit > 0 ? normalizedMinLimit : nil,
            maxLimit: normalizedMaxLimit > 0 ? normalizedMaxLimit : nil,
            priority: SubcategoryPriorityLevel.low.rawValue
        )

        settings.categories[categoryIndex].subcategories.append(subcategory)
        normalizePriorityRules()
        allocatedBySubcategoryID[newSubcategoryID] = 0
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()

        _ = autoReallocateExcessWithinCategory(
            categoryIndex: categoryIndex,
            targetSubcategoryID: newSubcategoryID,
            neededAmount: normalizedMinLimit
        )

        let currentAllocated = allocatedBySubcategoryID[newSubcategoryID, default: 0]
        let bankTopUp = min(bankAvailableAmount, max(0, normalizedMinLimit - currentAllocated))
        if bankTopUp > 0 {
            let operationBefore = makeOperationSnapshot()
            bankBalance -= bankTopUp
            allocatedBySubcategoryID[newSubcategoryID, default: 0] += bankTopUp
            recordMonthlyOtherIncoming(for: newSubcategoryID, amount: bankTopUp)
            appendHistoryEvent(
                BudgetHistoryEvent(
                    type: .transferFromFreeCapital,
                    amount: roundToCents(bankTopUp),
                    currencyCode: settings.currencyCode,
                    categoryType: categoryType,
                    categoryTitleSnapshot: categoryType.title,
                    subcategoryID: newSubcategoryID,
                    subcategoryNameSnapshot: trimmedName,
                    iconNameSnapshot: subcategory.iconName,
                    undoDelta: makeOperationDelta(from: operationBefore, to: makeOperationSnapshot())
                )
            )
        }

        let shortageAfterNormal = max(0, normalizedMinLimit - allocatedBySubcategoryID[newSubcategoryID, default: 0])
        if shortageAfterNormal > 0.0001 {
            let forcedApplied: Bool
            if useAutomaticForcedCoverage {
                forcedApplied = applyForcedAutomaticCoverage(
                    categoryIndex: categoryIndex,
                    targetSubcategoryID: newSubcategoryID,
                    shortageAmount: shortageAfterNormal
                )
            } else if let forcedAllocations {
                forcedApplied = applyManualForcedCoverage(
                    categoryIndex: categoryIndex,
                    targetSubcategoryID: newSubcategoryID,
                    allocations: forcedAllocations
                )
            } else {
                forcedApplied = false
            }

            if !forcedApplied {
                settings.categories[categoryIndex].subcategories.removeAll { $0.id == newSubcategoryID }
                allocatedBySubcategoryID.removeValue(forKey: newSubcategoryID)
                syncLastBankAutoDistributionStorageWithSettings()
                return false
            }
        }

        recalculate()
        return true
    }

    private func automaticCategoryCoverageAmount(
        in category: ExpenseCategory,
        excluding subcategoryID: UUID?
    ) -> Double {
        let categoryRemainingAmount = categoryCurrentRemaining(for: category)
        return category.subcategories
            .filter { $0.id != subcategoryID }
            .reduce(0.0) { partialResult, subcategory in
                let remaining = availableBalance(for: subcategory)
                let protectedAmount = minimumCommitment(
                    for: subcategory,
                    categoryAmount: categoryRemainingAmount
                )
                return partialResult + max(0, remaining - protectedAmount)
            }
    }

    private func forcedCoverageCandidates(
        in category: ExpenseCategory,
        excluding subcategoryID: UUID?
    ) -> [CategoryCoverageCandidate] {
        let categoryRemainingAmount = categoryCurrentRemaining(for: category)

        return category.subcategories.compactMap { subcategory in
            guard subcategory.id != subcategoryID else { return nil }
            let remaining = availableBalance(for: subcategory)
            guard remaining > 0.0001 else { return nil }

            let protectedAmount = minimumCommitment(
                for: subcategory,
                categoryAmount: categoryRemainingAmount
            )
            let alreadyFreeAmount = max(0, remaining - protectedAmount)
            let forcedAmount = max(0, remaining - alreadyFreeAmount)
            guard forcedAmount > 0.0001 else { return nil }

            return CategoryCoverageCandidate(
                subcategoryID: subcategory.id,
                name: subcategory.name,
                iconName: subcategory.iconName,
                availableAmount: roundToCents(forcedAmount)
            )
        }
        .sorted { $0.availableAmount > $1.availableAmount }
    }

    @discardableResult
    private func autoReallocateExcessWithinCategory(
        categoryIndex: Int,
        targetSubcategoryID: UUID,
        neededAmount: Double
    ) -> Double {
        guard settings.categories.indices.contains(categoryIndex) else { return 0 }
        guard neededAmount > 0.0001 else { return 0 }

        let category = settings.categories[categoryIndex]
        let categoryRemainingAmount = categoryCurrentRemaining(for: category)
        var remainingNeed = neededAmount
        var transferred: Double = 0
        let priorityOrder = [SubcategoryPriorityLevel.low.rawValue, SubcategoryPriorityLevel.medium.rawValue, SubcategoryPriorityLevel.high.rawValue]

        for level in priorityOrder {
            for donor in category.subcategories where donor.id != targetSubcategoryID && donor.priority == level {
                guard remainingNeed > 0.0001 else { break }

                let donorRemaining = availableBalance(for: donor)
                let protectedAmount = minimumCommitment(
                    for: donor,
                    categoryAmount: categoryRemainingAmount
                )
                let freeAmount = max(0, donorRemaining - protectedAmount)
                let transferAmount = min(freeAmount, remainingNeed)
                guard transferAmount > 0.0001 else { continue }

                let operationBefore = makeOperationSnapshot()
                allocatedBySubcategoryID[donor.id, default: 0] -= transferAmount
                allocatedBySubcategoryID[targetSubcategoryID, default: 0] += transferAmount
                recordMonthlyOtherIncoming(for: targetSubcategoryID, amount: transferAmount)
                recordMonthlyOtherOutgoing(for: donor.id, amount: transferAmount)
                appendCategoryTransferHistory(
                    categoryType: category.type,
                    from: donor,
                    to: settings.categories[categoryIndex].subcategories.first(where: { $0.id == targetSubcategoryID }) ?? donor,
                    amount: transferAmount,
                    undoDelta: makeOperationDelta(from: operationBefore, to: makeOperationSnapshot())
                )
                transferred += transferAmount
                remainingNeed -= transferAmount
            }
        }

        return roundToCents(transferred)
    }

    private func applyForcedAutomaticCoverage(
        categoryIndex: Int,
        targetSubcategoryID: UUID,
        shortageAmount: Double
    ) -> Bool {
        let category = settings.categories[categoryIndex]
        let candidates = forcedCoverageCandidates(
            in: category,
            excluding: targetSubcategoryID
        )
        let totalAvailable = candidates.reduce(0) { $0 + $1.availableAmount }
        guard totalAvailable + 0.0001 >= shortageAmount else { return false }
        guard let target = settings.categories[categoryIndex].subcategories.first(where: { $0.id == targetSubcategoryID }) else { return false }
        guard let allocations = automaticForcedCoverageAllocations(
            candidates: candidates,
            shortageAmount: shortageAmount
        ) else { return false }
        return applyForcedCoverageAllocations(
            categoryIndex: categoryIndex,
            target: target,
            allocations: allocations
        )
    }

    private func automaticForcedCoverageAllocations(
        candidates: [CategoryCoverageCandidate],
        shortageAmount: Double
    ) -> [UUID: Double]? {
        let normalizedShortage = roundToCents(max(0, shortageAmount))
        guard normalizedShortage > 0.0001 else { return [:] }

        let totalAvailable = candidates.reduce(0) { $0 + $1.availableAmount }
        guard totalAvailable + 0.0001 >= normalizedShortage else { return nil }

        var remainingNeed = normalizedShortage
        var allocations: [UUID: Double] = [:]

        for (index, candidate) in candidates.enumerated() where remainingNeed > 0.0001 {
            let proposedAmount: Double
            if index == candidates.count - 1 {
                proposedAmount = remainingNeed
            } else {
                proposedAmount = roundToCents(normalizedShortage * (candidate.availableAmount / totalAvailable))
            }

            let amount = min(candidate.availableAmount, remainingNeed, max(0, proposedAmount))
            guard amount > 0.0001 else { continue }
            allocations[candidate.subcategoryID] = amount
            remainingNeed = max(0, remainingNeed - amount)
        }

        if remainingNeed > 0.0001 {
            for candidate in candidates where remainingNeed > 0.0001 {
                let current = allocations[candidate.subcategoryID, default: 0]
                let spare = max(0, candidate.availableAmount - current)
                guard spare > 0.0001 else { continue }
                let extra = min(spare, remainingNeed)
                allocations[candidate.subcategoryID] = current + extra
                remainingNeed = max(0, remainingNeed - extra)
            }
        }

        guard remainingNeed <= 0.0001 else { return nil }
        return allocations.mapValues(roundToCents)
    }

    private func applyManualForcedCoverage(
        categoryIndex: Int,
        targetSubcategoryID: UUID,
        allocations: [UUID: Double]
    ) -> Bool {
        guard let target = settings.categories[categoryIndex].subcategories.first(where: { $0.id == targetSubcategoryID }) else { return false }
        return applyForcedCoverageAllocations(
            categoryIndex: categoryIndex,
            target: target,
            allocations: allocations
        )
    }

    private func applyForcedCoverageAllocations(
        categoryIndex: Int,
        target: Subcategory,
        allocations: [UUID: Double]
    ) -> Bool {
        guard settings.categories.indices.contains(categoryIndex) else { return false }
        let category = settings.categories[categoryIndex]
        let availableByID = Dictionary(
            uniqueKeysWithValues: forcedCoverageCandidates(in: category, excluding: target.id).map {
                ($0.subcategoryID, $0.availableAmount)
            }
        )

        var totalApplied: Double = 0

        for (donorID, rawAmount) in allocations {
            let amount = roundToCents(max(0, rawAmount))
            guard amount > 0.0001 else { continue }
            guard let available = availableByID[donorID], amount <= available + 0.0001 else { return false }
            guard let donor = settings.categories[categoryIndex].subcategories.first(where: { $0.id == donorID }) else { return false }

            let operationBefore = makeOperationSnapshot()
            allocatedBySubcategoryID[donorID, default: 0] -= amount
            allocatedBySubcategoryID[target.id, default: 0] += amount
            recordMonthlyOtherIncoming(for: target.id, amount: amount)
            recordMonthlyOtherOutgoing(for: donorID, amount: amount)
            appendCategoryTransferHistory(
                categoryType: category.type,
                from: donor,
                to: target,
                amount: amount,
                undoDelta: makeOperationDelta(from: operationBefore, to: makeOperationSnapshot())
            )
            totalApplied += amount
        }

        return totalApplied > 0.0001
    }

    private func appendCategoryTransferHistory(
        categoryType: ExpenseCategoryType,
        from source: Subcategory,
        to target: Subcategory,
        amount: Double,
        undoDelta: BudgetOperationDelta?
    ) {
        appendHistoryEvent(
            BudgetHistoryEvent(
                type: .categoryReallocation,
                amount: roundToCents(amount),
                currencyCode: settings.currencyCode,
                categoryType: categoryType,
                categoryTitleSnapshot: categoryType.title,
                subcategoryID: source.id,
                subcategoryNameSnapshot: source.name,
                iconNameSnapshot: source.iconName,
                counterpartyNameSnapshot: target.name,
                undoDelta: undoDelta
            )
        )
    }

    private func availableBalance(for subcategory: Subcategory) -> Double {
        let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
        return max(0, allocated - subcategory.spentAmount)
    }

    private func syncAllocationStorageWithSettings() {
        let validIDs = Set(settings.categories.flatMap { $0.subcategories.map(\.id) })

        allocatedBySubcategoryID = allocatedBySubcategoryID
            .filter { validIDs.contains($0.key) }

        for id in validIDs where allocatedBySubcategoryID[id] == nil {
            allocatedBySubcategoryID[id] = 0
        }
    }

    private func syncTargetBaselineStorageWithSettings() {
        let validCategoryIDs = Set(settings.categories.map(\.id))

        categoryTargetBaselineByID = categoryTargetBaselineByID
            .filter { validCategoryIDs.contains($0.key) }

        for id in validCategoryIDs where categoryTargetBaselineByID[id] == nil {
            categoryTargetBaselineByID[id] = 0
        }
    }

    private func syncLastIncomeToBankStorageWithSettings() {
        let validCategoryIDs = Set(settings.categories.map(\.id))

        lastIncomeToBankByCategoryID = lastIncomeToBankByCategoryID
            .filter { validCategoryIDs.contains($0.key) }

        for id in validCategoryIDs where lastIncomeToBankByCategoryID[id] == nil {
            lastIncomeToBankByCategoryID[id] = 0
        }
    }

    private func syncLastBankAutoDistributionStorageWithSettings() {
        let validSubcategoryIDs = Set(settings.categories.flatMap { $0.subcategories.map(\.id) })

        lastBankAutoDistributedBySubcategoryID = lastBankAutoDistributedBySubcategoryID
            .filter { validSubcategoryIDs.contains($0.key) }
    }

    private func syncMonthlyIncomeStorageWithSettings() {
        let validSubcategoryIDs = Set(settings.categories.flatMap { $0.subcategories.map(\.id) })

        monthlyIncomeBySubcategoryID = monthlyIncomeBySubcategoryID
            .filter { validSubcategoryIDs.contains($0.key) }
        monthlyIncomeDistributionBySubcategoryID = monthlyIncomeDistributionBySubcategoryID
            .filter { validSubcategoryIDs.contains($0.key) }
        monthlyOtherIncomingBySubcategoryID = monthlyOtherIncomingBySubcategoryID
            .filter { validSubcategoryIDs.contains($0.key) }
        monthlyOtherOutgoingBySubcategoryID = monthlyOtherOutgoingBySubcategoryID
            .filter { validSubcategoryIDs.contains($0.key) }
    }

    private func applyIncomeDelta(_ deltaIncome: Double) {
        let allocationsBefore = allocatedBySubcategoryID
        allocationEngine.applyIncomeDelta(
            deltaIncome,
            settings: settings,
            categoryTargetBaselineByID: &categoryTargetBaselineByID,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance,
            lastIncomeToBankByCategoryID: &lastIncomeToBankByCategoryID,
            lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID
        )
        recordMonthlyIncomeDistributionChanges(from: allocationsBefore, to: allocatedBySubcategoryID)
        topUpEmergencyReserveFromFreeCapital()
    }

    private func buildDistribution() -> BudgetDistribution {
        let monthlyExpenseBySubcategoryID = currentMonthExpenseBySubcategoryID()

        let categoryAllocations: [CategoryAllocation] = settings.categories.map { category in
            let categoryAllocatedAmount = categoryCurrentAllocated(for: category)

            let subcategoryAllocations: [SubcategoryAllocation] = category.subcategories.map { subcategory in
                let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
                let spent = subcategory.spentAmount
                let remaining = max(0, allocated - spent)
                let minimumTarget = minimumFloorForRebalance(for: subcategory)
                let deficit = max(0, minimumTarget - remaining)
                let monthlyIncome = monthlyIncomeBySubcategoryID[subcategory.id, default: 0]
                let monthlyIncomeDistribution = monthlyIncomeDistributionBySubcategoryID[subcategory.id, default: 0]
                let storedMonthlyOtherIncoming = monthlyOtherIncomingBySubcategoryID[subcategory.id, default: 0]
                let monthlyOtherIncoming = monthlyIncomeDistribution > 0.0001 || storedMonthlyOtherIncoming > 0.0001
                    ? storedMonthlyOtherIncoming
                    : monthlyIncome
                let monthlyOtherOutgoing = monthlyOtherOutgoingBySubcategoryID[subcategory.id, default: 0]
                let monthlyExpense = monthlyExpenseBySubcategoryID[subcategory.id, default: 0]

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
                    spentAmount: roundToCents(spent),
                    remainingAmount: roundToCents(remaining),
                    deficitAmount: roundToCents(deficit),
                    monthlyIncomeAmount: roundToCents(monthlyIncome),
                    monthlyIncomeDistributionAmount: roundToCents(monthlyIncomeDistribution),
                    monthlyOtherIncomingAmount: roundToCents(monthlyOtherIncoming),
                    monthlyExpenseAmount: roundToCents(monthlyExpense),
                    monthlyOtherOutgoingAmount: roundToCents(monthlyOtherOutgoing)
                )
            }

            let categoryDeficit = subcategoryAllocations.reduce(0) { $0 + $1.deficitAmount }

            return CategoryAllocation(
                id: category.id,
                type: category.type,
                percentage: category.percentage,
                allocatedAmount: roundToCents(categoryAllocatedAmount),
                lastIncomeToBankAmount: roundToCents(lastIncomeToBankByCategoryID[category.id, default: 0]),
                subcategoryAllocations: subcategoryAllocations,
                deficitAmount: roundToCents(categoryDeficit)
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
            income: roundToCents(income),
            categoryAllocations: categoryAllocations,
            bankAmount: roundToCents(max(0, bankBalance)),
            lastBankAutoDistributions: bankAutoLines
        )
    }

    private func categoryCurrentAllocated(for category: ExpenseCategory) -> Double {
        category.subcategories.reduce(0) { partialResult, subcategory in
            partialResult + allocatedBySubcategoryID[subcategory.id, default: 0]
        }
    }

    private func categoryCurrentRemaining(for category: ExpenseCategory) -> Double {
        category.subcategories.reduce(0) { partialResult, subcategory in
            let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
            let remaining = max(0, allocated - subcategory.spentAmount)
            return partialResult + remaining
        }
    }

    private func availableMoneyForNewMinLimit(categoryIndex: Int) -> Double {
        let category = settings.categories[categoryIndex]
        let categoryRemainingAmount = categoryCurrentRemaining(for: category)

        let committedMinimums = category.subcategories.reduce(0.0) { partialResult, subcategory in
            partialResult + minimumCommitment(for: subcategory, categoryAmount: categoryRemainingAmount)
        }

        let freeInsideCategory = max(0, categoryRemainingAmount - committedMinimums)
        return freeInsideCategory + bankAvailableAmount
    }

    private func availableMoneyForEditedMinLimit(categoryIndex: Int, excludingSubcategoryID: UUID) -> Double {
        let category = settings.categories[categoryIndex]
        let categoryRemainingAmount = categoryCurrentRemaining(for: category)

        let committedMinimumsWithoutCurrent = category.subcategories
            .filter { $0.id != excludingSubcategoryID }
            .reduce(0.0) { partialResult, subcategory in
                partialResult + minimumCommitment(for: subcategory, categoryAmount: categoryRemainingAmount)
            }

        let freeInsideCategory = max(0, categoryRemainingAmount - committedMinimumsWithoutCurrent)
        return freeInsideCategory + bankAvailableAmount
    }

    private func rebalanceForNewSubcategoryMinimum(in categoryIndex: Int, newSubcategoryID: UUID) {
        allocationEngine.rebalanceForNewSubcategoryMinimum(
            in: categoryIndex,
            newSubcategoryID: newSubcategoryID,
            settings: settings,
            allocatedBySubcategoryID: &allocatedBySubcategoryID
        )
    }

    private func minimumCommitment(for subcategory: Subcategory, categoryAmount: Double) -> Double {
        let cap = maxCap(for: subcategory)

        let minLimitTarget = min(max(0, subcategory.minLimit ?? 0), cap)
        if minLimitTarget > 0 {
            return minLimitTarget
        }

        let basePercentTarget = min(
            categoryAmount * (max(0, subcategory.percentage) / 100.0),
            cap
        )
        return max(0, basePercentTarget)
    }

    private func minimumFloorForRebalance(for subcategory: Subcategory) -> Double {
        allocationEngine.minimumFloorForRebalance(for: subcategory)
    }

    private func moveExcessAboveMaxToBank(categoryType: ExpenseCategoryType, subcategoryID: UUID) {
        allocationEngine.moveExcessAboveMaxToBank(
            categoryType: categoryType,
            subcategoryID: subcategoryID,
            settings: settings,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance
        )
        topUpEmergencyReserveFromFreeCapital()
    }

    private func topUpEmergencyReserveFromFreeCapital() {
        let allocationsBefore = allocatedBySubcategoryID
        allocationEngine.resolveEmergencyReserveMinimumFromBank(
            settings: settings,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance,
            lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID,
            trackAutoDistribution: true
        )
        recordMonthlyOtherIncomingChanges(from: allocationsBefore, to: allocatedBySubcategoryID)
    }

    private func maxCap(for subcategory: Subcategory) -> Double {
        guard let maxLimit = subcategory.maxLimit, maxLimit > 0 else {
            return .greatestFiniteMagnitude
        }
        return maxLimit
    }

    private func roundToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private func makeOperationSnapshot() -> BudgetOperationStateSnapshot {
        BudgetOperationStateSnapshot(
            income: income,
            bankBalance: bankBalance,
            allocatedBySubcategoryID: allocatedBySubcategoryID,
            spentBySubcategoryID: currentSpentBySubcategoryID(),
            monthlyIncomeBySubcategoryID: monthlyIncomeBySubcategoryID,
            monthlyIncomeDistributionBySubcategoryID: monthlyIncomeDistributionBySubcategoryID,
            monthlyOtherIncomingBySubcategoryID: monthlyOtherIncomingBySubcategoryID,
            monthlyOtherOutgoingBySubcategoryID: monthlyOtherOutgoingBySubcategoryID,
            categoryTargetBaselineByID: categoryTargetBaselineByID
        )
    }

    private func restoreOperationSnapshot(_ snapshot: BudgetOperationStateSnapshot) {
        income = snapshot.income
        bankBalance = snapshot.bankBalance
        allocatedBySubcategoryID = snapshot.allocatedBySubcategoryID
        monthlyIncomeBySubcategoryID = snapshot.monthlyIncomeBySubcategoryID
        monthlyIncomeDistributionBySubcategoryID = snapshot.monthlyIncomeDistributionBySubcategoryID
        monthlyOtherIncomingBySubcategoryID = snapshot.monthlyOtherIncomingBySubcategoryID
        monthlyOtherOutgoingBySubcategoryID = snapshot.monthlyOtherOutgoingBySubcategoryID
        categoryTargetBaselineByID = snapshot.categoryTargetBaselineByID

        for categoryIndex in settings.categories.indices {
            for subcategoryIndex in settings.categories[categoryIndex].subcategories.indices {
                let subcategoryID = settings.categories[categoryIndex].subcategories[subcategoryIndex].id
                settings.categories[categoryIndex].subcategories[subcategoryIndex].spentAmount =
                    snapshot.spentBySubcategoryID[subcategoryID, default: settings.categories[categoryIndex].subcategories[subcategoryIndex].spentAmount]
            }
        }
    }

    private func makeOperationDelta(
        from before: BudgetOperationStateSnapshot,
        to after: BudgetOperationStateSnapshot
    ) -> BudgetOperationDelta? {
        let delta = BudgetOperationDelta(
            incomeDelta: after.income - before.income,
            bankBalanceDelta: after.bankBalance - before.bankBalance,
            allocatedBySubcategoryIDDelta: encodeUUIDMapDelta(
                before: before.allocatedBySubcategoryID,
                after: after.allocatedBySubcategoryID
            ),
            spentBySubcategoryIDDelta: encodeUUIDMapDelta(
                before: before.spentBySubcategoryID,
                after: after.spentBySubcategoryID
            ),
            monthlyIncomeBySubcategoryIDDelta: encodeUUIDMapDelta(
                before: before.monthlyIncomeBySubcategoryID,
                after: after.monthlyIncomeBySubcategoryID
            ),
            monthlyIncomeDistributionBySubcategoryIDDelta: encodeUUIDMapDelta(
                before: before.monthlyIncomeDistributionBySubcategoryID,
                after: after.monthlyIncomeDistributionBySubcategoryID
            ),
            monthlyOtherIncomingBySubcategoryIDDelta: encodeUUIDMapDelta(
                before: before.monthlyOtherIncomingBySubcategoryID,
                after: after.monthlyOtherIncomingBySubcategoryID
            ),
            monthlyOtherOutgoingBySubcategoryIDDelta: encodeUUIDMapDelta(
                before: before.monthlyOtherOutgoingBySubcategoryID,
                after: after.monthlyOtherOutgoingBySubcategoryID
            ),
            categoryTargetBaselineByIDDelta: encodeUUIDMapDelta(
                before: before.categoryTargetBaselineByID,
                after: after.categoryTargetBaselineByID
            )
        )

        return delta.isEmpty ? nil : delta
    }

    private func applyReverseOperationDelta(_ delta: BudgetOperationDelta) -> Bool {
        let nextIncome = income - delta.incomeDelta
        let nextBankBalance = bankBalance - delta.bankBalanceDelta
        guard nextIncome >= -0.0001, nextBankBalance >= -0.0001 else { return false }

        income = max(0, nextIncome)
        bankBalance = max(0, nextBankBalance)

        guard applyReverseUUIDDelta(delta.allocatedBySubcategoryIDDelta, to: &allocatedBySubcategoryID),
              applyReverseUUIDDelta(delta.monthlyIncomeBySubcategoryIDDelta, to: &monthlyIncomeBySubcategoryID),
              applyReverseUUIDDelta(delta.monthlyIncomeDistributionBySubcategoryIDDelta, to: &monthlyIncomeDistributionBySubcategoryID),
              applyReverseUUIDDelta(delta.monthlyOtherIncomingBySubcategoryIDDelta, to: &monthlyOtherIncomingBySubcategoryID),
              applyReverseUUIDDelta(delta.monthlyOtherOutgoingBySubcategoryIDDelta, to: &monthlyOtherOutgoingBySubcategoryID),
              applyReverseUUIDDelta(delta.categoryTargetBaselineByIDDelta, to: &categoryTargetBaselineByID),
              applyReverseSpentDelta(delta.spentBySubcategoryIDDelta) else {
            return false
        }

        return true
    }

    private func applyReverseUUIDDelta(_ deltaByStringID: [String: Double], to values: inout [UUID: Double]) -> Bool {
        for (idString, delta) in deltaByStringID {
            guard let id = UUID(uuidString: idString) else { return false }
            let nextValue = values[id, default: 0] - delta
            guard nextValue >= -0.0001 else { return false }
            values[id] = max(0, nextValue)
        }

        return true
    }

    private func applyReverseSpentDelta(_ deltaByStringID: [String: Double]) -> Bool {
        for (idString, delta) in deltaByStringID {
            guard let id = UUID(uuidString: idString),
                  let indexPath = subcategoryIndexPath(for: id) else {
                return false
            }

            let currentSpent = settings.categories[indexPath.categoryIndex].subcategories[indexPath.subcategoryIndex].spentAmount
            let nextSpent = currentSpent - delta
            guard nextSpent >= -0.0001 else { return false }
            settings.categories[indexPath.categoryIndex].subcategories[indexPath.subcategoryIndex].spentAmount = max(0, nextSpent)
        }

        return true
    }

    private func currentSpentBySubcategoryID() -> [UUID: Double] {
        settings.categories.reduce(into: [:]) { partialResult, category in
            for subcategory in category.subcategories {
                partialResult[subcategory.id] = subcategory.spentAmount
            }
        }
    }

    private func encodeUUIDMapDelta(before: [UUID: Double], after: [UUID: Double]) -> [String: Double] {
        let allIDs = Set(before.keys).union(after.keys)
        return allIDs.reduce(into: [:]) { partialResult, id in
            let delta = after[id, default: 0] - before[id, default: 0]
            guard abs(delta) > 0.0001 else { return }
            partialResult[id.uuidString] = delta
        }
    }

    private func subcategoryIndexPath(for subcategoryID: UUID) -> (categoryIndex: Int, subcategoryIndex: Int)? {
        for categoryIndex in settings.categories.indices {
            if let subcategoryIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) {
                return (categoryIndex, subcategoryIndex)
            }
        }

        return nil
    }

    private func refreshLastIncomeAmountFromHistory() {
        lastIncomeAmount = historyEvents
            .sorted { $0.createdAt > $1.createdAt }
            .first(where: { $0.type == .income })?
            .amount ?? 0
    }

    private func persistCurrentState() {
        let state = BudgetPersistedState(
            income: income,
            lastIncomeAmount: lastIncomeAmount,
            settings: settings,
            allocatedBySubcategoryID: encodeUUIDMap(allocatedBySubcategoryID),
            categoryTargetBaselineByID: encodeUUIDMap(categoryTargetBaselineByID),
            lastIncomeToBankByCategoryID: encodeUUIDMap(lastIncomeToBankByCategoryID),
            lastBankAutoDistributedBySubcategoryID: encodeUUIDMap(lastBankAutoDistributedBySubcategoryID),
            monthlyIncomeBySubcategoryID: encodeUUIDMap(monthlyIncomeBySubcategoryID),
            monthlyIncomeDistributionBySubcategoryID: encodeUUIDMap(monthlyIncomeDistributionBySubcategoryID),
            monthlyOtherIncomingBySubcategoryID: encodeUUIDMap(monthlyOtherIncomingBySubcategoryID),
            monthlyOtherOutgoingBySubcategoryID: encodeUUIDMap(monthlyOtherOutgoingBySubcategoryID),
            monthlyTrackingMonthKey: monthlyTrackingMonthKey,
            bankBalance: bankBalance
        )
        persistenceService.saveBudgetState(state)
    }

    private func restoreFromPersistedState(_ persistedState: BudgetPersistedState) {
        income = max(0, persistedState.income)
        lastIncomeAmount = max(0, persistedState.lastIncomeAmount)
        settings = persistedState.settings
        normalizePriorityRules()

        allocatedBySubcategoryID = decodeUUIDMap(persistedState.allocatedBySubcategoryID)
        categoryTargetBaselineByID = decodeUUIDMap(persistedState.categoryTargetBaselineByID)
        lastIncomeToBankByCategoryID = decodeUUIDMap(persistedState.lastIncomeToBankByCategoryID)
        lastBankAutoDistributedBySubcategoryID = [:]
        monthlyIncomeBySubcategoryID = decodeUUIDMap(persistedState.monthlyIncomeBySubcategoryID)
        monthlyIncomeDistributionBySubcategoryID = decodeUUIDMap(persistedState.monthlyIncomeDistributionBySubcategoryID)
        monthlyOtherIncomingBySubcategoryID = decodeUUIDMap(persistedState.monthlyOtherIncomingBySubcategoryID)
        monthlyOtherOutgoingBySubcategoryID = decodeUUIDMap(persistedState.monthlyOtherOutgoingBySubcategoryID)
        monthlyTrackingMonthKey = persistedState.monthlyTrackingMonthKey
        bankBalance = max(0, persistedState.bankBalance)

        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        syncMonthlyIncomeStorageWithSettings()
        rolloverMonthlyTrackingIfNeeded()
    }

    private func encodeUUIDMap(_ map: [UUID: Double]) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: map.map { ($0.key.uuidString, $0.value) })
    }

    private func decodeUUIDMap(_ map: [String: Double]) -> [UUID: Double] {
        map.reduce(into: [:]) { partialResult, pair in
            guard let id = UUID(uuidString: pair.key) else { return }
            partialResult[id] = pair.value
        }
    }

    private func appendHistoryEvent(_ event: BudgetHistoryEvent) {
        historyEvents.insert(event, at: 0)
        historyStorage.append(event)
    }

    private func clearHistory() {
        historyEvents = []
        historyStorage.clear()
    }

    private func currentMonthExpenseBySubcategoryID(now: Date = Date()) -> [UUID: Double] {
        let currentMonthKey = Self.makeMonthKey(for: now, calendar: calendar)

        return historyEvents.reduce(into: [:]) { partialResult, event in
            guard event.type == .expense,
                  let subcategoryID = event.subcategoryID,
                  Self.makeMonthKey(for: event.createdAt, calendar: calendar) == currentMonthKey else { return }
            partialResult[subcategoryID, default: 0] += event.amount
        }
    }

    private func recordMonthlyIncome(for subcategoryID: UUID, amount: Double) {
        let normalized = roundToCents(max(0, amount))
        guard normalized > 0.0001 else { return }
        rolloverMonthlyTrackingIfNeeded()
        monthlyIncomeBySubcategoryID[subcategoryID, default: 0] += normalized
    }

    private func recordMonthlyIncomeDistribution(for subcategoryID: UUID, amount: Double) {
        let normalized = roundToCents(max(0, amount))
        guard normalized > 0.0001 else { return }
        recordMonthlyIncome(for: subcategoryID, amount: normalized)
        monthlyIncomeDistributionBySubcategoryID[subcategoryID, default: 0] += normalized
    }

    private func recordMonthlyOtherIncoming(for subcategoryID: UUID, amount: Double) {
        let normalized = roundToCents(max(0, amount))
        guard normalized > 0.0001 else { return }
        recordMonthlyIncome(for: subcategoryID, amount: normalized)
        monthlyOtherIncomingBySubcategoryID[subcategoryID, default: 0] += normalized
    }

    private func recordMonthlyOtherOutgoing(for subcategoryID: UUID, amount: Double) {
        let normalized = roundToCents(max(0, amount))
        guard normalized > 0.0001 else { return }
        rolloverMonthlyTrackingIfNeeded()
        monthlyOtherOutgoingBySubcategoryID[subcategoryID, default: 0] += normalized
    }

    private func recordMonthlyIncomeDistributionChanges(from before: [UUID: Double], to after: [UUID: Double]) {
        recordMonthlyIncomingChanges(from: before, to: after, recorder: recordMonthlyIncomeDistribution)
    }

    private func recordMonthlyOtherIncomingChanges(from before: [UUID: Double], to after: [UUID: Double]) {
        recordMonthlyIncomingChanges(from: before, to: after, recorder: recordMonthlyOtherIncoming)
    }

    private func recordMonthlyIncomingChanges(
        from before: [UUID: Double],
        to after: [UUID: Double],
        recorder: (UUID, Double) -> Void
    ) {
        let allIDs = Set(before.keys).union(after.keys)

        for id in allIDs {
            let delta = after[id, default: 0] - before[id, default: 0]
            if delta > 0.0001 {
                recorder(id, delta)
            }
        }
    }

    private func rolloverMonthlyTrackingIfNeeded(now: Date = Date()) {
        let currentMonthKey = Self.makeMonthKey(for: now, calendar: calendar)
        guard monthlyTrackingMonthKey != currentMonthKey else { return }
        monthlyTrackingMonthKey = currentMonthKey
        clearMonthlyTracking()
    }

    private func clearMonthlyTracking() {
        monthlyIncomeBySubcategoryID = [:]
        monthlyIncomeDistributionBySubcategoryID = [:]
        monthlyOtherIncomingBySubcategoryID = [:]
        monthlyOtherOutgoingBySubcategoryID = [:]
    }

    private static func makeMonthKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private func normalizePriorityRules() {
        for categoryIndex in settings.categories.indices {
            let category = settings.categories[categoryIndex]

            for subcategoryIndex in settings.categories[categoryIndex].subcategories.indices {
                let subcategory = settings.categories[categoryIndex].subcategories[subcategoryIndex]
                settings.categories[categoryIndex].subcategories[subcategoryIndex].priority =
                    canonicalPriority(for: subcategory, in: category).rawValue
            }
        }
    }

    private func canonicalPriority(
        for subcategory: Subcategory,
        in category: ExpenseCategory
    ) -> SubcategoryPriorityLevel {
        guard subcategory.isSystem else { return .low }

        switch category.type {
        case .essentials:
            let housingPercentage = category.subcategories.first(where: { $0.systemKey == .housing })?.percentage ?? 0
            let shouldPrioritizeFood = housingPercentage <= 10.0001
            if shouldPrioritizeFood {
                return subcategory.systemKey == .food ? .high : .medium
            }
            return subcategory.systemKey == .housing ? .high : .medium
        case .wants:
            return subcategory.systemKey == .shopping ? .high : .medium
        case .savings:
            let hasDebt = category.subcategories.contains(where: { $0.systemKey == .debt })
            if hasDebt {
                return subcategory.systemKey == .debt ? .high : .medium
            }
            return subcategory.systemKey == .emergencyFund ? .high : .medium
        }
    }
}
