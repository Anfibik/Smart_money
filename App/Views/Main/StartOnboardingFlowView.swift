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
    @State private var selectedRecommendationKeys: Set<SystemSubcategoryKey> = []
    @State private var capitalCoveragePolicy: FreeCapitalCoveragePolicy = .none
    @State private var goalTargetAmountInput = ""
    @State private var isGoalTargetPromptPresented = false
    @State private var hasForeignCurrency = false
    @State private var foreignCurrency: ForeignCurrencyType = .usd
    @State private var foreignCurrencyAmountInput = "0"
    @State private var isForeignCurrencyAmountFocused = false
    @State private var isForeignCurrencyPickerPresented = false

    private let builder = StartOnboardingBuilder()
    private let capitalCoveragePlanner = StartCapitalCoveragePlanner()

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
            .onChange(of: goalTargetAmountInput) { _, newValue in
                let sanitized = CurrencyInputFormatter.sanitized(newValue)
                if goalTargetAmountInput != sanitized {
                    goalTargetAmountInput = sanitized
                }
            }
            .onChange(of: hasForeignCurrency) { _, isEnabled in
                if !isEnabled {
                    foreignCurrencyAmountInput = "0"
                    isForeignCurrencyAmountFocused = false
                }
            }
            .confirmationDialog(
                "Выберите валюту",
                isPresented: $isForeignCurrencyPickerPresented,
                titleVisibility: .visible
            ) {
                ForEach(ForeignCurrencyType.allCases) { currency in
                    Button(currency.displayName) {
                        foreignCurrency = currency
                    }
                }
            }
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Шаг \(currentStep) из 5")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)

                ProgressView(value: Double(currentStep), total: 5)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.accent)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }

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
                    prompt: "Например, 120 000",
                    autoFocus: true
                )

                inputField(
                    title: "Текущий капитал / долг*",
                    text: $capitalInput,
                    prompt: "Например, 50 000 или -20 000",
                    allowsNegative: true,
                    caption: "Отрицательное значение будет учтено как долг."
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

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Наличие валюты", isOn: $hasForeignCurrency)
                        .font(.subheadline.weight(.medium))

                    if hasForeignCurrency {
                        Button {
                            isForeignCurrencyAmountFocused = false
                            isForeignCurrencyPickerPresented = true
                        } label: {
                            HStack(spacing: 8) {
                                Text(foreignCurrency.displayName)
                                    .font(.body.weight(.medium))
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Валюта")

                        inputField(
                            title: "Сумма в \(foreignCurrency.rawValue)",
                            text: $foreignCurrencyAmountInput,
                            prompt: "0",
                            currencyCode: foreignCurrency.rawValue,
                            externalFocus: $isForeignCurrencyAmountFocused
                        )
                    }
                }
            }

        }
    }

    private var familyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldCard {
                Stepper("Взрослые: \(dependentsCount)", value: $dependentsCount, in: 0...12)

                Stepper("Пожилые родственники: \(elderlyDependentsCount)", value: $elderlyDependentsCount, in: 0...12)

                Stepper("Дети до 12 лет: \(childrenCount)", value: $childrenCount, in: 0...12)

                Stepper("Домашние животные: \(petsCount)", value: $petsCount, in: 0...12)

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
                            .foregroundStyle(strategy == item ? AppTheme.accent : .secondary)

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
        if let preview, let capitalCoveragePlan {
            VStack(alignment: .leading, spacing: 14) {
                incomeResultCard(preview: preview)
                freeCapitalResultCard(
                    plan: capitalCoveragePlan,
                    configuration: preview.configuration
                )
                capitalCoverageChoiceCard(plan: capitalCoveragePlan)
                emergencyFundCard(preview: preview)
            }
        } else {
            validationText("Не удалось собрать итоговую конфигурацию. Проверьте введенные значения.")
        }
    }

    private func incomeResultCard(preview: StartOnboardingPreview) -> some View {
        let configuration = preview.configuration
        let difference = monthlyDifference(for: configuration)
        let hasEnoughIncome = difference >= -0.01
        let statusColor = hasEnoughIncome ? AppTheme.positive : AppTheme.negative

        return VStack(alignment: .leading, spacing: 16) {
            Label("Общее финансовое состояние", systemImage: "chart.pie.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(hasEnoughIncome ? "Дохода хватает" : "Дохода не хватает")
                    .font(.title3.weight(.bold))

                Text(currency(abs(difference)))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(statusColor)

                Text(
                    hasEnoughIncome
                        ? "Данная сумма остается после покрытия Вашего прожиточного минимума."
                        : "Столько не хватает ежемесячно для покрытия Вашего прожиточного минимума."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                summaryMetric(
                    title: "Доход",
                    value: currency(configuration.input.monthlyIncome)
                )
                summaryMetric(
                    title: "Нужно минимум",
                    value: currency(configuration.monthlyMinimumExcludingEmergency)
                )
            }
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

    private func capitalCoverageChoiceCard(
        plan: StartCapitalCoveragePlan
    ) -> some View {
        let coversCardDeficits = capitalCoveragePolicy.coversCardDeficits
        let coversEmergencyFund = capitalCoveragePolicy.coversEmergencyFund
        let hasSelectedCoverage = coversCardDeficits || coversEmergencyFund
        let cardDeficitsBinding = Binding(
            get: { capitalCoveragePolicy.coversCardDeficits },
            set: {
                capitalCoveragePolicy = capitalCoveragePolicy
                    .settingCardDeficitsCoverage($0)
            }
        )
        let emergencyFundBinding = Binding(
            get: { capitalCoveragePolicy.coversEmergencyFund },
            set: {
                capitalCoveragePolicy = capitalCoveragePolicy
                    .settingEmergencyFundCoverage($0)
            }
        )

        return summarySectionCard(
            title: "Использовать свободный капитал",
            systemImage: "arrow.triangle.branch"
        ) {
            Toggle(isOn: cardDeficitsBinding.animation(.easeInOut(duration: 0.2))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Покрыть потребности")
                        .font(.subheadline.weight(.semibold))
                    Text(
                        plan.hasCardDeficits
                            ? coverageOptionText(
                                isEnabled: coversCardDeficits,
                                deficit: plan.cardDeficitTotal,
                                coveredAmount: plan.coveredCardDeficitAmount
                            )
                            : "Все минимальные потребности уже покрыты"
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
            .disabled(!plan.hasCardDeficits || plan.availableFreeCapital <= 0.01)

            summaryDivider

            Toggle(isOn: emergencyFundBinding.animation(.easeInOut(duration: 0.2))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Пополнить Подушку")
                        .font(.subheadline.weight(.semibold))
                    Text(
                        plan.hasEmergencyFundDeficit
                            ? coverageOptionText(
                                isEnabled: coversEmergencyFund,
                                deficit: plan.emergencyFundDeficit,
                                coveredAmount: plan.coveredEmergencyFundAmount
                            )
                            : "Цель Подушки уже достигнута"
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(AppTheme.accent)
            .disabled(!plan.hasEmergencyFundDeficit || plan.availableFreeCapital <= 0.01)

            summaryDivider
            summaryValueRow(
                "Будет использовано",
                currency(plan.projectedDistribution),
                valueColor: hasSelectedCoverage ? AppTheme.accent : .secondary,
                isEmphasized: true
            )
        }
    }

    private func emergencyFundCard(preview: StartOnboardingPreview) -> some View {
        let target = max(0, preview.configuration.emergencyTarget)
        let currentAmount = emergencyFundAmount(in: preview)
        let remaining = max(0, target - currentAmount)
        let progress = target > 0 ? min(1, currentAmount / target) : 1

        return summarySectionCard(
            title: "Финансовая Подушка",
            systemImage: "shield.fill"
        ) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Сформировано")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(percentText(progress * 100))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(remaining > 0.01 ? AppTheme.warning : AppTheme.positive)
                }

                ProgressView(value: progress)
                    .tint(remaining > 0.01 ? AppTheme.warning : AppTheme.positive)
            }

            summaryValueRow(
                "Сейчас",
                currency(currentAmount),
                valueColor: currentAmount > 0.01 ? AppTheme.primaryText : .secondary
            )
            summaryDivider
            summaryValueRow("Цель", currency(target))
            summaryDivider
            summaryValueRow(
                "Осталось накопить",
                currency(remaining),
                valueColor: remaining > 0.01 ? AppTheme.warning : AppTheme.positive,
                isEmphasized: true
            )

        }
    }

    private func freeCapitalResultCard(
        plan: StartCapitalCoveragePlan,
        configuration: StartOnboardingConfiguration
    ) -> some View {
        summarySectionCard(
            title: "Свободный капитал",
            systemImage: "banknote.fill"
        ) {
            Text(currency(plan.projectedRemainingFreeCapital))
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(
                    plan.projectedRemainingFreeCapital > 0.01
                        ? AppTheme.positive
                        : AppTheme.secondaryText
                )

            if configuration.initialDistributionShortfall > 0.01 {
                Text(
                    "Стартовое распределение ограничено текущим капиталом: "
                    + "распределится \(currency(configuration.initialDistributionAmount)) "
                    + "из \(currency(configuration.input.monthlyIncome)). "
                    + "Не хватает \(currency(configuration.initialDistributionShortfall))."
                )
                .font(.caption)
                .foregroundStyle(AppTheme.warning)
                .fixedSize(horizontal: false, vertical: true)
            }

        }
    }

    private func coverageOptionText(
        isEnabled: Bool,
        deficit: Double,
        coveredAmount: Double
    ) -> String {
        if isEnabled {
            return "Будет покрыто: \(currency(coveredAmount))"
        }
        return "Не покрыто: \(currency(deficit))"
    }

    private func emergencyFundAmount(
        in preview: StartOnboardingPreview
    ) -> Double {
        preview.distribution.categoryAllocations
            .first(where: { $0.type == .savings })?
            .subcategoryAllocations
            .first(where: { $0.systemKey == .emergencyFund })?
            .remainingAmount ?? 0
    }

    private func summaryMetric(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                Text(cardCurrency(allocation?.allocatedAmount ?? 0, descriptor: descriptor))
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
        HStack(spacing: 12) {
            if currentStep > 1 {
                Button {
                    currentStep -= 1
                } label: {
                    Text("Назад")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.primaryText)
                .background(AppTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.mutedIcon.opacity(0.35), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if currentStep < 5 {
                Button {
                    currentStep += 1
                } label: {
                    primaryFooterLabel("Далее")
                }
                .buttonStyle(.plain)
                .disabled(!canAdvance)
                .foregroundStyle(primaryFooterTextColor(isEnabled: canAdvance))
                .background(primaryFooterBackground(isEnabled: canAdvance))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                let canStart = preview != nil
                Button {
                    if let configuration = preview?.configuration {
                        onComplete(configuration)
                    }
                } label: {
                    primaryFooterLabel("Начать")
                }
                .buttonStyle(.plain)
                .disabled(!canStart)
                .foregroundStyle(primaryFooterTextColor(isEnabled: canStart))
                .background(primaryFooterBackground(isEnabled: canStart))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func primaryFooterLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
    }

    private func primaryFooterBackground(isEnabled: Bool) -> Color {
        isEnabled ? AppTheme.accent : AppTheme.cardBackground
    }

    private func primaryFooterTextColor(isEnabled: Bool) -> Color {
        isEnabled ? AppTheme.primaryText : AppTheme.primaryText.opacity(0.58)
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
        prompt: String,
        currencyCode: String = "UAH",
        allowsNegative: Bool = false,
        autoFocus: Bool = false,
        caption: String? = nil,
        externalFocus: Binding<Bool>? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.primaryText)

            CurrencyInput(
                text: text,
                placeholder: prompt,
                currencyCode: currencyCode,
                allowsNegative: allowsNegative,
                style: .card,
                autoFocus: autoFocus,
                externalFocus: externalFocus
            )

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
            .foregroundStyle(AppTheme.negative)
            .fixedSize(horizontal: false, vertical: true)
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
            return "Введите данные для распределения стартового бюджета на потребности."
        case 2:
            return "Эти параметры влияют на дополнительные расходы семьи."
        case 3:
            return "Выберите стратегию своего бюджета."
        case 4:
            return "Ознакомься с картами потребностей и при необходимости добавь предлагаемые, тапнув по ним."
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
        guard isStepOneValid, isStepTwoValid else { return nil }
        return builder.buildPreview(
            input: resolvedInput,
            capitalCoveragePolicy: capitalCoveragePolicy
        )
    }

    private var uncoveredPreview: StartOnboardingPreview? {
        guard isStepOneValid, isStepTwoValid else { return nil }
        return builder.buildPreview(
            input: resolvedInput,
            capitalCoveragePolicy: .none
        )
    }

    private var capitalCoveragePlan: StartCapitalCoveragePlan? {
        guard let uncoveredPreview, let preview else { return nil }
        return capitalCoveragePlanner.makePlan(
            uncoveredPreview: uncoveredPreview,
            projectedPreview: preview
        )
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
            goalTargetAmount: parsedDouble(goalTargetAmountInput),
            foreignCurrency: foreignCurrency,
            foreignCurrencyAmount: hasForeignCurrency
                ? parsedDouble(foreignCurrencyAmountInput)
                : 0
        )
    }

    private func parsedDouble(_ input: String) -> Double {
        CurrencyInputFormatter.value(from: input)
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: "UAH")
    }

    private func cardCurrency(
        _ value: Double,
        descriptor: StartSystemCardDescriptor
    ) -> String {
        AppCurrencyFormatter.string(
            value,
            currencyCode: descriptor.balanceCurrencyCode ?? "UAH"
        )
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

}

private struct OnboardingDisplayedCard: Identifiable {
    let descriptor: StartSystemCardDescriptor
    let allocation: SubcategoryAllocation?

    var id: String { descriptor.id }
}
