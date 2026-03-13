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
                    title: "Свободный капитал*",
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
                title: "Категории потребностей",
                text: "Список основных потребностей, сформированых на основе Ваших данных. Вы можете добавить свои, но общий процент расходов не может привышать 100%."
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
                    customCardRow(index: index)
                }
            }

            Button {
                presentNewCustomCardSheet(for: categoryType)
            } label: {
                Label("Добавить карту", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    private func customCardRow(index: Int) -> some View {
        let card = customCards[index]

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: card.iconName)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.subheadline.weight(.medium))

                    Text("Минимум: \(parsedDouble(card.minInput), format: .currency(code: "UAH"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if card.percentageInput.isEmpty {
                        Text("Процент: будет рассчитан от минимума")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Процент: \(parsedDouble(card.percentageInput), specifier: "%.2f")%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        presentEditCustomCardSheet(for: card.id)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        customCards.remove(at: index)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
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
            return "Карты потребностей"
        case 4:
            return "Выбор стратегии"
        default:
            return "Итоговая конфигурация"
        }
    }

    private var stepDescription: String {
        switch currentStep {
        case 1:
            return "Введи данные для распределения стартового бюджета на потребности."
        case 2:
            return "Состав семьи, детей и дополнительные платежи."
        case 3:
            return "Список финальных потребностей."
        case 4:
            return "Выбери стратегию своего бюджета."
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
