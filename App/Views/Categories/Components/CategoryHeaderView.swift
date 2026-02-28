import SwiftUI

struct CategoryHeaderView: View {
    let category: CategoryAllocation
    let currencyCode: String
    let categoryRemaining: Double
    let categorySpent: Double
    let categoryLastIncome: Double
    let isExpanded: Bool
    let useCompactLayout: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            if useCompactLayout {
                compactHeader
            } else {
                fullHeader
            }
        }
        .buttonStyle(NoFlashButtonStyle())
    }

    private var compactHeader: some View {
        ZStack(alignment: .trailing) {
            Text(category.type.title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private var fullHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(category.type.title)
                        .font(.headline)

                    Text("\(category.percentage, specifier: "%.0f")%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(categoryRemaining, format: .currency(code: currencyCode))
                    .font(.subheadline.weight(.semibold))

                Text("В банку: \(category.lastIncomeToBankAmount, format: .currency(code: currencyCode))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text("+ \(categoryLastIncome, format: .currency(code: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("- \(categorySpent, format: .currency(code: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Дефицит: -\(category.deficitAmount, format: .currency(code: currencyCode))")
                    .font(.caption)
                    .foregroundColor(category.deficitAmount > 0 ? .red : .secondary)
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }
}

struct NoFlashButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
