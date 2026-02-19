import SwiftUI

struct SubcategoryCardView: View {
    let subcategory: SubcategoryAllocation
    let actualPercent: Double
    let currencyCode: String
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
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
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.5, perform: onLongPress)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }
}
