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
                    title: "Средний доход в месяц*",
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
                Stepper("Количество взрослых иждивенцев: \(dependentsCount)", value: $dependentsCount, in: 0...12)

                Stepper("Количество иждивенцев стариков: \(elderlyDependentsCount)", value: $elderlyDependentsCount, in: 0...12)

                Stepper("Количество детей до 12 лет: \(childrenCount)", value: $childrenCount, in: 0...12)

                Stepper("Количество домашних животных: \(petsCount)", value: $petsCount, in: 0...12)

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
            VStack(alignment: .leading, spacing: 16) {
                summaryMetrics(preview: preview)

                if !preview.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Предупреждения")
                            .font(.headline)

                        ForEach(preview.warnings, id: \.self) { warning in
                            Text("• \(warning)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(AppTheme.panelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        } else {
            validationText("Не удалось собрать итоговую конфигурацию. Проверьте введенные значения.")
        }
    }

    private func summaryMetrics(preview: StartOnboardingPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Итог")
                .font(.headline)

            metricRow("Стратегия", strategy.title)
            metricRow("Минимальная сумма в месяц для проживания", preview.configuration.monthlyMinimumExcludingEmergency, isCurrency: true)
            metricRow("Базовые расходы на жизнь", preview.configuration.mandatoryLivingMonthly, isCurrency: true)
            metricRow("Величина финансовой подушки", preview.configuration.emergencyTarget, isCurrency: true)
            metricRow("Данная сумма взята из вашего капитала, так как ежемесячного дохода не хватает для покрытия минимальной потребности", preview.configuration.capitalAppliedToMinimums, isCurrency: true)
            metricRow("\"Свободный капитал\" - остаток от вашего капитала после распределения дефицитов", preview.configuration.remainingFreeCapital, isCurrency: true)

            if let months = preview.configuration.freeCapitalCoverageMonths {
                metricRow("Хватит свободного капитала на:", "\(String(format: "%.2f", months)) мес.")
            } else {
                metricRow("Срок проживания в месяцах на свободном капитале", "Не определяется")
            }

            if preview.configuration.totalDeficit > 0.01 {
                metricRow("Дефицит денег для покрытия минимального проживания", preview.configuration.totalDeficit, isCurrency: true, color: .red)
            }
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func metricRow(
        _ title: String,
        _ value: String,
        color: Color = .secondary
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
        }
    }

    private func metricRow(
        _ title: String,
        _ value: Double,
        isCurrency: Bool,
        color: Color = .secondary
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            if isCurrency {
                Text(currency(value))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color)
            } else {
                Text("\(value, specifier: "%.2f")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color)
            }
        }
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

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(budget.type.title)
                    .font(.headline)
                Spacer()
                Text("\(budget.percentage, specifier: "%.0f")%")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("\(currency(budget.monthlyAmount)) в месяц")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Общий базовый процент категории: \(categoryBasePercentage(for: allocation), specifier: "%.2f")%")
                .font(.caption)
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
            _ = withAnimation(.easeInOut(duration: 0.2)) {
                if descriptor.isActive {
                    selectedRecommendationKeys.remove(descriptor.systemKey)
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
                Button("Создать стартовое состояние") {
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
            return "Семья и обязательства"
        case 3:
            return "Выбор стратегии"
        case 4:
            return "Карты потребностей"
        default:
            return "Итоговая конфигурация"
        }
    }

    private var stepDescription: String {
        switch currentStep {
        case 1:
            return "Введи данные для распределения стартового бюджета на потребности."
        case 2:
            return "Состав семьи, дети до 12 лет, старики и дополнительные платежи."
        case 3:
            return "Выбери стратегию своего бюджета."
        case 4:
            return "Проверь финальные карты потребностей."
        default:
            return "Итоговые данные."
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
        return builder.buildPreview(input: resolvedInput)
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
            selectedRecommendationKeys: Array(selectedRecommendationKeys).sorted { $0.rawValue < $1.rawValue }
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
