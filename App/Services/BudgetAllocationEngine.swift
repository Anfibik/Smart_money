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
        for category in settings.categories {
            var movedToBankForCategory: Double = 0
            let categoryDelta = deltaIncome * (category.percentage / 100.0)
            guard categoryDelta > 0 else {
                lastIncomeToBankByCategoryID[category.id] = 0
                continue
            }

            categoryTargetBaselineByID[category.id, default: 0] += categoryDelta
            let targetCategoryAmount = max(
                categoryTargetBaselineByID[category.id, default: 0],
                categoryCurrentAllocated(for: category, allocatedBySubcategoryID: allocatedBySubcategoryID)
            )

            let unmetBefore = unmetNeeds(
                for: category,
                targetCategoryAmount: targetCategoryAmount,
                stage: .basePercent,
                allocatedBySubcategoryID: allocatedBySubcategoryID
            )

            guard !unmetBefore.isEmpty else {
                bankBalance += categoryDelta
                movedToBankForCategory += categoryDelta
                lastIncomeToBankByCategoryID[category.id] = roundToCents(movedToBankForCategory)
                continue
            }

            var incomePart = categoryDelta
            distributeAcrossStages(
                amount: &incomePart,
                category: category,
                targetCategoryAmount: targetCategoryAmount,
                allocatedBySubcategoryID: &allocatedBySubcategoryID
            )

            if incomePart > 0 {
                bankBalance += incomePart
                movedToBankForCategory += incomePart
            }
            lastIncomeToBankByCategoryID[category.id] = roundToCents(movedToBankForCategory)
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
    }

    private func distributeAcrossStages(
        amount: inout Double,
        category: ExpenseCategory,
        targetCategoryAmount: Double,
        allocatedBySubcategoryID: inout [UUID: Double],
        onAllocate: ((UUID, Double) -> Void)? = nil
    ) {
        for stage in AllocationStage.allCases {
            guard amount > 0 else { break }
            let stageNeeds = unmetNeeds(
                for: category,
                targetCategoryAmount: targetCategoryAmount,
                stage: stage,
                allocatedBySubcategoryID: allocatedBySubcategoryID
            )
            distributeAmount(
                amount: &amount,
                across: stageNeeds,
                allocatedBySubcategoryID: &allocatedBySubcategoryID,
                onAllocate: onAllocate
            )
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

    private func unmetNeeds(
        for category: ExpenseCategory,
        targetCategoryAmount: Double,
        stage: AllocationStage,
        allocatedBySubcategoryID: [UUID: Double]
    ) -> [NeedEntry] {
        category.subcategories.compactMap { subcategory in
            let allocated = allocatedBySubcategoryID[subcategory.id, default: 0]
            let remaining = max(0, allocated - subcategory.spentAmount)
            let target = stageTarget(
                for: subcategory,
                targetCategoryAmount: targetCategoryAmount,
                stage: stage
            )
            let need = max(0, target - remaining)

            guard need > 0.0001 else { return nil }
            return NeedEntry(subcategoryID: subcategory.id, priority: subcategory.priority, need: need)
        }
    }

    private func stageTarget(
        for subcategory: Subcategory,
        targetCategoryAmount: Double,
        stage: AllocationStage
    ) -> Double {
        let cap = maxCap(for: subcategory)

        let minLimitTarget = min(max(0, subcategory.minLimit ?? 0), cap)

        let basePercentTarget = min(
            targetCategoryAmount * (max(0, subcategory.percentage) / 100.0),
            cap
        )

        switch stage {
        case .minLimit:
            return minLimitTarget
        case .basePercent:
            return max(minLimitTarget, basePercentTarget)
        }
    }

    private func categoryCurrentAllocated(
        for category: ExpenseCategory,
        allocatedBySubcategoryID: [UUID: Double]
    ) -> Double {
        category.subcategories.reduce(0) { partialResult, subcategory in
            partialResult + allocatedBySubcategoryID[subcategory.id, default: 0]
        }
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

private enum AllocationStage: CaseIterable {
    case minLimit
    case basePercent
}
