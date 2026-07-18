import SwiftUI

struct StartOnboardingFlowView: View {
    let onComplete: (StartOnboardingConfiguration) -> Void

    @State private var currentStep = 1
    @State private var monthlyIncomeInput = ""
    @State private var capitalInput = ""
    @State private var housingType: SetupHousingType = .rented
    @State private var housingCostInput = ""
    @State private var hasCar = false
    @State private var dependentsCount = 0
    @State private var elderlyDependentsCount = 0
    @State private var childrenCount = 0
    @State private var petsCount = 0
    @State private var hasCredit = false
    @State private var creditPaymentInput = ""
    @State private var strategy: StartStrategyType = .stability
    @State private var expandedCardKeys: Set<String> = []
    @State private var selectedRecommendationKeys: Set<SystemSubcategoryKey> = []
    @State private var coverDeficitsFromFreeCapital = false
    @State private var goalTargetAmountInput = ""
    @State private var isGoalTargetPromptPresented = false

    private let builder = StartOnboardingBuilder()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        stepHeader

                        switch currentStep {
                        case 1:
                            financesStep
                        case 2:
                            familyStep
                        case 3:
                            strategyStep
                        case 4:
                            customCardsStep
                        default:
                            summaryStep
                        }
                    }
                    .padding()
                }

                footer
                    .padding()
                    .background(.thinMaterial)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .navigationTitle("Стартовая настройка")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Сумма цели", isPresented: $isGoalTargetPromptPresented) {
                TextField("Например, 500 000", text: $goalTargetAmountInput)
                    .keyboardType(.decimalPad)

                Button("Отмена", role: .cancel) {
                    goalTargetAmountInput = ""
                }

                Button("Добавить") {
                    guard parsedDouble(goalTargetAmountInput) > 0 else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        _ = selectedRecommendationKeys.insert(.goal)
                    }
                }
                .disabled(parsedDouble(goalTargetAmountInput) <= 0)
            } message: {
                Text("Укажите полную стоимость цели. Эта сумма станет максимумом карточки.")
            }
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Шаг \(currentStep) из 5")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(stepTitle)
                .font(.title2.weight(.semibold))

            Text(stepDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var financesStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldCard {
                inputField(
                    title: "Средний доход за месяц*",
                    text: $monthlyIncomeInput,
                    prompt: "Например, 120 000"
                )

                inputField(
                    title: "Накопленный капитал*",
                    text: $capitalInput,
                    prompt: "Можно отрицательное значение"
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Тип жилья*")
                        .font(.subheadline.weight(.medium))

                    Picker("Тип жилья", selection: $housingType) {
                        ForEach(SetupHousingType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                inputField(
                    title: "\(housingType.costTitle)*",
                    text: $housingCostInput,
                    prompt: "Ежемесячная сумма"
                )
            }

            if !isStepOneValid {
                validationText(stepOneValidationMessage)
            }
        }
    }

    private var familyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldCard {
                Stepper("Взрослые: \(dependentsCount)", value: $dependentsCount, in: 0...12)

                Stepper("Стариков: \(elderlyDependentsCount)", value: $elderlyDependentsCount, in: 0...12)

                Stepper("Дети до 12 лет: \(childrenCount)", value: $childrenCount, in: 0...12)

                Stepper("Домашние животныхе: \(petsCount)", value: $petsCount, in: 0...12)

                Toggle("Есть авто", isOn: $hasCar)

                Toggle("Есть кредит", isOn: $hasCredit)

                if hasCredit {
                    inputField(
                        title: "Ежемесячный платеж по кредиту*",
                        text: $creditPaymentInput,
                        prompt: "Например, 15 000"
                    )
                }
            }

            if !isStepTwoValid {
                validationText(stepTwoValidationMessage)
            }
        }
        .onChange(of: hasCredit) { _, newValue in
            if !newValue {
                creditPaymentInput = ""
            }
        }
    }

    private var customCardsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let preview {
                let descriptors = builder.onboardingCardDescriptors(for: resolvedInput)
                ForEach(preview.configuration.categoryBudgets) { budget in
                    if let allocation = preview.distribution.categoryAllocations.first(where: { $0.type == budget.type }) {
                        onboardingCategorySection(
                            budget: budget,
                            allocation: allocation,
                            descriptors: descriptors.filter { $0.categoryType == budget.type }
                        )
                    }
                }
            } else {
                validationText("Не удалось рассчитать карты потребностей. Проверьте введенные значения.")
            }

        }
    }

    private var strategyStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(StartStrategyType.allCases) { item in
                Button {
                    strategy = item
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: strategy == item ? "largecircle.fill.circle" : "circle")
                            .font(.title3)
                            .foregroundStyle(strategy == item ? .green : .secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(item.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.panelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var summaryStep: some View {
        if let preview = preview {
            VStack(alignment: .leading, spacing: 14) {
                summaryStatusCard(preview: preview)

                if let uncoveredPreview,
                   let coveredPreview,
                   canOfferDeficitCoverage(uncoveredPreview) {
                    deficitCoverageChoiceCard(
                        uncoveredPreview: uncoveredPreview,
                        coveredPreview: coveredPreview
                    )
                }

                monthlyPlanCard(preview: preview)
                capitalPlanCard(preview: preview)
                capitalCoverageCard(preview: preview)

                if !preview.warnings.isEmpty {
                    summaryWarningsCard(preview.warnings)
                }
            }
        } else {
            validationText("Не удалось собрать итоговую конфигурацию. Проверьте введенные значения.")
        }
    }

    private func deficitCoverageChoiceCard(
        uncoveredPreview: StartOnboardingPreview,
        coveredPreview: StartOnboardingPreview
    ) -> some View {
        let available = uncoveredPreview.configuration.remainingFreeCapital
        let essentialsDeficit = categoryDeficit(
            .essentials,
            in: uncoveredPreview
        )
        let wantsDeficit = categoryDeficit(
            .wants,
            in: uncoveredPreview
        )
        let financeCardDeficits = financeDeficitCards(in: uncoveredPreview)
        let projectedCoverage = max(
            0,
            available - coveredPreview.configuration.remainingFreeCapital
        )
        let amountToCover = coverDeficitsFromFreeCapital ? projectedCoverage : 0
        let remaining = coverDeficitsFromFreeCapital
            ? coveredPreview.configuration.remainingFreeCapital
            : available

        return summarySectionCard(
            title: "Покрыть дефициты?",
            systemImage: "arrow.triangle.branch"
        ) {
            Text(
                "Можно направить свободный капитал на незакрытые минимумы: "
                    + "сначала «Основные», затем «Долг», «Подушка» и остальные карты по приоритету."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $coverDeficitsFromFreeCapital.animation(.easeInOut(duration: 0.2))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Покрыть дефициты")
                        .font(.subheadline.weight(.semibold))
                    Text(coverDeficitsFromFreeCapital ? "Включено" : "Выключено")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.green)

            summaryDivider
            Text("Текущие дефициты")
                .font(.subheadline.weight(.semibold))

            summaryValueRow(
                ExpenseCategoryType.essentials.title,
                currency(essentialsDeficit),
                valueColor: deficitValueColor(essentialsDeficit)
            )
            summaryDivider
            summaryValueRow(
                ExpenseCategoryType.wants.title,
                currency(wantsDeficit),
                valueColor: deficitValueColor(wantsDeficit)
            )

            ForEach(financeCardDeficits) { card in
                summaryDivider
                summaryValueRow(
                    card.name,
                    currency(card.deficitAmount),
                    valueColor: deficitValueColor(card.deficitAmount)
                )
            }

            summaryDivider
            summaryValueRow("Свободный капитал", currency(available))
            summaryDivider
            summaryValueRow("Останется свободно", currency(remaining))
            summaryDivider
            summaryValueRow(
                "Будет распределено",
                currency(amountToCover),
                valueColor: coverDeficitsFromFreeCapital ? .green : .secondary,
                isEmphasized: true
            )
        }
    }

    private func categoryDeficit(
        _ categoryType: ExpenseCategoryType,
        in preview: StartOnboardingPreview
    ) -> Double {
        preview.distribution.categoryAllocations
            .first(where: { $0.type == categoryType })?
            .deficitAmount ?? 0
    }

    private func financeDeficitCards(
        in preview: StartOnboardingPreview
    ) -> [SubcategoryAllocation] {
        preview.distribution.categoryAllocations
            .first(where: { $0.type == .savings })?
            .subcategoryAllocations
            .filter { $0.deficitAmount > 0.01 } ?? []
    }

    private func deficitValueColor(_ amount: Double) -> Color {
        amount > 0.01 ? .orange : .secondary
    }

    private func summaryStatusCard(preview: StartOnboardingPreview) -> some View {
        let configuration = preview.configuration
        let difference = monthlyDifference(for: configuration)
        let uncoveredMinimums = max(0, configuration.totalDeficit)
        let statusColor: Color = if uncoveredMinimums > 0.01 {
            .red
        } else if difference < -0.01 {
            .orange
        } else {
            .green
        }
        let statusTitle = if uncoveredMinimums > 0.01 {
            "Не все минимумы обеспечены"
        } else if difference < -0.01 {
            "Ежемесячно не хватает"
        } else {
            "Доход покрывает план"
        }
        let statusAmount = uncoveredMinimums > 0.01
            ? uncoveredMinimums
            : abs(difference)

        return VStack(alignment: .leading, spacing: 12) {
            Label(strategy.title, systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(statusTitle)
                .font(.headline)

            Text(currency(statusAmount))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(statusColor)

            Text(summaryStatusDescription(for: configuration))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor.opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(statusColor.opacity(0.28), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func monthlyPlanCard(preview: StartOnboardingPreview) -> some View {
        let configuration = preview.configuration
        let difference = monthlyDifference(for: configuration)
        let differenceColor: Color = if difference < -0.01 {
            .red
        } else if difference > 0.01 {
            .green
        } else {
            .secondary
        }

        return summarySectionCard(
            title: "Ежемесячный план",
            systemImage: "calendar"
        ) {
            summaryValueRow("Доход", currency(configuration.input.monthlyIncome))
            summaryDivider
            summaryValueRow(
                "Минимальные потребности",
                currency(configuration.monthlyMinimumExcludingEmergency)
            )
            summaryDivider
            summaryValueRow(
                "Разница",
                signedCurrency(difference),
                valueColor: differenceColor,
                isEmphasized: true
            )
        }
    }

    private func capitalPlanCard(preview: StartOnboardingPreview) -> some View {
        let configuration = preview.configuration

        return summarySectionCard(
            title: "Свободный капитал",
            systemImage: "banknote.fill"
        ) {
            summaryValueRow(
                "До покрытия",
                currency(
                    configuration.remainingFreeCapital
                        + configuration.capitalAppliedToMinimums
                )
            )
            summaryDivider
            summaryValueRow(
                "Направлено на дефициты",
                currency(configuration.capitalAppliedToMinimums)
            )
            summaryDivider
            summaryValueRow(
                "Осталось свободно",
                currency(configuration.remainingFreeCapital),
                isEmphasized: true
            )
            summaryDivider
            summaryValueRow(
                "Цель финансовой подушки",
                currency(configuration.emergencyTarget)
            )
        }
    }

    private func capitalCoverageCard(preview: StartOnboardingPreview) -> some View {
        let configuration = preview.configuration
        let monthlyShortfall = max(0, -monthlyDifference(for: configuration))
        let coverageWithIncome = monthlyShortfall > 0.01
            ? configuration.remainingFreeCapital / monthlyShortfall
            : nil

        return summarySectionCard(
            title: "Запас капитала",
            systemImage: "shield.fill"
        ) {
            if let coverageWithIncome {
                summaryValueRow(
                    "С текущим доходом",
                    formattedMonths(coverageWithIncome),
                    valueColor: coverageWithIncome < 6 ? .orange : .green,
                    isEmphasized: true
                )
            } else {
                summaryValueRow(
                    "С текущим доходом",
                    "План покрыт",
                    valueColor: .green,
                    isEmphasized: true
                )
            }

            summaryDivider

            if let monthsWithoutIncome = configuration.freeCapitalCoverageMonths {
                summaryValueRow(
                    "Без дохода",
                    formattedMonths(monthsWithoutIncome)
                )
            } else {
                summaryValueRow("Без дохода", "Не определяется")
            }

            Text("Расчёт предполагает, что текущие расходы и доход не изменятся.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    private func summaryWarningsCard(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Обратите внимание", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)

                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.09))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summarySectionCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryValueRow(
        _ title: String,
        _ value: String,
        valueColor: Color = .primary,
        isEmphasized: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(isEmphasized ? .headline : .subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var summaryDivider: some View {
        Divider()
            .overlay(Color.secondary.opacity(0.12))
    }

    private func monthlyDifference(for configuration: StartOnboardingConfiguration) -> Double {
        configuration.input.monthlyIncome - configuration.monthlyMinimumExcludingEmergency
    }

    private func summaryStatusDescription(
        for configuration: StartOnboardingConfiguration
    ) -> String {
        if configuration.totalDeficit > 0.01 {
            if configuration.coversDeficitsFromFreeCapital {
                return "После покрытия из свободного капитала часть минимальных сумм всё ещё не обеспечена."
            }
            if configuration.remainingFreeCapital > 0.01 {
                return "Часть минимальных сумм не обеспечена. Ниже можно выбрать, использовать ли свободный капитал для покрытия."
            }
            return "После распределения дохода часть минимальных сумм осталась без покрытия."
        }

        let difference = monthlyDifference(for: configuration)
        if difference < -0.01 {
            let minimum = configuration.monthlyMinimumExcludingEmergency
            let coverage = minimum > 0
                ? min(100, configuration.input.monthlyIncome / minimum * 100)
                : 100
            return "Доход покрывает \(String(format: "%.0f", coverage))% выбранного ежемесячного плана."
        }

        return "Ежемесячный доход полностью покрывает выбранный план."
    }

    private func signedCurrency(_ value: Double) -> String {
        if value > 0.005 {
            return "+\(currency(value))"
        }
        if value < -0.005 {
            return "−\(currency(abs(value)))"
        }
        return currency(0)
    }

    private func formattedMonths(_ value: Double) -> String {
        "\(String(format: "%.1f", max(0, value))) мес."
    }

    private func onboardingCategorySection(
        budget: StartCategoryBudget,
        allocation: CategoryAllocation,
        descriptors: [StartSystemCardDescriptor]
    ) -> some View {
        let displayedCards = descriptors.map { descriptor in
            OnboardingDisplayedCard(
                descriptor: descriptor,
                allocation: allocation.subcategoryAllocations.first(where: { $0.systemKey == descriptor.systemKey })
            )
        }
        let activeCards = displayedCards.filter { !$0.descriptor.isRecommended || $0.descriptor.isActive }
        let recommendedCards = displayedCards.filter { $0.descriptor.isRecommended && !$0.descriptor.isActive }
        let totalIncome = preview?.distribution.income ?? 0
        let settledAmount = allocation.allocatedAmount

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(budget.type.title)
                    .font(.headline)
                Spacer()
                Text("\(budget.percentage, specifier: "%.0f")%")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("Зачислено \(currency(settledAmount)) из \(currency(budget.monthlyAmount))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Текущие")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(activeCards) { card in
                    onboardingSubcategoryCard(card, totalIncome: totalIncome)
                }
            }

            if !recommendedCards.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Рекомендуемые")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(recommendedCards) { card in
                        onboardingSubcategoryCard(card, totalIncome: totalIncome)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func onboardingSubcategoryCard(
        _ card: OnboardingDisplayedCard,
        totalIncome: Double
    ) -> some View {
        let descriptor = card.descriptor
        let allocation = card.allocation
        let incomeShare = allocation.map { incomeSharePercent(for: $0, totalIncome: totalIncome) } ?? 0
        let isInactiveRecommendation = descriptor.isRecommended && !descriptor.isActive

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: descriptor.iconName)
                    .frame(width: 24)
                    .foregroundStyle(isInactiveRecommendation ? .secondary : .primary)

                Text(descriptor.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("От дохода: \(percentText(incomeShare))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(currency(allocation?.allocatedAmount ?? 0))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isInactiveRecommendation ? .secondary : .primary)

                Text(descriptor.note ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(isInactiveRecommendation ? 0.6 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            guard descriptor.isRecommended else { return }

            if descriptor.systemKey == .goal, !descriptor.isActive {
                goalTargetAmountInput = ""
                isGoalTargetPromptPresented = true
                return
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                if descriptor.isActive {
                    selectedRecommendationKeys.remove(descriptor.systemKey)
                    if descriptor.systemKey == .goal {
                        goalTargetAmountInput = ""
                    }
                } else {
                    selectedRecommendationKeys.insert(descriptor.systemKey)
                }
            }
        }
    }

    private func onboardingParameterRow(
        _ title: String,
        _ value: String,
        valueColor: Color = .secondary,
        titleFont: Font = .caption,
        valueFont: Font = .caption.weight(.medium)
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(titleFont)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(valueFont)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }

    private var footer: some View {
        HStack {
            if currentStep > 1 {
                Button("Назад") {
                    currentStep -= 1
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep < 5 {
                Button("Далее") {
                    currentStep += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAdvance)
            } else {
                Button("Начать") {
                    if let configuration = preview?.configuration {
                        onComplete(configuration)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(preview == nil)
            }
        }
    }

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding()
            .background(AppTheme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func inputField(
        title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))

            TextField(prompt, text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func infoCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.red)
    }

    private var stepTitle: String {
        switch currentStep {
        case 1:
            return "Финансы и жилье"
        case 2:
            return "Иждивенцы"
        case 3:
            return "Выбор стратегии"
        case 4:
            return "Карты потребностей"
        default:
            return "Ваш финансовый план готов"
        }
    }

    private var stepDescription: String {
        switch currentStep {
        case 1:
            return "Введи данные для распределения стартового бюджета на потребности."
        case 2:
            return "Данные параметры влияют на дополнительные расходы по содержанию иждивенцев не считая Вас"
        case 3:
            return "Выбери стратегию своего бюджета."
        case 4:
            return "Проверь финальные карты потребностей."
        default:
            return "Посмотри, как распределятся доход и стартовый капитал."
        }
    }

    private var isStepOneValid: Bool {
        parsedDouble(monthlyIncomeInput) > 0 && parsedDouble(housingCostInput) > 0
    }

    private var stepOneValidationMessage: String {
        if parsedDouble(monthlyIncomeInput) <= 0 {
            return "Введите доход больше 0."
        }
        if parsedDouble(housingCostInput) <= 0 {
            return "Введите ежемесячную стоимость жилья больше 0."
        }
        return ""
    }

    private var isStepTwoValid: Bool {
        if hasCredit && parsedDouble(creditPaymentInput) <= 0 {
            return false
        }

        return true
    }

    private var stepTwoValidationMessage: String {
        if hasCredit && parsedDouble(creditPaymentInput) <= 0 {
            return "Введите ежемесячный платеж по кредиту."
        }
        return ""
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 1:
            return isStepOneValid
        case 2:
            return isStepTwoValid
        case 3:
            return true
        case 4:
            return true
        default:
            return preview != nil
        }
    }

    private var preview: StartOnboardingPreview? {
        coverDeficitsFromFreeCapital ? coveredPreview : uncoveredPreview
    }

    private var uncoveredPreview: StartOnboardingPreview? {
        guard isStepOneValid, isStepTwoValid else { return nil }
        return builder.buildPreview(
            input: resolvedInput,
            coverDeficitsFromFreeCapital: false
        )
    }

    private var coveredPreview: StartOnboardingPreview? {
        guard isStepOneValid, isStepTwoValid else { return nil }
        return builder.buildPreview(
            input: resolvedInput,
            coverDeficitsFromFreeCapital: true
        )
    }

    private func canOfferDeficitCoverage(_ preview: StartOnboardingPreview) -> Bool {
        preview.configuration.remainingFreeCapital > 0.01
            && preview.configuration.totalDeficit > 0.01
    }

    private var resolvedInput: StartOnboardingInput {
        StartOnboardingInput(
            monthlyIncome: parsedDouble(monthlyIncomeInput),
            capital: parsedDouble(capitalInput),
            housingType: housingType,
            housingCost: parsedDouble(housingCostInput),
            hasCar: hasCar,
            dependentsCount: dependentsCount,
            elderlyDependentsCount: elderlyDependentsCount,
            childrenCount: childrenCount,
            petsCount: petsCount,
            hasCredit: hasCredit,
            creditMonthlyPayment: parsedDouble(creditPaymentInput),
            strategy: strategy,
            customCards: [],
            selectedRecommendationKeys: Array(selectedRecommendationKeys).sorted { $0.rawValue < $1.rawValue },
            goalTargetAmount: parsedDouble(goalTargetAmountInput)
        )
    }

    private func parsedDouble(_ input: String) -> Double {
        let normalized = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: "UAH")
    }

    private func categoryBasePercentage(for allocation: CategoryAllocation) -> Double {
        allocation.subcategoryAllocations.reduce(0) { partialResult, subcategory in
            partialResult + subcategory.basePercentage
        }
    }

    private func currentMinimumAmount(for subcategory: SubcategoryAllocation) -> Double {
        let minimum = max(0, subcategory.minLimit ?? 0)
        return max(0, minimum - max(0, subcategory.deficitAmount))
    }

    private func maxLimitText(for subcategory: SubcategoryAllocation) -> String {
        guard let maxLimit = subcategory.maxLimit, maxLimit > 0 else {
            return "Не задана"
        }
        return currency(maxLimit)
    }

    private func percentText(_ value: Double) -> String {
        "\(String(format: "%.2f", value))%"
    }

    private func incomeSharePercent(
        for subcategory: SubcategoryAllocation,
        totalIncome: Double
    ) -> Double {
        guard totalIncome > 0.0001 else { return 0 }
        return (subcategory.allocatedAmount / totalIncome) * 100.0
    }

    private func onboardingCardExpansionKey(
        categoryType: ExpenseCategoryType,
        subcategory: SubcategoryAllocation
    ) -> String {
        let normalizedName = subcategory.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(categoryType.rawValue)|\(subcategory.isSystem ? "system" : "custom")|\(normalizedName)|\(subcategory.iconName)"
    }

    private func toggleOnboardingCardExpansion(key: String) {
        if expandedCardKeys.contains(key) {
            expandedCardKeys.remove(key)
        } else {
            expandedCardKeys.insert(key)
        }
    }

    private func cardDescription(for subcategory: SubcategoryAllocation) -> String? {
        switch subcategory.name {
        case "Жилье":
            return housingType == .rented
                ? "Аренда, коммунальные, ремонт, клининг..."
                : "Коммунальные, ремонт, клининг..."
        case "Питание":
            return "Продукты, кафе, столовые, фастфуд..."
        case "Здоровье":
            return "Лекарства, витамины, бады, больницы, стоматология, пансионаты, процедуры"
        case "Гигиена":
            return "Парикмахерские, уход за телом и зубами..."
        case "Дети":
            return "Все детские расходы, кроме питания и здоровья"
        case "Транспорт":
            return hasCar ? "Бензин, ТО, ремонт, обслуживание, тюнинг" : "Общественный транспорт, такси"
        case "Животные":
            return "Корм, уход, ветврач"
        case "Шоппинг", "Шопинг":
            return "Торговые центы, одежда, любой вид покупок"
        case "Хобби":
            return "Затраты на любимое дело"
        case "Развлечения", "Досуг":
            return "Театры, прогулки, концерты, клубы..."
        case "Путешествия", "Путешествие":
            return "Поездки, билеты, отпуск"
        case "Подарки":
            return "Праздники, сюрпризы, внимание близким"
        case "Спорт":
            return "Зал, секции, инвентарь"
        case "Подушка":
            return "Финансовая продушка на 6 месяцев проживания"
        case "Долг":
            return "Создается при отрицательном капитале"
        case "Кредит":
            return "Создается при наличии ежемесячного платежа"
        case "Цель":
            return "Крупная цель: квартира, дом, автомобиль или обучение ребёнка"
        default:
            return nil
        }
    }
}

private struct OnboardingDisplayedCard: Identifiable {
    let descriptor: StartSystemCardDescriptor
    let allocation: SubcategoryAllocation?

    var id: String { descriptor.id }
}
