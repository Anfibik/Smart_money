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
    let isInteractive: Bool
    let onTap: () -> Void

    var body: some View {
        Group {
            if isInteractive {
                Button(action: onTap) {
                    if useCompactLayout {
                        categoryHeader
                    } else {
                        fullHeader
                    }
                }
                .buttonStyle(NoFlashButtonStyle())
            } else {
                fullHeader
            }
        }
    }

    private var categoryHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(category.type.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text("\(category.percentage, specifier: "%.0f")%")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(currency(categoryRemaining))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private var fullHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(category.type.title)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text("\(category.percentage, specifier: "%.0f")%")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(currency(categoryRemaining))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(AppTheme.mutedIcon.opacity(0.55))
                .frame(height: 62)

            Grid(alignment: .trailing, horizontalSpacing: 4, verticalSpacing: 6) {
                metricRow(
                    label: "Остаток:",
                    value: currency(categoryPreviousMonthBalance),
                    color: .secondary
                )
                metricRow(
                    label: "Доход:",
                    value: "+ \(currency(categoryMonthlyIncome))",
                    color: AppTheme.positive
                )
                metricRow(
                    label: "Расход:",
                    value: "- \(currency(categoryMonthlyExpense))",
                    color: AppTheme.negative
                )
            }
            .layoutPriority(1)

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }

    private func metricRow(label: String, value: String, color: Color) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(color)
                .gridColumnAlignment(.trailing)

            Text(value)
                .font(.caption)
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .gridColumnAlignment(.trailing)
        }
    }
}

struct NoFlashButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
