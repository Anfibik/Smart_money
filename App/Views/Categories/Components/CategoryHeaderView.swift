import SwiftUI

struct CategoryHeaderView: View {
    let category: CategoryAllocation
    let currencyCode: String
    let categoryRemaining: Double
    let categoryMonthlyExpense: Double
    let categoryMonthlyIncome: Double
    let categoryPreviousMonthBalance: Double
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

                Text(currency(categoryRemaining))
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Text("Доход: + \(currency(categoryMonthlyIncome))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.positive)

                Text("Остаток: \(currency(categoryPreviousMonthBalance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Расход: - \(currency(categoryMonthlyExpense))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.negative)
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }
}

struct NoFlashButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
