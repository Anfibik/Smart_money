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
    private var bankBalance: Double = 0
    private let persistenceService: PersistenceService
    private let allocationEngine: BudgetAllocationEngine
    private let historyStorage: BudgetHistoryStorage

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

        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
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
        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        if normalized > 0 {
            income = normalized
            applyIncomeDelta(normalized)
        }

        recalculate()
    }

    func addIncome(_ value: Double) {
        let normalized = max(0, value)
        guard normalized > 0 else { return }

        lastIncomeAmount = normalized
        income += normalized
        lastIncomeToBankByCategoryID = [:]
        lastBankAutoDistributedBySubcategoryID = [:]
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
        applyIncomeDelta(normalized)
        appendHistoryEvent(
            BudgetHistoryEvent(
                type: .income,
                amount: normalized,
                currencyCode: settings.currencyCode
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

        for categoryIndex in settings.categories.indices {
            for subcategoryIndex in settings.categories[categoryIndex].subcategories.indices {
                settings.categories[categoryIndex].subcategories[subcategoryIndex].spentAmount = 0
            }
        }

        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()

        clearHistory()
        persistenceService.clearBudgetState()
        recalculate()
    }

    func resetToInitialSystemState() {
        settings = BudgetSettings()
        resetMoneyData()
    }

    func updateSettings(_ newSettings: BudgetSettings) {
        settings = newSettings
        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
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
            useAutomaticForcedCoverage: false
        )
    }

    func expenseCoverageRequirement(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double
    ) -> CategoryCoverageRequirement? {
        let normalizedAmount = max(0, amount)
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

    @discardableResult
    func addExpenseWithAutomaticForcedCoverage(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double
    ) -> Bool {
        performExpense(
            categoryType: categoryType,
            subcategoryID: subcategoryID,
            amount: amount,
            forcedAllocations: nil,
            useAutomaticForcedCoverage: true
        )
    }

    @discardableResult
    func addExpenseWithManualForcedCoverage(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        amount: Double,
        allocations: [UUID: Double]
    ) -> Bool {
        performExpense(
            categoryType: categoryType,
            subcategoryID: subcategoryID,
            amount: amount,
            forcedAllocations: allocations,
            useAutomaticForcedCoverage: false
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
        let minimumLevel = minimumFloorForRebalance(for: subcategory)
        let maxWithdrawable = max(0, remaining - minimumLevel)

        guard normalizedAmount <= maxWithdrawable + 0.0001 else { return }

        allocatedBySubcategoryID[subcategoryID] = max(0, allocated - normalizedAmount)
        bankBalance += normalizedAmount
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
                iconNameSnapshot: subcategory.iconName
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

        bankBalance -= normalizedAmount
        allocatedBySubcategoryID[subcategoryID, default: 0] += normalizedAmount
        appendHistoryEvent(
            BudgetHistoryEvent(
                type: .transferFromFreeCapital,
                amount: normalizedAmount,
                currencyCode: settings.currencyCode,
                categoryType: categoryType,
                categoryTitleSnapshot: categoryType.title,
                subcategoryID: subcategory.id,
                subcategoryNameSnapshot: subcategory.name,
                iconNameSnapshot: subcategory.iconName
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
        sub.priority = priority.rawValue

        settings.categories[categoryIndex].subcategories[subIndex] = sub
        enforceUniquePriority(in: categoryIndex, selectedLevel: priority, selectedID: subcategoryID)
        moveExcessAboveMaxToBank(categoryType: categoryType, subcategoryID: subcategoryID)
        recalculate()
    }

    func applySystemSubcategorySetup(_ setups: [SystemSubcategorySetup]) {
        guard !setups.isEmpty else { return }

        var didChange = false

        for setup in setups {
            guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == setup.categoryType }) else { continue }
            guard let subIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: {
                $0.isSystem && $0.name == setup.name
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
        recalculate()
    }

    func applyStartOnboardingConfiguration(_ configuration: StartOnboardingConfiguration) {
        settings = configuration.settings
        income = 0
        lastIncomeAmount = max(0, configuration.input.monthlyIncome)
        bankBalance = 0

        allocatedBySubcategoryID = [:]
        categoryTargetBaselineByID = [:]
        lastIncomeToBankByCategoryID = [:]
        lastBankAutoDistributedBySubcategoryID = [:]

        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()

        if configuration.input.monthlyIncome > 0 {
            income = configuration.input.monthlyIncome
            applyIncomeDelta(configuration.input.monthlyIncome)
        }

        let startingFreeCapital = configuration.input.positiveCapital
        if startingFreeCapital > 0 {
            bankBalance += startingFreeCapital
            allocationEngine.resolveMinimumDeficitsFromBank(
                settings: settings,
                allocatedBySubcategoryID: &allocatedBySubcategoryID,
                bankBalance: &bankBalance,
                lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID,
                trackAutoDistribution: true
            )
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
        useAutomaticForcedCoverage: Bool
    ) -> Bool {
        let normalizedAmount = max(0, amount)
        guard normalizedAmount > 0 else { return false }
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return false }
        guard let subcategoryIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return false }

        let category = settings.categories[categoryIndex]
        let target = category.subcategories[subcategoryIndex]

        let currentRemaining = availableBalance(for: target)
        if normalizedAmount > currentRemaining + 0.0001 {
            let autoNeeded = normalizedAmount - currentRemaining
            _ = autoReallocateExcessWithinCategory(
                categoryIndex: categoryIndex,
                targetSubcategoryID: subcategoryID,
                neededAmount: autoNeeded
            )
        }

        var remainingAfterAuto = availableBalance(for: settings.categories[categoryIndex].subcategories[subcategoryIndex])
        var shortageAfterAuto = max(0, normalizedAmount - remainingAfterAuto)

        if shortageAfterAuto > 0.0001 {
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
        let bankShortage = max(0, normalizedAmount - remainingAfterAuto)
        guard bankShortage <= bankAvailableAmount + 0.0001 else { return false }
        if bankShortage > 0 {
            bankBalance -= bankShortage
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
                iconNameSnapshot: subcategory.iconName
            )
        )
        recalculate()
        return true
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
            priority: priority.rawValue
        )

        settings.categories[categoryIndex].subcategories.append(subcategory)
        allocatedBySubcategoryID[newSubcategoryID] = 0
        syncLastBankAutoDistributionStorageWithSettings()
        enforceUniquePriority(in: categoryIndex, selectedLevel: priority, selectedID: newSubcategoryID)

        _ = autoReallocateExcessWithinCategory(
            categoryIndex: categoryIndex,
            targetSubcategoryID: newSubcategoryID,
            neededAmount: normalizedMinLimit
        )

        let currentAllocated = allocatedBySubcategoryID[newSubcategoryID, default: 0]
        let bankTopUp = min(bankAvailableAmount, max(0, normalizedMinLimit - currentAllocated))
        if bankTopUp > 0 {
            bankBalance -= bankTopUp
            allocatedBySubcategoryID[newSubcategoryID, default: 0] += bankTopUp
            appendHistoryEvent(
                BudgetHistoryEvent(
                    type: .transferFromFreeCapital,
                    amount: roundToCents(bankTopUp),
                    currencyCode: settings.currencyCode,
                    categoryType: categoryType,
                    categoryTitleSnapshot: categoryType.title,
                    subcategoryID: newSubcategoryID,
                    subcategoryNameSnapshot: trimmedName,
                    iconNameSnapshot: subcategory.iconName
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

                allocatedBySubcategoryID[donor.id, default: 0] -= transferAmount
                allocatedBySubcategoryID[targetSubcategoryID, default: 0] += transferAmount
                appendCategoryTransferHistory(
                    categoryType: category.type,
                    from: donor,
                    to: settings.categories[categoryIndex].subcategories.first(where: { $0.id == targetSubcategoryID }) ?? donor,
                    amount: transferAmount
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

        var remainingNeed = shortageAmount
        var allocations: [UUID: Double] = [:]

        for (index, candidate) in candidates.enumerated() {
            let amount: Double
            if index == candidates.count - 1 {
                amount = remainingNeed
            } else {
                amount = roundToCents(shortageAmount * (candidate.availableAmount / totalAvailable))
            }
            let capped = min(candidate.availableAmount, amount)
            allocations[candidate.subcategoryID] = capped
            remainingNeed -= capped
        }

        if remainingNeed > 0.0001 {
            for candidate in candidates where remainingNeed > 0.0001 {
                let current = allocations[candidate.subcategoryID, default: 0]
                let spare = max(0, candidate.availableAmount - current)
                guard spare > 0.0001 else { continue }
                let extra = min(spare, remainingNeed)
                allocations[candidate.subcategoryID] = current + extra
                remainingNeed -= extra
            }
        }

        guard remainingNeed <= 0.0001 else { return false }
        return applyForcedCoverageAllocations(
            categoryIndex: categoryIndex,
            target: target,
            allocations: allocations
        )
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

            allocatedBySubcategoryID[donorID, default: 0] -= amount
            allocatedBySubcategoryID[target.id, default: 0] += amount
            appendCategoryTransferHistory(
                categoryType: category.type,
                from: donor,
                to: target,
                amount: amount
            )
            totalApplied += amount
        }

        return totalApplied > 0.0001
    }

    private func appendCategoryTransferHistory(
        categoryType: ExpenseCategoryType,
        from source: Subcategory,
        to target: Subcategory,
        amount: Double
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
                counterpartyNameSnapshot: target.name
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
    private func applyIncomeDelta(_ deltaIncome: Double) {
        allocationEngine.applyIncomeDelta(
            deltaIncome,
            settings: settings,
            categoryTargetBaselineByID: &categoryTargetBaselineByID,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance,
            lastIncomeToBankByCategoryID: &lastIncomeToBankByCategoryID,
            lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID
        )
        topUpEmergencyReserveFromFreeCapital()
    }

    private func buildDistribution() -> BudgetDistribution {
        let categoryAllocations: [CategoryAllocation] = settings.categories.map { category in
            let categoryAllocatedAmount = categoryCurrentAllocated(for: category)

            let subcategoryAllocations: [SubcategoryAllocation] = category.subcategories.map { subcategory in
                let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
                let spent = subcategory.spentAmount
                let remaining = max(0, allocated - spent)
                let minimumTarget = minimumFloorForRebalance(for: subcategory)
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
                    spentAmount: roundToCents(spent),
                    remainingAmount: roundToCents(remaining),
                    deficitAmount: roundToCents(deficit)
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
        allocationEngine.resolveEmergencyReserveMinimumFromBank(
            settings: settings,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance,
            lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID,
            trackAutoDistribution: true
        )
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

    private func enforceUniquePriority(in categoryIndex: Int, selectedLevel: SubcategoryPriorityLevel, selectedID: UUID) {
        guard selectedLevel == .high || selectedLevel == .medium else { return }

        for index in settings.categories[categoryIndex].subcategories.indices {
            let existing = settings.categories[categoryIndex].subcategories[index]
            if existing.id != selectedID,
               existing.priority == selectedLevel.rawValue {
                settings.categories[categoryIndex].subcategories[index].priority = SubcategoryPriorityLevel.low.rawValue
            }
        }
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
            bankBalance: bankBalance
        )
        persistenceService.saveBudgetState(state)
    }

    private func restoreFromPersistedState(_ persistedState: BudgetPersistedState) {
        income = max(0, persistedState.income)
        lastIncomeAmount = max(0, persistedState.lastIncomeAmount)
        settings = persistedState.settings

        allocatedBySubcategoryID = decodeUUIDMap(persistedState.allocatedBySubcategoryID)
        categoryTargetBaselineByID = decodeUUIDMap(persistedState.categoryTargetBaselineByID)
        lastIncomeToBankByCategoryID = decodeUUIDMap(persistedState.lastIncomeToBankByCategoryID)
        lastBankAutoDistributedBySubcategoryID = [:]
        bankBalance = max(0, persistedState.bankBalance)

        syncAllocationStorageWithSettings()
        syncTargetBaselineStorageWithSettings()
        syncLastIncomeToBankStorageWithSettings()
        syncLastBankAutoDistributionStorageWithSettings()
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
}
