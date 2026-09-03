import SwiftUI

struct SubcategoryCardView: View {
    let subcategory: SubcategoryAllocation
    let isDetailSideVisible: Bool
    let currencyCode: String
    let onTap: () -> Void
    let onToggleDetailMode: () -> Void
    let onLongPress: () -> Void

    @State private var suppressSingleTapAfterDoubleTap = false

    private enum CardState {
        case normal
        case negative
    }

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
        .frame(
            maxWidth: .infinity,
            minHeight: 96,
            maxHeight: 96,
            alignment: .topLeading
        )
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                suppressSingleTapAfterDoubleTap = true
                onToggleDetailMode()
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
            titleRow(alignment: .center)
                .padding(.top, 6)

            Spacer(minLength: 4)

            Image(systemName: subcategory.iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 4)

            Text(currencyString(subcategory.remainingAmount))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 6)
        .overlay(alignment: .topTrailing) {
            systemLockBadge
        }
    }

    private var detailSide: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Текущий месяц")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            detailMetricRow(
                title: "+",
                value: currencyString(subcategory.monthlyIncomeDistributionAmount),
                symbolColor: AppTheme.positive,
                valueColor: AppTheme.positive
            )
            detailMetricRow(
                title: "-",
                value: currencyString(subcategory.monthlyExpenseAmount),
                symbolColor: AppTheme.negative,
                valueColor: AppTheme.negative
            )
            detailMetricRow(
                title: "→←",
                value: currencyString(subcategory.monthlyOtherIncomingAmount),
                symbolColor: paleGreen,
                valueColor: paleGreen
            )
            detailMetricRow(
                title: "←→",
                value: currencyString(subcategory.monthlyOtherOutgoingAmount),
                symbolColor: paleRed,
                valueColor: paleRed
            )
            dividerLine
            minimumRow
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var systemLockBadge: some View {
        if subcategory.isRequired {
            Image(systemName: "lock.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(5)
                .background(
                    Circle()
                        .fill(AppTheme.cardBackground.opacity(0.92))
                )
                .padding(5)
                .accessibilityLabel("Обязательная карточка")
        }
    }

    private func titleRow(alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 6) {
            Text(subcategory.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }

    private var state: CardState {
        if rawBalance < -0.01 {
            return .negative
        }

        return .normal
    }

    private var rawBalance: Double {
        subcategory.allocatedAmount - subcategory.spentAmount
    }

    private var paleGreen: Color {
        AppTheme.positive.opacity(0.62)
    }

    private var paleRed: Color {
        AppTheme.negative.opacity(0.62)
    }

    private var statusColor: Color {
        switch state {
        case .normal:
            return .primary
        case .negative:
            return AppTheme.negative
        }
    }

    private var minimumRow: some View {
        Text("мин.: \(formattedAmount(subcategory.minLimit ?? 0))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func detailMetricRow(
        title: String,
        value: String,
        symbolColor: Color = .primary,
        valueColor: Color = .primary
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(symbolColor)
                .frame(width: 20, alignment: .center)
            Spacer(minLength: 4)
            Text(value)
                .foregroundStyle(valueColor)
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func formattedAmount(_ value: Double) -> String {
        String(format: "%.2f", max(0, value)).replacingOccurrences(of: ".00", with: "")
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.35))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private func currencyString(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }
}
