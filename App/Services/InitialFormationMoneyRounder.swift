import Foundation

enum InitialFormationMoneyRounder {
    static func roundAllocations(
        settings: BudgetSettings,
        allocations: inout [UUID: Double]
    ) {
        for category in settings.categories {
            let automaticCards = category.subcategories
                .filter(\.participatesInAutomaticAllocation)
            roundCategoryAllocations(
                subcategories: automaticCards,
                allocations: &allocations
            )

            for subcategory in category.subcategories where !subcategory.participatesInAutomaticAllocation {
                guard let amount = allocations[subcategory.id] else { continue }
                allocations[subcategory.id] = max(0, amount.rounded())
            }
        }
    }

    private static func roundCategoryAllocations(
        subcategories: [Subcategory],
        allocations: inout [UUID: Double]
    ) {
        guard !subcategories.isEmpty else { return }

        let source = subcategories.map { subcategory in
            (
                id: subcategory.id,
                amount: max(0, allocations[subcategory.id, default: 0])
            )
        }
        let targetTotal = source.reduce(0.0) { $0 + $1.amount }.rounded()
        var roundedByID = Dictionary(
            uniqueKeysWithValues: source.map { ($0.id, floor($0.amount)) }
        )
        let flooredTotal = roundedByID.values.reduce(0, +)
        var unitsToAdd = max(0, Int(targetTotal - flooredTotal))

        let remainderOrder = source.sorted { lhs, rhs in
            let lhsRemainder = lhs.amount - floor(lhs.amount)
            let rhsRemainder = rhs.amount - floor(rhs.amount)
            if abs(lhsRemainder - rhsRemainder) > 0.0001 {
                return lhsRemainder > rhsRemainder
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        for item in remainderOrder where unitsToAdd > 0 {
            roundedByID[item.id, default: 0] += 1
            unitsToAdd -= 1
        }

        for item in source {
            allocations[item.id] = roundedByID[item.id, default: 0]
        }
    }
}
