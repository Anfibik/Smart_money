import SwiftUI

struct CategoryExpandedContentView: View {
    let category: CategoryAllocation
    let currencyCode: String
    let canAddSubcategory: Bool
    let onSubcategoryTap: (SubcategoryAllocation) -> Void
    let onSubcategoryLongPress: (SubcategoryAllocation) -> Void
    let onAddTap: () -> Void

    @State private var isDetailModeVisible = false

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(category.subcategoryAllocations) { subcategory in
                    SubcategoryCardView(
                        subcategory: subcategory,
                        isDetailSideVisible: isDetailModeVisible,
                        currencyCode: currencyCode,
                        onTap: { onSubcategoryTap(subcategory) },
                        onToggleDetailMode: { isDetailModeVisible.toggle() },
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
