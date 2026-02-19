import Foundation
import Combine

@MainActor
final class CategoriesViewModel: ObservableObject {
    @Published private(set) var categories: [CategoryAllocation] = []

    private var cancellables = Set<AnyCancellable>()

    init(budgetViewModel: BudgetViewModel) {
        categories = budgetViewModel.distribution.categoryAllocations

        budgetViewModel.$distribution
            .map(\.categoryAllocations)
            .sink { [weak self] allocations in
                self?.categories = allocations
            }
            .store(in: &cancellables)
    }

    func category(for type: ExpenseCategoryType) -> CategoryAllocation? {
        categories.first(where: { $0.type == type })
    }

    func subcategories(for type: ExpenseCategoryType) -> [SubcategoryAllocation] {
        category(for: type)?.subcategoryAllocations ?? []
    }

    func remainingTotal(for type: ExpenseCategoryType) -> Double {
        subcategories(for: type).reduce(0) { $0 + $1.remainingAmount }
    }
}
