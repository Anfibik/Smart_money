import SwiftUI

struct EditSubcategorySheetView: View {
    @Environment(\.dismiss) private var dismiss

    let target: EditSubcategoryTarget
    let currencyCode: String
    let bankAvailableAmount: Double
    let availableForCard: Double
    let availableMoneyForCard: Double
    let currentRemaining: Double
    let currentMaxLimit: Double?
    let isEmbeddedInNavigationStack: Bool

    @Binding var editNameInput: String
    @Binding var editPercentInput: String
    @Binding var editMinAmountInput: String
    @Binding var editMaxAmountInput: String
    @Binding var editRequiresMinimumAmount: Bool
    @Binding var editIconName: String
    @Binding var withdrawAmountInput: String
    @Binding var depositAmountInput: String
    @Binding var depositHryvniaAmountInput: String
    @Binding var depositExchangeRateInput: String
    @Binding var depositUsesFreeCapital: Bool
    @Binding var editForeignCurrency: ForeignCurrencyType

    let canSave: Bool
    let onSave: () -> Void
    let onWithdraw: () -> Void
    let onDeposit: () -> Void
    let onCurrencyChange: (ForeignCurrencyType) -> Void
    let onConvertToFreeCapital: (Double, Double) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var lastEditedDepositField: DepositAmountField = .foreignCurrency
    @State private var withdrawExchangeRateInput = ""
    @State private var isDeleteConfirmationPresented = false

    private enum DepositAmountField {
        case foreignCurrency
        case hryvnia
    }

    private var requestedPercent: Double {
        nonNegativeValue(from: editPercentInput)
    }

    private var requestedWithdraw: Double {
        nonNegativeValue(from: withdrawAmountInput)
    }

    private var maxWithdrawable: Double {
        max(0, currentRemaining)
    }

    private var canWithdraw: Bool {
        guard requestedWithdraw > 0,
              requestedWithdraw <= maxWithdrawable + 0.0001 else {
            return false
        }
        return !target.isManualOnly || requestedWithdrawExchangeRate > 0
    }

    private var requestedWithdrawExchangeRate: Double {
        nonNegativeValue(from: withdrawExchangeRateInput)
    }

    private var requestedDeposit: Double {
        nonNegativeValue(from: depositAmountInput)
    }

    private var requestedHryvniaDeposit: Double {
        nonNegativeValue(from: depositHryvniaAmountInput)
    }

    private var requestedExchangeRate: Double {
        nonNegativeValue(from: depositExchangeRateInput)
    }

    private var maxAllowedByMaxLimit: Double {
        guard let currentMaxLimit, currentMaxLimit > 0 else {
            return bankAvailableAmount
        }
        return max(0, currentMaxLimit - currentRemaining)
    }

    private var maxDepositable: Double {
        if target.isManualOnly {
            return .greatestFiniteMagnitude
        }
        return max(0, min(bankAvailableAmount, maxAllowedByMaxLimit))
    }

    private var canDeposit: Bool {
        if target.isManualOnly, depositUsesFreeCapital {
            return requestedDeposit > 0
                && requestedHryvniaDeposit > 0
                && requestedExchangeRate > 0
                && requestedHryvniaDeposit <= bankAvailableAmount + 0.0001
        }
        return requestedDeposit > 0 && requestedDeposit <= maxDepositable + 0.0001
    }

    @ViewBuilder
    var body: some View {
        if isEmbeddedInNavigationStack {
            managementContent
        } else {
            NavigationStack {
                managementContent
            }
        }
    }

    private var managementContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if target.isManualOnly {
                    currencySection
                }

                depositSection
                transferSection

                if !target.isManualOnly {
                    parametersSection
                }

                if onDelete != nil {
                    deletionSection
                }
            }
            .padding(16)
        }
        .background(AppTheme.appBackground.ignoresSafeArea())
        .navigationTitle("Управление средствами")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEmbeddedInNavigationStack {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад", action: onCancel)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово", action: dismissKeyboard)
            }
        }
        .confirmationDialog(
            "Удалить карточку?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Удалить карточку", role: .destructive) {
                onDelete?()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            if currentRemaining > 0 {
                Text("Остаток \(currency(currentRemaining)) будет возвращён в свободный капитал.")
            } else {
                Text("Это действие нельзя отменить.")
            }
        }
        .onAppear {
            if editIconName.isEmpty {
                editIconName = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
            }
            if !isEmbeddedInNavigationStack, !target.isSystem {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isNameFocused = true
                }
            }
        }
        .onChange(of: editForeignCurrency) { oldValue, newValue in
            guard target.isManualOnly, oldValue != newValue else { return }
            onCurrencyChange(newValue)
        }
    }

    private var currencySection: some View {
        managementSection(title: "Валюта", systemImage: "dollarsign.arrow.circlepath") {
            Text("Выберите валюту")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Валюта", selection: $editForeignCurrency) {
                ForEach(ForeignCurrencyType.allCases) { currency in
                    Text(currency.displayName).tag(currency)
                }
            }
            .pickerStyle(.menu)

            Text("Смена валюты изменит только обозначение. Сумма не конвертируется.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var depositSection: some View {
        managementSection(title: "Пополнение", systemImage: "plus.circle") {
            Text("Текущий остаток: \(target.isManualOnly ? manualCurrency(currentRemaining) : currency(currentRemaining))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if target.isManualOnly {
                Toggle("Использовать свободный капитал", isOn: $depositUsesFreeCapital)

                if depositUsesFreeCapital {
                    Text("Доступно: \(hryvniaCurrency(bankAvailableAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    currencyDepositFields
                } else {
                    CurrencyInput(
                        text: $depositAmountInput,
                        placeholder: "Сумма для пополнения",
                        currencyCode: editForeignCurrency.rawValue,
                        showsDoneButton: false
                    )
                }
            } else {
                Text("Доступно в свободном капитале: \(currency(bankAvailableAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Можно пополнить: \(currency(maxDepositable))")
                    .font(.caption)
                    .foregroundColor(maxDepositable > 0 ? .secondary : AppTheme.negative)
                CurrencyInput(
                    text: $depositAmountInput,
                    placeholder: "Сумма для пополнения",
                    currencyCode: target.currencyCode,
                    showsDoneButton: false
                )
            }

            if requestedDeposit > maxDepositable, requestedDeposit > 0 {
                Text("Сумма превышает доступный свободный капитал или максимум карточки.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.negative)
            }

            Button(depositButtonTitle, action: onDeposit)
                .buttonStyle(.borderedProminent)
                .disabled(!canDeposit)
        }
    }

    @ViewBuilder
    private var currencyDepositFields: some View {
        Text("Курс: 1 \(editForeignCurrency.rawValue) в гривнах")
            .font(.caption)
            .foregroundStyle(.secondary)

        CurrencyInput(
            text: exchangeRateBinding,
            placeholder: "Курс",
            currencyCode: "UAH",
            maximumFractionDigits: 4,
            showsDoneButton: false
        )
        CurrencyInput(
            text: foreignDepositBinding,
            placeholder: "Сумма в \(editForeignCurrency.rawValue)",
            currencyCode: editForeignCurrency.rawValue,
            showsDoneButton: false
        )
        .disabled(requestedExchangeRate <= 0)
        CurrencyInput(
            text: hryvniaDepositBinding,
            placeholder: "Сумма в гривнах",
            currencyCode: "UAH",
            showsDoneButton: false
        )
        .disabled(requestedExchangeRate <= 0)

        if requestedExchangeRate <= 0 {
            Text("Сначала укажите курс валюты.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if requestedHryvniaDeposit > bankAvailableAmount {
            Text("Недостаточно свободного капитала. Не хватает \(hryvniaCurrency(requestedHryvniaDeposit - bankAvailableAmount)).")
                .font(.caption)
                .foregroundStyle(AppTheme.negative)
        }
    }

    private var transferSection: some View {
        managementSection(title: "Перевод в свободный капитал", systemImage: "arrow.up.right.circle") {
            Text("Доступно для перевода: \(target.isManualOnly ? manualCurrency(maxWithdrawable) : currency(maxWithdrawable))")
                .font(.caption)
                .foregroundColor(maxWithdrawable > 0 ? .secondary : AppTheme.negative)

            CurrencyInput(
                text: $withdrawAmountInput,
                placeholder: "Сумма для перевода",
                currencyCode: target.isManualOnly ? editForeignCurrency.rawValue : currencyCode,
                showsDoneButton: false
            )

            if target.isManualOnly {
                CurrencyInput(
                    text: $withdrawExchangeRateInput,
                    placeholder: "Курс к гривне",
                    currencyCode: "UAH",
                    maximumFractionDigits: 4,
                    showsDoneButton: false
                )

                if requestedWithdraw > 0, requestedWithdrawExchangeRate > 0 {
                    Text("В свободный капитал поступит \(hryvniaCurrency(requestedWithdraw * requestedWithdrawExchangeRate)).")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.positive)
                }
            }

            if requestedWithdraw > maxWithdrawable, requestedWithdraw > 0 {
                Text("Нельзя перевести больше текущего остатка карточки.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.negative)
            }

            Button("Перевести средства", action: performTransfer)
                .buttonStyle(.bordered)
                .disabled(!canWithdraw)
        }
    }

    private var parametersSection: some View {
        managementSection(title: "Параметры карточки", systemImage: "slider.horizontal.3") {
            Text("Категория: \(target.categoryTitle)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Свободно: \(formattedPercent(max(0, availableForCard)))% и \(currency(availableMoneyForCard))")
                .font(.caption)
                .foregroundColor(availableForCard > 0 ? .secondary : AppTheme.negative)
            Text(target.isSystem
                ? "Приоритет системной карточки задаётся правилами приложения."
                : "Пользовательские карточки имеют низкий приоритет.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if target.isSystem {
                HStack(spacing: 10) {
                    Image(systemName: editIconName)
                        .frame(width: 28)
                    Text(editNameInput)
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityElement(children: .combine)
            } else {
                SubcategoryIconPickerView(selectedIconName: $editIconName)
                TextField("Название*", text: $editNameInput)
                    .textFieldStyle(.roundedBorder)
                    .focused($isNameFocused)
            }
            TextField("Процент*", text: $editPercentInput)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            if requestedPercent > availableForCard, requestedPercent > 0 {
                Text("Доступно не более \(formattedPercent(max(0, availableForCard)))%.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.negative)
            }

            Toggle(
                "Обязательная минимальная сумма",
                isOn: $editRequiresMinimumAmount
            )
            .disabled(target.minimumRequirementIsLocked)

            if target.minimumRequirementIsLocked {
                Text("Для карточек «Жилье», «Питание» и «Подушка» обязательный минимум нельзя отключить.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CurrencyInput(
                text: $editMinAmountInput,
                placeholder: editRequiresMinimumAmount
                    ? "Минимальная сумма*"
                    : "Минимальная сумма (необязательно)",
                currencyCode: currencyCode,
                showsDoneButton: false
            )

            if editRequiresMinimumAmount,
               nonNegativeValue(from: editMinAmountInput) <= 0 {
                Text("Укажите минимальную сумму, чтобы сохранить карточку.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.negative)
            }
            CurrencyInput(
                text: $editMaxAmountInput,
                placeholder: "Максимальная сумма",
                currencyCode: currencyCode,
                showsDoneButton: false
            )
            Button("Сохранить параметры", action: saveParameters)
                .buttonStyle(.bordered)
                .disabled(!canSave)
        }
    }

    private var deletionSection: some View {
        managementSection(title: "Удаление", systemImage: "trash") {
            Text("Остаток карточки будет возвращён в свободный капитал.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Удалить карточку", role: .destructive) {
                isDeleteConfirmationPresented = true
            }
            .buttonStyle(.bordered)
        }
    }

    private func managementSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(Color.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func saveParameters() {
        onSave()
        if isEmbeddedInNavigationStack {
            dismiss()
        }
    }

    private func performTransfer() {
        if target.isManualOnly {
            onConvertToFreeCapital(requestedWithdraw, requestedWithdrawExchangeRate)
            withdrawAmountInput = ""
            withdrawExchangeRateInput = ""
        } else {
            onWithdraw()
        }
    }

    private func dismissKeyboard() {
        isNameFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func nonNegativeValue(from input: String) -> Double {
        CurrencyInputFormatter.value(from: input, allowsNegative: false)
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }

    private func manualCurrency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: editForeignCurrency.rawValue)
    }

    private func hryvniaCurrency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: "UAH")
    }

    private var depositButtonTitle: String {
        if target.isManualOnly {
            return depositUsesFreeCapital
                ? "Конвертировать из свободного капитала"
                : "Пополнить баланс"
        }
        return "Пополнить из свободного капитала"
    }

    private var foreignDepositBinding: Binding<String> {
        Binding(
            get: { depositAmountInput },
            set: { newValue in
                depositAmountInput = newValue
                lastEditedDepositField = .foreignCurrency
                recalculateHryvniaDeposit()
            }
        )
    }

    private var hryvniaDepositBinding: Binding<String> {
        Binding(
            get: { depositHryvniaAmountInput },
            set: { newValue in
                depositHryvniaAmountInput = newValue
                lastEditedDepositField = .hryvnia
                recalculateForeignDeposit()
            }
        )
    }

    private var exchangeRateBinding: Binding<String> {
        Binding(
            get: { depositExchangeRateInput },
            set: { newValue in
                depositExchangeRateInput = newValue
                switch lastEditedDepositField {
                case .foreignCurrency:
                    recalculateHryvniaDeposit()
                case .hryvnia:
                    recalculateForeignDeposit()
                }
            }
        )
    }

    private func recalculateHryvniaDeposit() {
        let rate = requestedExchangeRate
        let foreignAmount = requestedDeposit
        guard rate > 0, foreignAmount > 0 else {
            depositHryvniaAmountInput = ""
            return
        }
        depositHryvniaAmountInput = formattedInput(foreignAmount * rate)
    }

    private func recalculateForeignDeposit() {
        let rate = requestedExchangeRate
        let hryvniaAmount = requestedHryvniaDeposit
        guard rate > 0, hryvniaAmount > 0 else {
            depositAmountInput = ""
            return
        }
        depositAmountInput = formattedInput(hryvniaAmount / rate)
    }

    private func formattedInput(_ value: Double) -> String {
        let rawValue = String(format: "%.2f", value)
            .replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        return CurrencyInputFormatter.sanitized(rawValue)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }
}
