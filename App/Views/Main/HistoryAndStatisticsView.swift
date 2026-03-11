import SwiftUI
import Charts

struct HistoryAndStatisticsView: View {
    @StateObject private var viewModel: HistoryAndStatisticsViewModel

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(budgetViewModel: BudgetViewModel) {
        _viewModel = StateObject(
            wrappedValue: HistoryAndStatisticsViewModel(budgetViewModel: budgetViewModel)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                periodControlsCard
                summaryGrid
                timelineCard
                analyticsCard
                historyCard
            }
            .padding()
        }
        .background(AppTheme.appBackground.ignoresSafeArea())
        .navigationTitle("История и статистика")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var periodControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Период", selection: $viewModel.periodMode) {
                ForEach(HistoryPeriodMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch viewModel.periodMode {
            case .month:
                selectionButton(
                    title: "Выбранный месяц",
                    value: viewModel.selectedMonth?.title() ?? "Выберите месяц"
                ) {
                    ForEach(viewModel.availableMonths) { month in
                        Button(month.title()) {
                            viewModel.selectedMonth = month
                        }
                    }
                }

            case .year:
                selectionButton(
                    title: "Выбранный год",
                    value: viewModel.selectedYear.map(String.init) ?? "Выберите год"
                ) {
                    ForEach(viewModel.availableYears, id: \.self) { year in
                        Button(String(year)) {
                            viewModel.selectedYear = year
                        }
                    }
                }

            case .allTime:
                Text("Показываем весь период после последнего полного сброса.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var summaryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Сводка")
                .font(.headline)

            LazyVGrid(columns: summaryColumns, spacing: 12) {
                summaryCard(
                    title: "Доходы",
                    value: currency(viewModel.summary.totalIncome),
                    tint: .green,
                    footnote: "\(viewModel.summary.incomeOperationsCount) операций"
                )
                summaryCard(
                    title: "Расходы",
                    value: currency(viewModel.summary.totalExpense),
                    tint: .red,
                    footnote: "\(viewModel.summary.expenseOperationsCount) операций"
                )
                summaryCard(
                    title: "Результат",
                    value: currency(viewModel.summary.netResult),
                    tint: viewModel.summary.netResult >= 0 ? .blue : .orange,
                    footnote: "Доходы минус расходы"
                )
                summaryCard(
                    title: "Операции",
                    value: "\(viewModel.summary.operationCount)",
                    tint: .secondary,
                    footnote: "Переводов: \(viewModel.summary.transferOperationsCount)"
                )
            }

            Text("Внутренние переводы не входят в финансовую статистику, но отображаются в истории ниже.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Динамика по времени")
                .font(.headline)

            if viewModel.summary.timelineBuckets.isEmpty {
                emptyBlock(text: "За выбранный период нет доходов и расходов.")
            } else {
                HStack(spacing: 12) {
                    legendDot(color: .green, title: "Доходы")
                    legendDot(color: .red, title: "Расходы")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(viewModel.summary.timelineBuckets) { bucket in
                        BarMark(
                            x: .value("Период", bucket.label),
                            y: .value("Сумма", bucket.income)
                        )
                        .position(by: .value("Тип", "Доходы"))
                        .foregroundStyle(Color.green.gradient)

                        BarMark(
                            x: .value("Период", bucket.label),
                            y: .value("Сумма", bucket.expense)
                        )
                        .position(by: .value("Тип", "Расходы"))
                        .foregroundStyle(Color.red.gradient)
                    }
                    .frame(
                        width: max(340, CGFloat(viewModel.summary.timelineBuckets.count) * 34),
                        height: 220
                    )
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var analyticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Аналитика расходов")
                .font(.headline)

            metricsStrip

            analyticsSection(
                title: "По категориям",
                isEmpty: viewModel.summary.expenseByCategory.isEmpty
            ) {
                ForEach(viewModel.summary.expenseByCategory) { line in
                    statLine(
                        title: line.title,
                        subtitle: percentageText(line.share),
                        amount: line.amount,
                        tint: .orange
                    )
                }
            }

            analyticsSection(
                title: "Топ-5 карточек",
                isEmpty: viewModel.summary.topExpenseSubcategories.isEmpty
            ) {
                ForEach(viewModel.summary.topExpenseSubcategories) { line in
                    statLine(
                        title: line.title,
                        subtitle: percentageText(line.share),
                        amount: line.amount,
                        tint: .pink,
                        iconName: line.iconName
                    )
                }
            }
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var metricsStrip: some View {
        HStack(spacing: 12) {
            compactMetric(
                title: "Крупнейший расход",
                value: currency(viewModel.summary.largestExpense)
            )
            compactMetric(
                title: "Средний расход",
                value: currency(viewModel.summary.averageExpense)
            )
        }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(HistoryEntryFilter.allCases) { filter in
                        Button {
                            viewModel.entryFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(viewModel.entryFilter == filter ? Color.accentColor.opacity(0.18) : AppTheme.cardBackground)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(viewModel.entryFilter == filter ? Color.accentColor : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if viewModel.historySections.isEmpty {
                emptyBlock(text: "За выбранный период операций нет.")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.historySections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.subheadline.weight(.semibold))

                            VStack(spacing: 0) {
                                ForEach(Array(section.events.enumerated()), id: \.element.id) { index, event in
                                    historyRow(for: event)

                                    if index < section.events.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func selectionButton<MenuContent: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> MenuContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))

            Menu(content: content) {
                HStack {
                    Text(value)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func summaryCard(title: String, value: String, tint: Color, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func compactMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func legendDot(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func analyticsSection<Content: View>(
        title: String,
        isEmpty: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if isEmpty {
                emptyBlock(text: "Недостаточно данных для отображения.")
            } else {
                VStack(spacing: 10, content: content)
            }
        }
    }

    private func statLine(
        title: String,
        subtitle: String,
        amount: Double,
        tint: Color,
        iconName: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                if let iconName {
                    Image(systemName: iconName)
                        .foregroundStyle(tint)
                        .frame(width: 18)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(currency(amount))
                    .font(.subheadline.weight(.semibold))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.cardBackground)
                    Capsule()
                        .fill(tint.opacity(0.75))
                        .frame(width: max(6, geometry.size.width * CGFloat(min(1, amount == 0 ? 0 : amount / max(amount, viewModel.summary.totalExpense)))))
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func historyRow(for event: BudgetHistoryEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.displayIconName)
                .font(.title3)
                .foregroundStyle(eventColor(for: event))
                .frame(width: 34, height: 34)
                .background(eventColor(for: event).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(event.displayTitle)
                    .font(.subheadline.weight(.semibold))

                if let subtitle = event.displaySubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(event.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(eventAmountText(for: event))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(eventColor(for: event))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func emptyBlock(text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: viewModel.currencyCode))
    }

    private func percentageText(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }

    private func eventAmountText(for event: BudgetHistoryEvent) -> String {
        let prefix: String
        switch event.type {
        case .income:
            prefix = "+"
        case .expense:
            prefix = "-"
        case .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation:
            prefix = ""
        }
        return "\(prefix)\(currency(event.amount))"
    }

    private func eventColor(for event: BudgetHistoryEvent) -> Color {
        switch event.type {
        case .income:
            return .green
        case .expense:
            return .red
        case .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation:
            return .blue
        }
    }
}
