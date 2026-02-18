import Foundation

struct SubcategoryAllocation: Identifiable, Hashable {
    let id: UUID
    let name: String
    let isSystem: Bool
    let basePercentage: Double
    let fixedMinimumPercentage: Double?
    let minLimit: Double?
    let maxLimit: Double?
    let priority: Int
    let percentage: Double
    let allocatedAmount: Double
    let spentAmount: Double
    let remainingAmount: Double
    let deficitAmount: Double
}

struct CategoryAllocation: Identifiable, Hashable {
    let id: UUID
    let type: ExpenseCategoryType
    let percentage: Double
    let allocatedAmount: Double
    let lastIncomeToBankAmount: Double
    let subcategoryAllocations: [SubcategoryAllocation]
    let deficitAmount: Double
}

struct BankAutoDistributionLine: Identifiable, Hashable {
    let id: UUID
    let name: String
    let amount: Double
}

struct BudgetDistribution: Hashable {
    let income: Double
    let categoryAllocations: [CategoryAllocation]
    let bankAmount: Double
    let lastBankAutoDistributions: [BankAutoDistributionLine]
}

final class BudgetService {
    func distribute(income: Double, settings: BudgetSettings) -> BudgetDistribution {
        var categoryWorks: [CategoryWork] = []
        var bankAmount: Double = 0

        for category in settings.categories {
            let categoryAmount = income * (category.percentage / 100.0)
            let result = allocateCategory(
                categoryAmount: categoryAmount,
                subcategories: category.subcategories
            )

            bankAmount += max(0, result.unallocatedAmount)

            categoryWorks.append(
                CategoryWork(
                    id: category.id,
                    type: category.type,
                    percentage: category.percentage,
                    categoryAmount: categoryAmount,
                    rules: result.rules,
                    allocatedByID: result.allocatedByID
                )
            )
        }

        // Global bank: first pass forms surplus, second pass covers minimum deficits by priority.
        spendBankOnDeficits(categoryWorks: &categoryWorks, bankAmount: &bankAmount)

        let categoryAllocations = categoryWorks.map { work in
            let ordered = prioritizedRules(work.rules)
            let roundedAllocatedByID = roundedCents(
                exactByID: work.allocatedByID,
                ruleOrder: ordered,
                totalTarget: work.allocatedByID.values.reduce(0, +)
            )

            let subcategoryAllocations = work.rules.map { rule in
                let allocated = roundedAllocatedByID[rule.subcategory.id] ?? 0
                let remainingAmount = max(0, allocated - rule.subcategory.spentAmount)
                let deficit = max(0, rule.minimumTarget - allocated)

                return SubcategoryAllocation(
                    id: rule.subcategory.id,
                    name: rule.subcategory.name,
                    isSystem: rule.subcategory.isSystem,
                    basePercentage: rule.subcategory.percentage,
                    fixedMinimumPercentage: rule.subcategory.fixedMinimumPercentage,
                    minLimit: rule.subcategory.minLimit,
                    maxLimit: rule.subcategory.maxLimit,
                    priority: rule.subcategory.priority,
                    percentage: work.categoryAmount > 0 ? (allocated / work.categoryAmount) * 100.0 : 0,
                    allocatedAmount: roundToCents(allocated),
                    spentAmount: rule.subcategory.spentAmount,
                    remainingAmount: roundToCents(remainingAmount),
                    deficitAmount: roundToCents(deficit)
                )
            }

            let categoryDeficit = subcategoryAllocations.reduce(0) { $0 + $1.deficitAmount }

            return CategoryAllocation(
                id: work.id,
                type: work.type,
                percentage: work.percentage,
                allocatedAmount: roundToCents(work.categoryAmount),
                lastIncomeToBankAmount: 0,
                subcategoryAllocations: subcategoryAllocations,
                deficitAmount: roundToCents(categoryDeficit)
            )
        }

        return BudgetDistribution(
            income: income,
            categoryAllocations: categoryAllocations,
            bankAmount: roundToCents(bankAmount),
            lastBankAutoDistributions: []
        )
    }

    private func allocateCategory(
        categoryAmount: Double,
        subcategories: [Subcategory]
    ) -> (rules: [AllocationRule], allocatedByID: [UUID: Double], unallocatedAmount: Double) {
        guard !subcategories.isEmpty else {
            return ([], [:], categoryAmount)
        }

        let rules = subcategories.map { sub -> AllocationRule in
            let maxCap = maxCap(for: sub)
            let minAmount = min(max(0, sub.minLimit ?? 0), maxCap)
            let minPercentAmount = min(categoryAmount * (max(0, sub.fixedMinimumPercentage ?? 0) / 100.0), maxCap)
            let basePercentAmount = min(categoryAmount * (max(0, sub.percentage) / 100.0), maxCap)

            let minimumTarget: Double = {
                if minAmount > 0 { return minAmount }
                if minPercentAmount > 0 { return minPercentAmount }
                return basePercentAmount
            }()

            return AllocationRule(
                subcategory: sub,
                maxCap: maxCap,
                minAmountTarget: minAmount,
                minPercentTarget: minPercentAmount,
                basePercentTarget: basePercentAmount,
                minimumTarget: minimumTarget
            )
        }

        var allocatedByID = Dictionary(uniqueKeysWithValues: rules.map { ($0.subcategory.id, 0.0) })
        var remaining = categoryAmount

        let ordered = prioritizedRules(rules)

        // Stage 1: min sum
        runAllocationStage(
            ordered: ordered,
            allocatedByID: &allocatedByID,
            remaining: &remaining
        ) { rule, current in
            max(0, rule.minAmountTarget - current)
        }

        // Stage 2: min percent
        if remaining > 0 {
            runAllocationStage(
                ordered: ordered,
                allocatedByID: &allocatedByID,
                remaining: &remaining
            ) { rule, current in
                max(0, rule.minPercentTarget - current)
            }
        }

        // Stage 3: base percent
        if remaining > 0 {
            runAllocationStage(
                ordered: ordered,
                allocatedByID: &allocatedByID,
                remaining: &remaining
            ) { rule, current in
                max(0, rule.basePercentTarget - current)
            }
        }

        // Stage 4: max sum cap
        if !rules.isEmpty {
            for rule in rules {
                let id = rule.subcategory.id
                guard let current = allocatedByID[id] else { continue }
                if current > rule.maxCap {
                    let extra = current - rule.maxCap
                    allocatedByID[id] = rule.maxCap
                    remaining += extra
                }
            }
        }

        let usedAmount = allocatedByID.values.reduce(0, +)
        let unallocated = max(0, categoryAmount - usedAmount)
        return (rules, allocatedByID, roundToCents(unallocated))
    }

    private func runAllocationStage(
        ordered: PrioritizedRules,
        allocatedByID: inout [UUID: Double],
        remaining: inout Double,
        requirement: (AllocationRule, Double) -> Double
    ) {
        guard remaining > 0 else { return }

        if let high = ordered.high {
            allocateSingle(
                rule: high,
                allocatedByID: &allocatedByID,
                remaining: &remaining,
                requirement: requirement
            )
            if remaining <= 0 { return }
        }

        if let medium = ordered.medium {
            allocateSingle(
                rule: medium,
                allocatedByID: &allocatedByID,
                remaining: &remaining,
                requirement: requirement
            )
            if remaining <= 0 { return }
        }

        allocateLowGroup(
            rules: ordered.low,
            allocatedByID: &allocatedByID,
            remaining: &remaining,
            requirement: requirement
        )
    }

    private func allocateSingle(
        rule: AllocationRule,
        allocatedByID: inout [UUID: Double],
        remaining: inout Double,
        requirement: (AllocationRule, Double) -> Double
    ) {
        guard remaining > 0 else { return }

        let id = rule.subcategory.id
        let current = allocatedByID[id] ?? 0
        let needed = requirement(rule, current)
        guard needed > 0 else { return }

        let delta = min(needed, remaining)
        allocatedByID[id] = current + delta
        remaining -= delta
    }

    private func allocateLowGroup(
        rules: [AllocationRule],
        allocatedByID: inout [UUID: Double],
        remaining: inout Double,
        requirement: (AllocationRule, Double) -> Double
    ) {
        guard remaining > 0, !rules.isEmpty else { return }

        let needs = rules.map { rule -> (rule: AllocationRule, need: Double) in
            let current = allocatedByID[rule.subcategory.id] ?? 0
            return (rule, max(0, requirement(rule, current)))
        }.filter { $0.need > 0 }

        guard !needs.isEmpty else { return }

        let totalNeed = needs.reduce(0) { $0 + $1.need }
        if totalNeed <= remaining {
            for item in needs {
                let id = item.rule.subcategory.id
                allocatedByID[id] = (allocatedByID[id] ?? 0) + item.need
            }
            remaining -= totalNeed
            return
        }

        // Shortage case for low priority: same shortage ratio for all lows.
        for item in needs {
            let share = remaining * (item.need / totalNeed)
            let id = item.rule.subcategory.id
            allocatedByID[id] = (allocatedByID[id] ?? 0) + share
        }
        remaining = 0
    }

    private func spendBankOnDeficits(categoryWorks: inout [CategoryWork], bankAmount: inout Double) {
        guard bankAmount > 0 else { return }

        let highEntries = deficitEntries(categoryWorks: categoryWorks, priority: SubcategoryPriorityLevel.high.rawValue)
        allocateBank(by: highEntries, categoryWorks: &categoryWorks, bankAmount: &bankAmount)
        guard bankAmount > 0 else { return }

        let mediumEntries = deficitEntries(categoryWorks: categoryWorks, priority: SubcategoryPriorityLevel.medium.rawValue)
        allocateBank(by: mediumEntries, categoryWorks: &categoryWorks, bankAmount: &bankAmount)
        guard bankAmount > 0 else { return }

        let lowEntries = deficitEntries(categoryWorks: categoryWorks, priority: nil)
        allocateBank(by: lowEntries, categoryWorks: &categoryWorks, bankAmount: &bankAmount)
    }

    private func deficitEntries(categoryWorks: [CategoryWork], priority: Int?) -> [DeficitEntry] {
        var entries: [DeficitEntry] = []

        for categoryIndex in categoryWorks.indices {
            let work = categoryWorks[categoryIndex]
            for rule in work.rules {
                let isMatchingPriority: Bool
                if let priority {
                    isMatchingPriority = rule.subcategory.priority == priority
                } else {
                    isMatchingPriority = rule.subcategory.priority != SubcategoryPriorityLevel.high.rawValue
                        && rule.subcategory.priority != SubcategoryPriorityLevel.medium.rawValue
                }

                guard isMatchingPriority else { continue }

                let current = work.allocatedByID[rule.subcategory.id] ?? 0
                let deficit = max(0, rule.minimumTarget - current)
                guard deficit > 0 else { continue }

                entries.append(
                    DeficitEntry(
                        categoryIndex: categoryIndex,
                        subcategoryID: rule.subcategory.id,
                        deficit: deficit
                    )
                )
            }
        }

        return entries
    }

    private func allocateBank(
        by entries: [DeficitEntry],
        categoryWorks: inout [CategoryWork],
        bankAmount: inout Double
    ) {
        guard bankAmount > 0, !entries.isEmpty else { return }

        let totalDeficit = entries.reduce(0) { $0 + $1.deficit }
        guard totalDeficit > 0 else { return }

        let ratio = min(1, bankAmount / totalDeficit)
        var consumed: Double = 0

        for entry in entries {
            let delta = entry.deficit * ratio
            guard delta > 0 else { continue }
            categoryWorks[entry.categoryIndex].allocatedByID[entry.subcategoryID, default: 0] += delta
            consumed += delta
        }

        bankAmount = max(0, bankAmount - consumed)
    }

    private func prioritizedRules(_ rules: [AllocationRule]) -> PrioritizedRules {
        let high = rules.first(where: { $0.subcategory.priority == SubcategoryPriorityLevel.high.rawValue })
        let medium = rules.first(where: {
            $0.subcategory.priority == SubcategoryPriorityLevel.medium.rawValue
            && $0.subcategory.id != high?.subcategory.id
        })

        let low = rules.filter { rule in
            rule.subcategory.id != high?.subcategory.id
            && rule.subcategory.id != medium?.subcategory.id
        }

        return PrioritizedRules(high: high, medium: medium, low: low)
    }

    private func roundedCents(
        exactByID: [UUID: Double],
        ruleOrder: PrioritizedRules,
        totalTarget: Double
    ) -> [UUID: Double] {
        var rounded = exactByID.mapValues { value in
            floor(max(0, value) * 100.0) / 100.0
        }

        let roundedTotal = rounded.values.reduce(0, +)
        var centsToDistribute = Int(round((roundToCents(totalTarget) - roundToCents(roundedTotal)) * 100))
        guard centsToDistribute > 0 else { return rounded }

        var order: [UUID] = []
        if let high = ruleOrder.high { order.append(high.subcategory.id) }
        if let medium = ruleOrder.medium { order.append(medium.subcategory.id) }
        order.append(contentsOf: ruleOrder.low.map { $0.subcategory.id })

        guard !order.isEmpty else { return rounded }

        var idx = 0
        while centsToDistribute > 0 {
            let id = order[idx % order.count]
            rounded[id, default: 0] += 0.01
            centsToDistribute -= 1
            idx += 1
        }

        return rounded
    }

    private func roundToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private func maxCap(for subcategory: Subcategory) -> Double {
        guard let maxLimit = subcategory.maxLimit, maxLimit > 0 else {
            return .greatestFiniteMagnitude
        }
        return maxLimit
    }
}

private struct AllocationRule {
    let subcategory: Subcategory
    let maxCap: Double
    let minAmountTarget: Double
    let minPercentTarget: Double
    let basePercentTarget: Double
    let minimumTarget: Double
}

private struct PrioritizedRules {
    let high: AllocationRule?
    let medium: AllocationRule?
    let low: [AllocationRule]
}

private struct CategoryWork {
    let id: UUID
    let type: ExpenseCategoryType
    let percentage: Double
    let categoryAmount: Double
    let rules: [AllocationRule]
    var allocatedByID: [UUID: Double]
}

private struct DeficitEntry {
    let categoryIndex: Int
    let subcategoryID: UUID
    let deficit: Double
}
