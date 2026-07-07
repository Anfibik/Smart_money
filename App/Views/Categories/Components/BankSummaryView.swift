import SwiftUI

struct BankSummaryView: View {
    let bankAvailableAmount: Double
    let lines: [BankAutoDistributionLine]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Свободный капитал")
                    .font(.headline)

                Spacer()

                Text(currency(bankAvailableAmount))
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(lines) { line in
                Text("\(line.name) - \(currency(line.amount))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }
}
