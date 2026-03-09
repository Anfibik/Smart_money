import SwiftUI

struct StartOnboardingFlowView: View {
    let onComplete: (StartOnboardingConfiguration) -> Void

    @State private var currentStep = 1
    @State private var monthlyIncomeInput = ""
    @State private var capitalInput = ""
    @State private var housingType: SetupHousingType = .rented
    @State private var housingCostInput = ""
    @State private var carsCount = 0
    @State private var dependentsCount = 0
    @State private var childrenCount = 0
    @State private var hasCredit = false
    @State private var creditPaymentInput = ""
    @State private var strategy: StartStrategyType = .stability
    @State private var customCards: [EditableCustomCard] = []

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
                            customCardsStep
                        case 4:
                            strategyStep
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
                    title: "Средний месячный доход за год",
                    text: $monthlyIncomeInput,
                    prompt: "Например, 120 000"
                )

                inputField(
                    title: "Текущий капитал в наличных*",
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

                Stepper("Количество авто: \(carsCount)", value: $carsCount, in: 0...10)
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

                Stepper("Количество детей до 16 лет: \(childrenCount)", value: $childrenCount, in: 0...12)

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
            infoCard(
                title: "Системные карты",
                text: "Они создаются автоматически и не редактируются на этом этапе. Ниже можно добавить только пользовательские карты. Итоговые суммы и проценты будут посчитаны после выбора стратегии."
            )

            ForEach(ExpenseCategoryType.allCases, id: \.self) { categoryType in
                VStack(alignment: .leading, spacing: 12) {
                    Text(categoryType.title)
                        .font(.headline)

                    systemCardsBlock(for: categoryType)
                    customCardsBlock(for: categoryType)
                }
            }

            if !areCustomCardsValid {
                validationText("Заполните название и минимальную сумму у всех пользовательских карт. Процент можно оставить пустым.")
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

                ForEach(preview.configuration.categoryBudgets) { budget in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(budget.type.title)
                                .font(.headline)
                            Spacer()
                            Text("\(budget.percentage, specifier: "%.0f")%")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Text("\(budget.monthlyAmount, format: .currency(code: "UAH")) в месяц")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let allocation = preview.distribution.categoryAllocations.first(where: { $0.type == budget.type }) {
                            ForEach(allocation.subcategoryAllocations) { subcategory in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: subcategory.iconName)
                                        .frame(width: 24)
                                        .foregroundStyle(subcategory.isSystem ? .primary : .secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(subcategory.name)
                                            .font(.subheadline.weight(.medium))

                                        Text("Мин.: \((subcategory.minLimit ?? 0), format: .currency(code: "UAH"))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text("Базовый процент: \(subcategory.basePercentage, specifier: "%.2f")%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if subcategory.deficitAmount > 0.01 {
                                            Text("Дефицит: \(subcategory.deficitAmount, format: .currency(code: "UAH"))")
                                                .font(.caption)
                                                .foregroundStyle(.red)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
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
            metricRow("Обязательные минимумы в месяц", preview.configuration.monthlyMinimumExcludingEmergency, isCurrency: true)
            metricRow("Базовые расходы на жизнь", preview.configuration.mandatoryLivingMonthly, isCurrency: true)
            metricRow("Цель подушки", preview.configuration.emergencyTarget, isCurrency: true)
            metricRow("Стартовый капитал, ушедший в минимумы", preview.configuration.capitalAppliedToMinimums, isCurrency: true)
            metricRow("Свободный капитал после запуска", preview.configuration.remainingFreeCapital, isCurrency: true)

            if let months = preview.configuration.freeCapitalCoverageMonths {
                metricRow("Хватит без подушки", "\(String(format: "%.2f", months)) мес.")
            } else {
                metricRow("Хватит без подушки", "Не определяется")
            }

            if preview.configuration.totalDeficit > 0.01 {
                metricRow("Остаточный дефицит", preview.configuration.totalDeficit, isCurrency: true, color: .red)
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
                Text(value, format: .currency(code: "UAH"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color)
            } else {
                Text("\(value, specifier: "%.2f")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(color)
            }
        }
    }

    private func systemCardsBlock(for categoryType: ExpenseCategoryType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(systemCards(for: categoryType)) { card in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: card.iconName)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.name)
                            .font(.subheadline.weight(.medium))
                        if let note = card.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(AppTheme.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func customCardsBlock(for categoryType: ExpenseCategoryType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let indices = customCardIndices(for: categoryType)

            if indices.isEmpty {
                Text("Пользовательских карт пока нет.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(indices, id: \.self) { index in
                    customCardEditor(index: index)
                }
            }

            Button {
                appendCustomCard(to: categoryType)
            } label: {
                Label("Добавить карту", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    private func customCardEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(customCards[index].categoryType.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    customCards.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                }
            }

            inputField(
                title: "Название*",
                text: Binding(
                    get: { customCards[index].name },
                    set: { customCards[index].name = $0 }
                ),
                prompt: "Например, Путешествия"
            )

            SubcategoryIconPickerView(
                selectedIconName: Binding(
                    get: { customCards[index].iconName },
                    set: { customCards[index].iconName = $0 }
                )
            )

            inputField(
                title: "Минимальная сумма*",
                text: Binding(
                    get: { customCards[index].minInput },
                    set: { customCards[index].minInput = $0 }
                ),
                prompt: "Обязательный минимум"
            )

            inputField(
                title: "Процент внутри категории",
                text: Binding(
                    get: { customCards[index].percentageInput },
                    set: { customCards[index].percentageInput = $0 }
                ),
                prompt: "Необязательно"
            )
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            return "Карты по умолчанию и свои карты"
        case 4:
            return "Выбор стратегии"
        default:
            return "Итоговая конфигурация"
        }
    }

    private var stepDescription: String {
        switch currentStep {
        case 1:
            return "Собираем базовые данные для стартового бюджета."
        case 2:
            return "Учитываем состав семьи, детей и кредитные платежи."
        case 3:
            return "Показываем системные карты и даем добавить пользовательские."
        case 4:
            return "Определяем месячное распределение по категориям."
        default:
            return "Проверяем итоговые минимумы, свободный капитал и дефициты."
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

    private var areCustomCardsValid: Bool {
        customCards.allSatisfy { card in
            !card.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && parsedDouble(card.minInput) > 0
                && (card.percentageInput.isEmpty || parsedDouble(card.percentageInput) > 0)
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 1:
            return isStepOneValid
        case 2:
            return isStepTwoValid
        case 3:
            return areCustomCardsValid
        case 4:
            return true
        default:
            return preview != nil
        }
    }

    private var preview: StartOnboardingPreview? {
        guard isStepOneValid, isStepTwoValid, areCustomCardsValid else { return nil }
        return builder.buildPreview(input: resolvedInput)
    }

    private var resolvedInput: StartOnboardingInput {
        StartOnboardingInput(
            monthlyIncome: parsedDouble(monthlyIncomeInput),
            capital: parsedDouble(capitalInput),
            housingType: housingType,
            housingCost: parsedDouble(housingCostInput),
            carsCount: carsCount,
            dependentsCount: dependentsCount,
            childrenCount: childrenCount,
            hasCredit: hasCredit,
            creditMonthlyPayment: parsedDouble(creditPaymentInput),
            strategy: strategy,
            customCards: customCards.compactMap { card in
                let name = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let minLimit = parsedDouble(card.minInput)
                guard !name.isEmpty, minLimit > 0 else { return nil }
                let percentValue = card.percentageInput.isEmpty ? nil : parsedDouble(card.percentageInput)
                return StartCustomCardInput(
                    id: card.id,
                    categoryType: card.categoryType,
                    name: name,
                    iconName: card.iconName,
                    minLimit: minLimit,
                    percentage: percentValue
                )
            }
        )
    }

    private func systemCards(for categoryType: ExpenseCategoryType) -> [StartSystemCardDescriptor] {
        StartOnboardingBuilder.systemCardDescriptors(
            housingType: housingType,
            carsCount: carsCount,
            childrenCount: childrenCount,
            capital: parsedDouble(capitalInput),
            hasCredit: hasCredit
        )
        .filter { $0.categoryType == categoryType }
    }

    private func customCardIndices(for categoryType: ExpenseCategoryType) -> [Int] {
        customCards.indices.filter { customCards[$0].categoryType == categoryType }
    }

    private func appendCustomCard(to categoryType: ExpenseCategoryType) {
        customCards.append(
            EditableCustomCard(
                categoryType: categoryType,
                iconName: SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
            )
        )
    }

    private func parsedDouble(_ input: String) -> Double {
        let normalized = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }
}

private struct EditableCustomCard: Identifiable, Hashable {
    let id: UUID
    let categoryType: ExpenseCategoryType
    var name: String
    var iconName: String
    var minInput: String
    var percentageInput: String

    init(
        id: UUID = UUID(),
        categoryType: ExpenseCategoryType,
        name: String = "",
        iconName: String,
        minInput: String = "",
        percentageInput: String = ""
    ) {
        self.id = id
        self.categoryType = categoryType
        self.name = name
        self.iconName = iconName
        self.minInput = minInput
        self.percentageInput = percentageInput
    }
}
