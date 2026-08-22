import SwiftUI

struct ExpenseSheetView<ManagementDestination: View>: View {
    let target: ExpenseTarget
    let currencyCode: String
    let currentCardAmount: Double
    let bankAvailableAmount: Double
    let isManualOnly: Bool
    let coverageRequirement: CategoryCoverageRequirement?
    let fundingPreview: ExpenseFundingPreview?
    let managementDestination: ManagementDestination
    @Binding var expenseInput: String
    @Binding var fundingStrategy: ExpenseFundingStrategy
    let onPay: (Double, ExpenseFundingStrategy) -> Void
    let onAutoForcedPay: (Double, ExpenseFundingStrategy) -> Void
    let onManualForcedPay: (Double, [UUID: Double], ExpenseFundingStrategy) -> Void
    let onConvertToFreeCapital: (Double, Double) -> Void
    let onCancel: () -> Void

    @State private var isCoverageChoicePresented = false
    @State private var isManualCoveragePresented = false
    @State private var isManualWriteOffChoicePresented = false
    @State private var isCurrencyConversionPresented = false

    private let keypadRows: [[ExpenseKeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.decimal, .digit("0"), .backspace]
    ]

    private var enteredAmount: Double {
        let normalized = expenseInput.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private var availableFromSubcategory: Double {
        currentCardAmount
    }

    private var canPay: Bool {
        guard enteredAmount > 0 else { return false }

        return fundingPreview?.canPay ?? false
    }

    private var amountDisplay: String {
        expenseInput.isEmpty ? "0" : expenseInput
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    availabilityCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 0)

                fundingBreakdownArea
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .frame(maxHeight: .infinity)

                amountCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                customKeyboard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(AppTheme.appBackground)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
            .navigationTitle(target.subcategoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) {
                        Text("Назад")
                            .lineLimit(1)
                            .frame(width: 94)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    NavigationLink {
                        managementDestination
                    } label: {
                        Text("Изменить")
                            .lineLimit(1)
                            .frame(width: 94)
                    }
                }
            }
            .confirmationDialog("Покрытие внутри категории", isPresented: $isCoverageChoicePresented, titleVisibility: .visible) {
                Button("Авто") {
                    onAutoForcedPay(enteredAmount, fundingStrategy)
                }

                Button("Ручной выбор") {
                    isManualCoveragePresented = true
                }

                Button("Отмена", role: .cancel) {}
            } message: {
                if let coverageRequirement {
                    Text("Нужно дополнительно покрыть \(currency(coverageRequirement.shortageAmount)) за счет других карточек категории.")
                }
            }
            .confirmationDialog(
                "Как списать валюту?",
                isPresented: $isManualWriteOffChoicePresented,
                titleVisibility: .visible
            ) {
                Button("Списать в затраты") {
                    onPay(enteredAmount, fundingStrategy)
                }

                Button("Перевести в свободный капитал") {
                    isCurrencyConversionPresented = true
                }

                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Выберите назначение для \(currency(enteredAmount)).")
            }
            .sheet(isPresented: $isManualCoveragePresented) {
                if let coverageRequirement {
                    ForcedCoverageSheetView(
                        title: "Ручное покрытие",
                        subtitle: "Выберите, с каких карточек категории снять деньги для оплаты \(target.subcategoryName).",
                        currencyCode: currencyCode,
                        requirement: coverageRequirement,
                        onConfirm: { allocations in
                            onManualForcedPay(enteredAmount, allocations, fundingStrategy)
                            isManualCoveragePresented = false
                        },
                        onCancel: {
                            isManualCoveragePresented = false
                        }
                    )
                }
            }
            .sheet(isPresented: $isCurrencyConversionPresented) {
                CurrencyConversionSheetView(
                    foreignAmount: enteredAmount,
                    foreignCurrencyCode: currencyCode,
                    onConfirm: { exchangeRate in
                        onConvertToFreeCapital(enteredAmount, exchangeRate)
                        isCurrencyConversionPresented = false
                    },
                    onCancel: {
                        isCurrencyConversionPresented = false
                    }
                )
            }
        }
    }

    private var availabilityCard: some View {
        HStack(spacing: 10) {
            availabilityPill(title: "Карточка", value: currency(availableFromSubcategory))
            if !isManualOnly {
                availabilityPill(title: "Свободный капитал", value: currency(bankAvailableAmount))
            }
        }
    }

    private func availabilityPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var amountCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "banknote")
                    .font(.title2.weight(.semibold))

                Text(currencyCode)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.95))

            Rectangle()
                .fill(.white.opacity(0.55))
                .frame(width: 1)
                .padding(.vertical, 8)

            Spacer(minLength: 8)

            Text(amountDisplay)
                .font(.system(size: 48, weight: .light, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Button {
                removeLastAmountCharacter()
            } label: {
                Image(systemName: "delete.left.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(expenseInput.isEmpty ? 0.35 : 0.95))
            }
            .disabled(expenseInput.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.40, green: 0.78, blue: 0.55),
                    Color(red: 0.27, green: 0.66, blue: 0.46)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var customKeyboard: some View {
        VStack(spacing: 7) {
            ForEach(keypadRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 7) {
                    ForEach(Array(keypadRows[rowIndex].enumerated()), id: \.offset) { _, key in
                        keypadButton(key)
                    }
                }
            }

            HStack(spacing: 7) {
                Button {
                    expenseInput = ""
                } label: {
                    Text("Очистить")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(expenseInput.isEmpty)

                Button {
                    submitPayment()
                } label: {
                    Text(canPay ? (isManualOnly ? "Продолжить" : "Оплатить") : "Оплата недоступна")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(canPay ? AppTheme.accent : Color.secondary.opacity(0.32))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .disabled(!canPay)
            }
        }
    }

    private func keypadButton(_ key: ExpenseKeypadKey) -> some View {
        Button {
            handleKeypadTap(key)
        } label: {
            Group {
                switch key {
                case .digit(let value):
                    Text(value)
                case .decimal:
                    Text(",")
                case .backspace:
                    Image(systemName: "delete.left")
                }
            }
            .font(.system(size: key.isPrimaryInput ? 35 : 25, weight: .regular, design: .rounded))
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: 53)
            .foregroundStyle(Color.primary)
            .background(AppTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var fundingBreakdownArea: some View {
        VStack(spacing: 12) {
            Text(isManualOnly ? "Списание с валютного баланса" : "Порядок списания")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            if !isManualOnly {
                Picker("Порядок списания", selection: $fundingStrategy) {
                    ForEach(ExpenseFundingStrategy.allCases) { strategy in
                        Text(shortFundingStrategyTitle(strategy)).tag(strategy)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if enteredAmount > 0, let fundingPreview {
                        fundingBreakdownContent(fundingPreview)
                    } else {
                        emptyFundingBreakdownState
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyFundingBreakdownState: some View {
        Text("Введите сумму, чтобы увидеть порядок списания")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 28)
    }

    @ViewBuilder
    private func fundingBreakdownContent(_ preview: ExpenseFundingPreview) -> some View {
        ForEach(preview.immediateLines) { line in
            fundingLine(line)
        }

        if !preview.confirmationLines.isEmpty {
            Divider()

            Text(preview.canPay
                 ? "Потребуется подтверждение: часть суммы будет взята из защищенных остатков других карточек. При выборе «Авто»:"
                 : "Будут использованы все доступные остатки других карточек:")
                .font(.caption)
                .foregroundStyle(preview.canPay ? AppTheme.warning : AppTheme.negative)

            ForEach(preview.confirmationLines) { line in
                fundingLine(line)
            }
        }

        if preview.uncoveredAmount > 0.0001 {
            Text("Не хватает \(currency(preview.uncoveredAmount)). Операция недоступна.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.negative)
        }
    }

    private func submitPayment() {
        guard canPay else { return }
        if isManualOnly {
            isManualWriteOffChoicePresented = true
        } else if let coverageRequirement, coverageRequirement.canCover {
            isCoverageChoicePresented = true
        } else {
            onPay(enteredAmount, fundingStrategy)
        }
    }

    private func fundingLine(_ line: ExpenseFundingLine) -> some View {
        HStack(spacing: 10) {
            Image(systemName: line.iconName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(fundingColor(for: line.kind))
                .frame(width: 24, height: 24)
                .background(fundingColor(for: line.kind).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(line.title)
                    .font(.caption.weight(.medium))

                Text(fundingDescription(for: line.kind))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(currency(line.amount))
                .font(.caption.monospacedDigit().weight(.semibold))
        }
    }

    private func fundingDescription(for kind: ExpenseFundingKind) -> String {
        switch kind {
        case .selectedCard:
            return "Выбранная карточка"
        case .automaticCategoryCard:
            return "Автоматически из свободного остатка"
        case .freeCapital:
            return "Автоматически"
        case .confirmedCategoryCard:
            return "После подтверждения"
        }
    }

    private func fundingColor(for kind: ExpenseFundingKind) -> Color {
        switch kind {
        case .selectedCard:
            return .accentColor
        case .automaticCategoryCard:
            return AppTheme.info
        case .freeCapital:
            return AppTheme.positive
        case .confirmedCategoryCard:
            return AppTheme.warning
        }
    }

    private func shortFundingStrategyTitle(_ strategy: ExpenseFundingStrategy) -> String {
        switch strategy {
        case .categoryFirst:
            return "Карточка"
        case .freeCapitalFirst:
            return "Капитал"
        }
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }

    private func handleKeypadTap(_ key: ExpenseKeypadKey) {
        switch key {
        case .digit(let value):
            appendAmountText(value)
        case .decimal:
            appendDecimalSeparator()
        case .backspace:
            removeLastAmountCharacter()
        }
    }

    private func appendAmountText(_ value: String) {
        expenseInput = sanitizedAmountInput(expenseInput + value)
    }

    private func appendDecimalSeparator() {
        guard !expenseInput.contains(",") && !expenseInput.contains(".") else { return }
        expenseInput = expenseInput.isEmpty ? "0," : "\(expenseInput),"
    }

    private func removeLastAmountCharacter() {
        guard !expenseInput.isEmpty else { return }
        expenseInput.removeLast()
        expenseInput = sanitizedAmountInput(expenseInput)
    }

    private func sanitizedAmountInput(_ input: String) -> String {
        var result = ""
        var hasSeparator = false
        var fractionCount = 0

        for character in input {
            if character.isNumber {
                if hasSeparator {
                    guard fractionCount < 2 else { continue }
                    fractionCount += 1
                }
                result.append(character)
            } else if character == "," || character == "." {
                guard !hasSeparator else { continue }
                hasSeparator = true
                if result.isEmpty {
                    result = "0"
                }
                result.append(",")
            }
        }

        let parts = result.split(separator: ",", omittingEmptySubsequences: false)
        guard let integerPart = parts.first else { return "" }

        var normalizedInteger = String(integerPart)
        while normalizedInteger.count > 1 && normalizedInteger.first == "0" {
            normalizedInteger.removeFirst()
        }

        guard parts.count > 1 else {
            return normalizedInteger == "0" ? "0" : normalizedInteger
        }

        return "\(normalizedInteger),\(parts[1])"
    }
}

private struct CurrencyConversionSheetView: View {
    let foreignAmount: Double
    let foreignCurrencyCode: String
    let onConfirm: (Double) -> Void
    let onCancel: () -> Void

    @State private var exchangeRateInput = ""

    private var exchangeRate: Double {
        CurrencyInputFormatter.value(from: exchangeRateInput, allowsNegative: false)
    }

    private var creditedAmount: Double {
        ((foreignAmount * exchangeRate) * 100).rounded() / 100
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Сумма конвертации")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AppCurrencyFormatter.string(foreignAmount, currencyCode: foreignCurrencyCode))
                        .font(.title2.monospacedDigit().weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Курс к гривне")
                        .font(.subheadline.weight(.semibold))

                    HStack {
                        Text("1 \(foreignCurrencyCode) =")
                            .foregroundStyle(.secondary)
                        CurrencyInput(
                            text: $exchangeRateInput,
                            placeholder: "Например, 41,50",
                            currencyCode: "UAH",
                            autoFocus: true
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("В свободный капитал поступит")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(AppCurrencyFormatter.string(creditedAmount, currencyCode: "UAH"))
                        .font(.title.monospacedDigit().weight(.bold))
                        .foregroundStyle(exchangeRate > 0 ? AppTheme.positive : .secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Spacer()

                Button {
                    onConfirm(exchangeRate)
                } label: {
                    Text("Конвертировать и зачислить")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(exchangeRate <= 0 || creditedAmount <= 0)
            }
            .padding()
            .background(AppTheme.appBackground.ignoresSafeArea())
            .navigationTitle("Перевод в капитал")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
            }
        }
    }
}

private enum ExpenseKeypadKey: Hashable {
    case digit(String)
    case decimal
    case backspace

    var isPrimaryInput: Bool {
        switch self {
        case .digit, .decimal:
            return true
        case .backspace:
            return false
        }
    }
}
