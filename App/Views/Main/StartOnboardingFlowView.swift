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
    @State private var customCards: [EditableCustomCard] = []
    @State private var isCustomCardSheetPresented = false
    @State private var customCardDraft = EditableCustomCard(
        categoryType: .essentials,
        iconName: SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
    )
    @State private var editingCustomCardID: UUID?

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
            .sheet(isPresented: $isCustomCardSheetPresented, onDismiss: resetCustomCardSheetState) {
                CustomCardSheetView(
                    draft: $customCardDraft,
                    isEditing: editingCustomCardID != nil,
                    onCancel: dismissCustomCardSheet,
                    onSave: saveCustomCardDraft
                )
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
                ForEach(preview.configuration.categoryBudgets) { budget in
                    if let allocation = preview.distribution.categoryAllocations.first(where: { $0.type == budget.type }) {
                        onboardingCategorySection(budget: budget, allocation: allocation)
                    }
                }
            } else {
                validationText("Не удалось рассчитать карты потребностей. Проверьте введенные значения.")
            }

            if !areCustomCardsValid {
                validationText("Название и минимальная сумма обязательны для заполнения")
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
        allocation: CategoryAllocation
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                ForEach(allocation.subcategoryAllocations) { subcategory in
                    onboardingSubcategoryCard(subcategory)
                }
            }

            Button {
                presentNewCustomCardSheet(for: budget.type)
            } label: {
                Label("Добавить карту", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func onboardingSubcategoryCard(_ subcategory: SubcategoryAllocation) -> some View {
        let currentMinimumAmount = currentMinimumAmount(for: subcategory)
        let deficitColor: Color = subcategory.deficitAmount > 0.01 ? .orange : .secondary

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: subcategory.iconName)
                    .frame(width: 24)
                    .foregroundStyle(subcategory.isSystem ? .primary : .secondary)

                Text(subcategory.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                if !subcategory.isSystem {
                    HStack(spacing: 12) {
                        Button {
                            presentEditCustomCardSheet(for: subcategory.id)
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)

                        Button(role: .destructive) {
                            removeCustomCard(id: subcategory.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Базовые параметры")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                onboardingParameterRow("Мин. сумма", currency(subcategory.minLimit ?? 0))
                onboardingParameterRow("Макс. сумма", maxLimitText(for: subcategory))
                onboardingParameterRow("Плановый процент", percentText(subcategory.basePercentage))
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Текущие параметры")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                onboardingParameterRow("Текущая мин. сумма", currency(currentMinimumAmount))
                onboardingParameterRow("Текущий процент от категории", percentText(subcategory.percentage))
                onboardingParameterRow("Дефицит", currency(subcategory.deficitAmount), valueColor: deficitColor)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func onboardingParameterRow(
        _ title: String,
        _ value: String,
        valueColor: Color = .secondary
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.weight(.medium))
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
            return "Проверь финальные карты потребностей и при необходимости добавь свои."
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
            return true
        case 4:
            return areCustomCardsValid
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
            hasCar: hasCar,
            dependentsCount: dependentsCount,
            elderlyDependentsCount: elderlyDependentsCount,
            childrenCount: childrenCount,
            petsCount: petsCount,
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

    private func presentNewCustomCardSheet(for categoryType: ExpenseCategoryType) {
        editingCustomCardID = nil
        customCardDraft = EditableCustomCard(
            categoryType: categoryType,
            iconName: SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
        )
        isCustomCardSheetPresented = true
    }

    private func presentEditCustomCardSheet(for id: UUID) {
        guard let card = customCards.first(where: { $0.id == id }) else { return }
        editingCustomCardID = id
        customCardDraft = card
        isCustomCardSheetPresented = true
    }

    private func saveCustomCardDraft() {
        guard customCardDraft.isValid else { return }

        if let editingCustomCardID,
           let index = customCards.firstIndex(where: { $0.id == editingCustomCardID }) {
            customCards[index] = customCardDraft
        } else {
            customCards.append(customCardDraft)
        }

        dismissCustomCardSheet()
    }

    private func removeCustomCard(id: UUID) {
        guard let index = customCards.firstIndex(where: { $0.id == id }) else { return }
        customCards.remove(at: index)
    }

    private func dismissCustomCardSheet() {
        isCustomCardSheetPresented = false
    }

    private func resetCustomCardSheetState() {
        editingCustomCardID = nil
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

    var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let minValue = parsedDecimal(minInput)
        let percentValue = parsedDecimal(percentageInput)

        guard !trimmedName.isEmpty, minValue > 0 else {
            return false
        }

        return percentageInput.isEmpty || percentValue > 0
    }

    private func parsedDecimal(_ input: String) -> Double {
        let normalized = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }
}

private struct CustomCardSheetView: View {
    @Binding var draft: EditableCustomCard

    let isEditing: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    infoSection

                    fieldCard {
                        textField(
                            title: "Название*",
                            text: $draft.name,
                            prompt: "Например, Путешествия"
                        )

                        SubcategoryIconPickerView(selectedIconName: $draft.iconName)

                        numericField(
                            title: "Минимальная сумма*",
                            text: $draft.minInput,
                            prompt: "Обязательный минимум"
                        )

                        numericField(
                            title: "Процент внутри категории",
                            text: $draft.percentageInput,
                            prompt: "Необязательно"
                        )
                    }

                    if !draft.isValid {
                        Text("Заполните название и минимальную сумму. Процент можно оставить пустым.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Редактирование карты" : "Новая карта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Сохранить" : "Создать", action: onSave)
                        .disabled(!draft.isValid)
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draft.categoryType.title)
                .font(.headline)
            Text("Сохраните для добавления потребности в категорию.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func fieldCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content)
            .padding()
            .background(AppTheme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func textField(
        title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))

            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func numericField(
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
}
