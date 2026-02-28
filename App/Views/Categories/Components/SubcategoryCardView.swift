import SwiftUI

struct SubcategoryCardView: View {
    let subcategory: SubcategoryAllocation
    let actualPercent: Double
    let currencyCode: String
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isDetailSideVisible = false
    @State private var suppressSingleTapAfterDoubleTap = false

    var body: some View {
        ZStack {
            compactSide
                .opacity(isDetailSideVisible ? 0 : 1)

            detailSide
                .opacity(isDetailSideVisible ? 1 : 0)
                .rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .rotation3DEffect(
            .degrees(isDetailSideVisible ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
        .animation(.easeInOut(duration: 0.28), value: isDetailSideVisible)
        .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .topLeading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                suppressSingleTapAfterDoubleTap = true
                isDetailSideVisible.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    suppressSingleTapAfterDoubleTap = false
                }
            }
        )
        .onTapGesture {
            guard !suppressSingleTapAfterDoubleTap else { return }
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, perform: onLongPress)
    }

    private var compactSide: some View {
        VStack(spacing: 0) {
            Text(subcategory.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)

            Spacer(minLength: 4)

            Image(systemName: subcategory.iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 4)

            Text(subcategory.remainingAmount, format: .currency(code: currencyCode))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 6)
    }

    private var detailSide: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text(subcategory.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)

                Spacer(minLength: 4)

                Text("\(formattedPercent(subcategory.basePercentage))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text("Текущий: \(actualPercent, specifier: "%.1f")%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subcategory.remainingAmount, format: .currency(code: currencyCode))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Дефицит: -\(subcategory.deficitAmount, format: .currency(code: currencyCode))")
                .font(.caption2)
                .foregroundColor(subcategory.deficitAmount > 0 ? .red : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }
}
