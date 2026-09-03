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

struct DashboardPeriodStatisticsView: View {
    @Binding var period: DashboardStatisticsPeriod
    let statistics: DashboardPeriodStatistics
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Статистика", systemImage: "chart.bar.fill")
                    .font(.headline)

                Spacer()
            }

            Picker("Период", selection: $period) {
                ForEach(DashboardStatisticsPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 9) {
                statisticRow(
                    title: "Остаток",
                    value: currency(statistics.openingBalance),
                    color: .secondary
                )
                statisticRow(
                    title: "Доход",
                    value: currency(statistics.totalIncome),
                    color: AppTheme.positive,
                    titleColor: AppTheme.positive
                )
                statisticRow(
                    title: "Расход",
                    value: currency(statistics.totalExpense),
                    color: AppTheme.negative,
                    titleColor: AppTheme.negative
                )

                Divider()

                statisticRow(
                    title: "Баланс",
                    value: currency(statistics.closingBalance),
                    isEmphasized: true
                )

                if statistics.outstandingDebt > 0.01 {
                    statisticRow(
                        title: "Остаток долга",
                        value: currency(statistics.outstandingDebt),
                        color: AppTheme.warning
                    )
                }

                ForEach(statistics.currencyBalances) { balance in
                    statisticRow(
                        title: "Валютный остаток \(balance.currencyCode)",
                        value: AppCurrencyFormatter.string(
                            balance.amount,
                            currencyCode: balance.currencyCode
                        )
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statisticRow(
        title: String,
        value: String,
        color: Color = .primary,
        titleColor: Color? = nil,
        isEmphasized: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(isEmphasized ? .subheadline.weight(.semibold) : .subheadline)
                .foregroundStyle(isEmphasized ? Color.primary : (titleColor ?? .secondary))

            Spacer(minLength: 8)

            Text(value)
                .font(isEmphasized ? .headline : .subheadline.weight(.medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }
}
