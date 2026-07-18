import Foundation

final class BudgetAllocationEngine {
    private let lowPriorityRaw = 1
    private let mediumPriorityRaw = 2
    private let highPriorityRaw = 3

    func applyIncomeDelta(
        _ deltaIncome: Double,
        settings: BudgetSettings,
        categoryTargetBaselineByID: inout [UUID: Double],
        allocatedBySubcategoryID: inout [UUID: Double],
        bankBalance: inout Double,
        lastIncomeToBankByCategoryID: inout [UUID: Double],
        lastBankAutoDistributedBySubcategoryID: inout [UUID: Double]
    ) {
        guard deltaIncome > 0.0001 else { return }

        let totalCategoryPercentage = settings.categories.reduce(0.0) {
            $0 + max(0, $1.percentage)
        }
        let categoryPercentageDenominator = max(100, totalCategoryPercentage)
        var incomeAssignedToCategories: Double = 0

        for category in settings.categories {
            let categoryDelta = deltaIncome
                * (max(0, category.percentage) / categoryPercentageDenominator)
            incomeAssignedToCategories += categoryDelta
            categoryTargetBaselineByID[category.id, default: 0] += categoryDelta

            guard categoryDelta > 0 else {
                lastIncomeToBankByCategoryID[category.id] = 0
                continue
            }

            var categoryRemainder = categoryDelta
            let minimumNeeds = minimumDeficitNeeds(
                for: category,
                allocatedBySubcategoryID: allocatedBySubcategoryID
            )
            distributeAmount(
                amount: &categoryRemainder,
                across: minimumNeeds,
                allocatedBySubcategoryID: &allocatedBySubcategoryID
            )

            distributeByPercentageWeights(
                amount: &categoryRemainder,
                category: category,
                allocatedBySubcategoryID: &allocatedBySubcategoryID
            )

            if categoryRemainder > 0.0001 {
                bankBalance += categoryRemainder
            }
            lastIncomeToBankByCategoryID[category.id] = roundToCents(categoryRemainder)
        }

        let incomeWithoutCategory = max(0, deltaIncome - incomeAssignedToCategories)
        if incomeWithoutCategory > 0.0001 {
            bankBalance += incomeWithoutCategory
        }
    }

    func resolveMinimumDeficitsFromBank(
        settings: BudgetSettings,
        allocatedBySubcategoryID: inout [UUID: Double],
        bankBalance: inout Double,
        lastBankAutoDistributedBySubcategoryID: inout [UUID: Double],
        trackAutoDistribution: Bool
    ) {
        guard bankBalance > 0.0001 else { return }

        resolveEmergencyReserveMinimumFromBank(
            settings: settings,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            bankBalance: &bankBalance,
            lastBankAutoDistributedBySubcategoryID: &lastBankAutoDistributedBySubcategoryID,
            trackAutoDistribution: trackAutoDistribution
        )
        guard bankBalance > 0.0001 else { return }

        var remainingBankAmount = bankBalance
        let needs = minimumDeficitNeeds(
            settings: settings,
            allocatedBySubcategoryID: allocatedBySubcategoryID
        )
        guard !needs.isEmpty else { return }

        let highNeeds = needs.filter { $0.priority == highPriorityRaw }
        let mediumNeeds = needs.filter { $0.priority == mediumPriorityRaw }
        let lowNeeds = needs.filter {
            $0.priority != highPriorityRaw
                && $0.priority != mediumPriorityRaw
        }

        var autoDistributedFromBank: [UUID: Double] = [:]

        let onAllocate: ((UUID, Double) -> Void)? = trackAutoDistribution
            ? { subcategoryID, allocated in
                autoDistributedFromBank[subcategoryID, default: 0] += allocated
            }
            : nil

        allocateGroup(
            amount: &remainingBankAmount,
            needs: highNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )
        allocateGroup(
            amount: &remainingBankAmount,
            needs: mediumNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )
        allocateLowGroup(
            amount: &remainingBankAmount,
            needs: lowNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )

        if trackAutoDistribution {
            for (subcategoryID, allocated) in autoDistributedFromBank {
                lastBankAutoDistributedBySubcategoryID[subcategoryID, default: 0] += allocated
            }
        }

        bankBalance = max(0, remainingBankAmount)
    }

    func coverOnboardingDeficitsFromBank(
        settings: BudgetSettings,
        allocatedBySubcategoryID: inout [UUID: Double],
        bankBalance: inout Double,
        distributedBySubcategoryID: inout [UUID: Double]
    ) {
        guard bankBalance > 0.0001 else { return }

        var remainingBankAmount = bankBalance
        var coveredAmounts: [UUID: Double] = [:]
        let onAllocate: (UUID, Double) -> Void = { subcategoryID, amount in
            coveredAmounts[subcategoryID, default: 0] += amount
        }

        let essentialsNeeds = settings.categories
            .filter { $0.type == .essentials }
            .flatMap {
                minimumDeficitNeeds(
                    for: $0,
                    allocatedBySubcategoryID: allocatedBySubcategoryID
                )
            }
        distributeAmount(
            amount: &remainingBankAmount,
            across: essentialsNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )

        let debtNeeds = prioritizedSystemNeeds(
            systemKey: .debt,
            settings: settings,
            allocatedBySubcategoryID: allocatedBySubcategoryID
        )
        distributeAmount(
            amount: &remainingBankAmount,
            across: debtNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )

        let emergencyNeeds = prioritizedSystemNeeds(
            systemKey: .emergencyFund,
            settings: settings,
            allocatedBySubcategoryID: allocatedBySubcategoryID
        )
        distributeAmount(
            amount: &remainingBankAmount,
            across: emergencyNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )

        let excludedIDs = Set(
            settings.categories.flatMap { category in
                category.subcategories.compactMap { subcategory -> UUID? in
                    if category.type == .essentials
                        || subcategory.systemKey == .debt
                        || subcategory.systemKey == .emergencyFund {
                        return subcategory.id
                    }
                    return nil
                }
            }
        )
        let remainingNeeds = minimumDeficitNeeds(
            settings: settings,
            allocatedBySubcategoryID: allocatedBySubcategoryID
        )
        .filter { !excludedIDs.contains($0.subcategoryID) }
        distributeAmount(
            amount: &remainingBankAmount,
            across: remainingNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )

        for (subcategoryID, amount) in coveredAmounts {
            distributedBySubcategoryID[subcategoryID, default: 0] += amount
        }
        bankBalance = max(0, remainingBankAmount)
    }

    func resolveEmergencyReserveMinimumFromBank(
        settings: BudgetSettings,
        allocatedBySubcategoryID: inout [UUID: Double],
        bankBalance: inout Double,
        lastBankAutoDistributedBySubcategoryID: inout [UUID: Double],
        trackAutoDistribution: Bool
    ) {
        guard bankBalance > 0.0001 else { return }
        guard !debtNeedsFunding(in: settings, allocatedBySubcategoryID: allocatedBySubcategoryID) else { return }
        guard let emergencyReserve = emergencyReserveSubcategory(in: settings) else { return }

        let minimumTarget = minimumFloorForRebalance(for: emergencyReserve)
        guard minimumTarget > 0 else { return }

        let allocated = allocatedBySubcategoryID[emergencyReserve.id, default: 0]
        let remaining = max(0, allocated - emergencyReserve.spentAmount)
        let missingAmount = max(0, minimumTarget - remaining)
        guard missingAmount > 0.0001 else { return }

        let transferred = min(bankBalance, missingAmount)
        allocatedBySubcategoryID[emergencyReserve.id, default: 0] += transferred
        bankBalance -= transferred

        if trackAutoDistribution {
            lastBankAutoDistributedBySubcategoryID[emergencyReserve.id, default: 0] += transferred
        }
    }

    func rebalanceForNewSubcategoryMinimum(
        in categoryIndex: Int,
        newSubcategoryID: UUID,
        settings: BudgetSettings,
        allocatedBySubcategoryID: inout [UUID: Double]
    ) {
        guard settings.categories.indices.contains(categoryIndex) else { return }
        let category = settings.categories[categoryIndex]
        guard let newSubcategory = category.subcategories.first(where: { $0.id == newSubcategoryID }) else { return }

        let targetMinimum = minimumFloorForRebalance(for: newSubcategory)
        guard targetMinimum > 0 else { return }

        let newAllocated = allocatedBySubcategoryID[newSubcategoryID, default: 0]
        let newRemaining = max(0, newAllocated - newSubcategory.spentAmount)
        var required = max(0, targetMinimum - newRemaining)
        guard required > 0.0001 else { return }

        let priorityOrder: [Int] = [lowPriorityRaw, mediumPriorityRaw, highPriorityRaw]

        for level in priorityOrder {
            guard required > 0.0001 else { break }

            let donors = category.subcategories.filter { subcategory in
                subcategory.id != newSubcategoryID && normalizedPriorityRaw(for: subcategory.priority) == level
            }
            guard !donors.isEmpty else { continue }

            let donorMovables: [(subcategoryID: UUID, movable: Double)] = donors.compactMap { donor in
                let allocated = allocatedBySubcategoryID[donor.id, default: 0]
                let floor = minimumFloorForRebalance(for: donor)
                let minAllocated = donor.spentAmount + floor
                let movable = max(0, allocated - minAllocated)
                guard movable > 0.0001 else { return nil }
                return (donor.id, movable)
            }

            let totalMovable = donorMovables.reduce(0) { $0 + $1.movable }
            guard totalMovable > 0.0001 else { continue }

            let plannedTake = min(required, totalMovable)
            var taken: Double = 0

            for entry in donorMovables {
                let share = plannedTake * (entry.movable / totalMovable)
                let delta = min(share, entry.movable)
                guard delta > 0 else { continue }

                allocatedBySubcategoryID[entry.subcategoryID, default: 0] -= delta
                taken += delta
            }

            if taken > 0 {
                allocatedBySubcategoryID[newSubcategoryID, default: 0] += taken
                required -= taken
            }
        }
    }

    func moveExcessAboveMaxToBank(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        settings: BudgetSettings,
        allocatedBySubcategoryID: inout [UUID: Double],
        bankBalance: inout Double
    ) {
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }
        guard let subIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }

        let subcategory = settings.categories[categoryIndex].subcategories[subIndex]
        guard let maxLimit = subcategory.maxLimit, maxLimit > 0 else { return }

        let allocated = allocatedBySubcategoryID[subcategoryID, default: 0]
        let remaining = max(0, allocated - subcategory.spentAmount)
        let excess = max(0, remaining - maxLimit)
        guard excess > 0.0001 else { return }

        allocatedBySubcategoryID[subcategoryID] = allocated - excess
        bankBalance += excess
    }

    func minimumFloorForRebalance(for subcategory: Subcategory) -> Double {
        let cap = maxCap(for: subcategory)
        let minLimitTarget = min(max(0, subcategory.minLimit ?? 0), cap)
        guard minLimitTarget > 0 else { return 0 }
        return minLimitTarget
    }

    private func minimumDeficitNeeds(
        settings: BudgetSettings,
        allocatedBySubcategoryID: [UUID: Double]
    ) -> [NeedEntry] {
        settings.categories.flatMap { category in
            minimumDeficitNeeds(
                for: category,
                allocatedBySubcategoryID: allocatedBySubcategoryID
            )
        }
    }

    private func prioritizedSystemNeeds(
        systemKey: SystemSubcategoryKey,
        settings: BudgetSettings,
        allocatedBySubcategoryID: [UUID: Double]
    ) -> [NeedEntry] {
        settings.categories.flatMap { category in
            category.subcategories.compactMap { subcategory in
                guard subcategory.systemKey == systemKey else { return nil }

                let minimumTarget = minimumFloorForRebalance(for: subcategory)
                let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
                let remaining = max(0, allocated - subcategory.spentAmount)
                let need = max(0, minimumTarget - remaining)
                guard need > 0.0001 else { return nil }

                return NeedEntry(
                    subcategoryID: subcategory.id,
                    priority: subcategory.priority,
                    need: need
                )
            }
        }
    }

    private func minimumDeficitNeeds(
        for category: ExpenseCategory,
        allocatedBySubcategoryID: [UUID: Double]
    ) -> [NeedEntry] {
        category.subcategories.compactMap { subcategory in
            let minimumTarget = minimumFloorForRebalance(for: subcategory)
            guard minimumTarget > 0 else { return nil }

            let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
            let remaining = max(0, allocated - subcategory.spentAmount)
            let need = max(0, minimumTarget - remaining)
            guard need > 0.0001 else { return nil }

            return NeedEntry(
                subcategoryID: subcategory.id,
                priority: subcategory.priority,
                need: need
            )
        }
    }

    private func distributeByPercentageWeights(
        amount: inout Double,
        category: ExpenseCategory,
        allocatedBySubcategoryID: inout [UUID: Double]
    ) {
        while amount > 0.0001 {
            let candidates: [WeightedCandidate] = category.subcategories.compactMap { subcategory in
                let weight = max(0, subcategory.percentage)
                guard weight > 0 else { return nil }

                let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
                let remaining = max(0, allocated - subcategory.spentAmount)
                let capacity = max(0, maxCap(for: subcategory) - remaining)
                guard capacity > 0.0001 else { return nil }

                return WeightedCandidate(
                    subcategoryID: subcategory.id,
                    weight: weight,
                    capacity: capacity
                )
            }

            let totalWeight = candidates.reduce(0) { $0 + $1.weight }
            guard totalWeight > 0 else { return }

            let amountAtStart = amount
            var allocatedThisRound: Double = 0

            for candidate in candidates {
                let weightedShare = amountAtStart * (candidate.weight / totalWeight)
                let delta = min(weightedShare, candidate.capacity)
                guard delta > 0 else { continue }

                allocatedBySubcategoryID[candidate.subcategoryID, default: 0] += delta
                allocatedThisRound += delta
            }

            guard allocatedThisRound > 0.0001 else { return }
            amount = max(0, amount - allocatedThisRound)
        }
    }

    private func distributeAmount(
        amount: inout Double,
        across needs: [NeedEntry],
        allocatedBySubcategoryID: inout [UUID: Double],
        onAllocate: ((UUID, Double) -> Void)? = nil
    ) {
        guard amount > 0, !needs.isEmpty else { return }

        let highNeeds = needs.filter { $0.priority == highPriorityRaw }
        let mediumNeeds = needs.filter { $0.priority == mediumPriorityRaw }
        let lowNeeds = needs.filter {
            $0.priority != highPriorityRaw
                && $0.priority != mediumPriorityRaw
        }

        allocateGroup(
            amount: &amount,
            needs: highNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )
        allocateGroup(
            amount: &amount,
            needs: mediumNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )
        allocateLowGroup(
            amount: &amount,
            needs: lowNeeds,
            allocatedBySubcategoryID: &allocatedBySubcategoryID,
            onAllocate: onAllocate
        )
    }

    private func allocateGroup(
        amount: inout Double,
        needs: [NeedEntry],
        allocatedBySubcategoryID: inout [UUID: Double],
        onAllocate: ((UUID, Double) -> Void)? = nil
    ) {
        guard amount > 0, !needs.isEmpty else { return }

        let totalNeed = needs.reduce(0) { $0 + $1.need }
        guard totalNeed > 0 else { return }

        if totalNeed <= amount {
            for need in needs {
                let delta = need.need
                allocatedBySubcategoryID[need.subcategoryID, default: 0] += delta
                onAllocate?(need.subcategoryID, delta)
            }
            amount -= totalNeed
            return
        }

        for need in needs {
            let share = amount * (need.need / totalNeed)
            allocatedBySubcategoryID[need.subcategoryID, default: 0] += share
            onAllocate?(need.subcategoryID, share)
        }
        amount = 0
    }

    private func allocateLowGroup(
        amount: inout Double,
        needs: [NeedEntry],
        allocatedBySubcategoryID: inout [UUID: Double],
        onAllocate: ((UUID, Double) -> Void)? = nil
    ) {
        guard amount > 0, !needs.isEmpty else { return }

        let totalNeed = needs.reduce(0) { $0 + $1.need }
        guard totalNeed > 0 else { return }

        if totalNeed <= amount {
            for need in needs {
                let delta = need.need
                allocatedBySubcategoryID[need.subcategoryID, default: 0] += delta
                onAllocate?(need.subcategoryID, delta)
            }
            amount -= totalNeed
            return
        }

        for need in needs {
            let share = amount * (need.need / totalNeed)
            allocatedBySubcategoryID[need.subcategoryID, default: 0] += share
            onAllocate?(need.subcategoryID, share)
        }
        amount = 0
    }

    private func normalizedPriorityRaw(for rawPriority: Int) -> Int {
        if rawPriority == highPriorityRaw { return highPriorityRaw }
        if rawPriority == mediumPriorityRaw { return mediumPriorityRaw }
        return lowPriorityRaw
    }

    private func emergencyReserveSubcategory(in settings: BudgetSettings) -> Subcategory? {
        settings.categories
            .first(where: { $0.type == .savings })?
            .subcategories
            .first(where: { $0.systemKey == .emergencyFund })
    }

    private func debtNeedsFunding(
        in settings: BudgetSettings,
        allocatedBySubcategoryID: [UUID: Double]
    ) -> Bool {
        guard let debt = settings.categories
            .first(where: { $0.type == .savings })?
            .subcategories
            .first(where: { $0.systemKey == .debt }) else {
            return false
        }

        let minimumTarget = minimumFloorForRebalance(for: debt)
        guard minimumTarget > 0 else { return false }

        let allocated = allocatedBySubcategoryID[debt.id, default: 0]
        let remaining = max(0, allocated - debt.spentAmount)
        return remaining + 0.0001 < minimumTarget
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
}

private struct NeedEntry {
    let subcategoryID: UUID
    let priority: Int
    let need: Double
}

private struct WeightedCandidate {
    let subcategoryID: UUID
    let weight: Double
    let capacity: Double
}
