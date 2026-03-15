import SwiftUI

struct CategoryListView: View {
    @ObservedObject var budgetViewModel: BudgetViewModel

    var body: some View {
        List {
            ForEach(budgetViewModel.distribution.categoryAllocations) { category in
                NavigationLink {
                    SubcategoryListView(
                        budgetViewModel: budgetViewModel,
                        categoryType: category.type,
                        currencyCode: budgetViewModel.settings.currencyCode
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.type.title)
                            .font(.headline)

                        Text("Выделено: \(currency(category.allocatedAmount))")
                            .font(.subheadline)

                        let remaining = category.subcategoryAllocations.reduce(0) { $0 + $1.remainingAmount }
                        Text("Остаток: \(currency(remaining))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Категории")
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: budgetViewModel.settings.currencyCode)
    }
}
