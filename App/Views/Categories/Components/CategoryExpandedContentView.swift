import SwiftUI

struct CategoryExpandedContentView: View {
    let category: CategoryAllocation
    let currencyCode: String
    let canAddSubcategory: Bool
    let onSubcategoryTap: (SubcategoryAllocation) -> Void
    let onSubcategoryLongPress: (SubcategoryAllocation) -> Void
    let onAddTap: () -> Void

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        let categorySpent = category.subcategoryAllocations.reduce(0) { $0 + $1.spentAmount }
        let categoryRemaining = category.subcategoryAllocations.reduce(0) { $0 + $1.remainingAmount }
        let totalCurrentCategoryAmount = category.subcategoryAllocations.reduce(0.0) { partialResult, subcategory in
            partialResult + subcategory.remainingAmount
        }

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Текущая: \(categoryRemaining, format: .currency(code: currencyCode))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text("Расход: - \(categorySpent, format: .currency(code: currencyCode))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(category.subcategoryAllocations) { subcategory in
                    let actualPercent = totalCurrentCategoryAmount > 0
                        ? (subcategory.remainingAmount / totalCurrentCategoryAmount) * 100.0
                        : 0

                    SubcategoryCardView(
                        subcategory: subcategory,
                        actualPercent: actualPercent,
                        currencyCode: currencyCode,
                        onTap: { onSubcategoryTap(subcategory) },
                        onLongPress: { onSubcategoryLongPress(subcategory) }
                    )
                }

                Button(action: onAddTap) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(canAddSubcategory ? AppTheme.cardBackground : AppTheme.disabledCardBackground)
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96)
                }
                .buttonStyle(.plain)
                .disabled(!canAddSubcategory)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.top, 6)
        .clipped()
    }
}
