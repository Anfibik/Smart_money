import SwiftUI

struct BankSummaryView: View {
    let bankAvailableAmount: Double
    let lines: [BankAutoDistributionLine]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Банка")
                    .font(.headline)

                Spacer()

                Text(bankAvailableAmount, format: .currency(code: currencyCode))
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(lines) { line in
                Text("\(line.name) - \(line.amount, format: .currency(code: currencyCode))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
