import SwiftUI

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
                analyticsCard
                historyCard
            }
            .padding()
        }
        .background(AppTheme.appBackground.ignoresSafeArea())
        .navigationTitle("Статистика")
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
                    tint: AppTheme.positive,
                    footnote: "\(viewModel.summary.incomeOperationsCount) операций"
                )
                summaryCard(
                    title: "Расходы",
                    value: currency(viewModel.summary.totalExpense),
                    tint: AppTheme.negative,
                    footnote: "\(viewModel.summary.expenseOperationsCount) операций"
                )
                summaryCard(
                    title: "Результат",
                    value: currency(viewModel.summary.netResult),
                    tint: viewModel.summary.netResult >= 0 ? AppTheme.info : AppTheme.warning,
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
                        tint: AppTheme.warning
                    )
                }
            }

            analyticsSection(
                title: "Карточки за период",
                isEmpty: viewModel.summary.expenseSubcategoriesByCategory.isEmpty
            ) {
                ForEach(viewModel.summary.expenseSubcategoriesByCategory) { section in
                    subcategoryStatsSection(section)
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
                                        .fill(viewModel.entryFilter == filter ? AppTheme.accent.opacity(0.18) : AppTheme.cardBackground)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(viewModel.entryFilter == filter ? AppTheme.accent : Color.clear, lineWidth: 1)
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

    private func subcategoryStatsSection(_ section: BudgetSubcategoryStatSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(currency(section.amount)) • \(percentageText(section.share))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            VStack(spacing: 8) {
                ForEach(section.subcategories) { line in
                    statLine(
                        title: line.title,
                        subtitle: percentageText(line.share),
                        amount: line.amount,
                        tint: AppTheme.highlight,
                        iconName: line.iconName
                    )
                }
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
                let width = max(0, geometry.size.width)
                let ratio = normalizedBarRatio(amount: amount)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.cardBackground)
                    Capsule()
                        .fill(tint.opacity(0.75))
                        .frame(width: ratio > 0 ? max(6, width * CGFloat(ratio)) : 0)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func normalizedBarRatio(amount: Double) -> Double {
        guard amount.isFinite, amount > 0 else { return 0 }

        let totalExpense = viewModel.summary.totalExpense
        let denominator = max(amount, totalExpense)
        guard denominator.isFinite, denominator > 0 else { return 0 }

        return min(1, max(0, amount / denominator))
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
        AppCurrencyFormatter.string(value, currencyCode: viewModel.currencyCode)
    }

    private func percentageText(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }

    private func eventAmountText(for event: BudgetHistoryEvent) -> String {
        let prefix: String
        switch event.type {
        case .income, .manualCardDeposit:
            prefix = "+"
        case .expense:
            prefix = "-"
        case .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation, .currencyConversion:
            prefix = ""
        }
        return "\(prefix)\(AppCurrencyFormatter.string(event.amount, currencyCode: event.currencyCode))"
    }

    private func eventColor(for event: BudgetHistoryEvent) -> Color {
        switch event.type {
        case .income, .manualCardDeposit:
            return AppTheme.positive
        case .expense:
            return AppTheme.negative
        case .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation, .currencyConversion:
            return AppTheme.info
        }
    }
}

struct BudgetHistoryView: View {
    @ObservedObject var budgetViewModel: BudgetViewModel
    @State private var pendingEventToRevert: BudgetHistoryEvent?
    @State private var isShowingRevertConfirmation = false
    @State private var isShowingRevertFailure = false

    private var editablePeriodEntries: [BudgetHistoryPresentationEntry] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
            let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)
        else {
            return []
        }

        return BudgetHistoryPresentation.entries(from: budgetViewModel.historyEvents)
            .filter { entry in
                entry.event.createdAt >= yesterdayStart && entry.event.createdAt < tomorrowStart
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if editablePeriodEntries.isEmpty {
                    emptyBlock(text: "За сегодня и вчера операций нет.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(editablePeriodEntries.enumerated()), id: \.element.id) { index, entry in
                            historyRow(for: entry)

                            if index < editablePeriodEntries.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(AppTheme.appBackground.ignoresSafeArea())
        .navigationTitle("История")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Удалить операцию?", isPresented: $isShowingRevertConfirmation) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                guard let event = pendingEventToRevert else { return }
                if !budgetViewModel.revertHistoryEvent(id: event.id) {
                    isShowingRevertFailure = true
                }
                pendingEventToRevert = nil
            }
        } message: {
            Text("Показатели будут возвращены к состоянию без выбранной операции.")
        }
        .alert("Операцию нельзя удалить", isPresented: $isShowingRevertFailure) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text("Для этой записи нет данных отката или связанные карточки уже изменены.")
        }
    }

    private func historyRow(for entry: BudgetHistoryPresentationEntry) -> some View {
        let event = entry.event

        return HStack(spacing: 12) {
            VStack(spacing: 3) {
                Image(systemName: event.displayIconName)
                    .font(.title3)
                    .foregroundStyle(eventColor(for: event))
                    .frame(width: 34, height: 34)
                    .background(eventColor(for: event).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if entry.hasInternalMovements {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.info)
                        .accessibilityLabel("В операции были внутренние перемещения")
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.displayTitle)
                    .font(.subheadline.weight(.semibold))

                if let subtitle = event.displaySubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(event.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(eventAmountText(for: event))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(eventColor(for: event))

            Button(role: .destructive) {
                pendingEventToRevert = event
                isShowingRevertConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(event.canUndo ? AppTheme.negative : Color.secondary)
            .disabled(!event.canUndo)
            .accessibilityLabel("Удалить операцию")
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
        AppCurrencyFormatter.string(value, currencyCode: budgetViewModel.settings.currencyCode)
    }

    private func eventAmountText(for event: BudgetHistoryEvent) -> String {
        let prefix: String
        switch event.type {
        case .income, .manualCardDeposit:
            prefix = "+"
        case .expense:
            prefix = "-"
        case .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation, .currencyConversion:
            prefix = ""
        }
        return "\(prefix)\(AppCurrencyFormatter.string(event.amount, currencyCode: event.currencyCode))"
    }

    private func eventColor(for event: BudgetHistoryEvent) -> Color {
        switch event.type {
        case .income, .manualCardDeposit:
            return AppTheme.positive
        case .expense:
            return AppTheme.negative
        case .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation, .currencyConversion:
            return AppTheme.info
        }
    }
}
