import SwiftUI

struct ExpenseSheetView: View {
    let target: ExpenseTarget
    let currencyCode: String
    let bankAvailableAmount: Double
    let coverageRequirement: CategoryCoverageRequirement?
    let fundingPreview: ExpenseFundingPreview?
    @Binding var expenseInput: String
    @Binding var fundingStrategy: ExpenseFundingStrategy
    let onPay: (Double, ExpenseFundingStrategy) -> Void
    let onAutoForcedPay: (Double, ExpenseFundingStrategy) -> Void
    let onManualForcedPay: (Double, [UUID: Double], ExpenseFundingStrategy) -> Void
    let onCancel: () -> Void

    @FocusState private var isExpenseFieldFocused: Bool
    @State private var isCoverageChoicePresented = false
    @State private var isManualCoveragePresented = false

    private var enteredAmount: Double {
        let normalized = expenseInput.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private var availableFromSubcategory: Double {
        target.currentAmount
    }

    private var canPay: Bool {
        guard enteredAmount > 0 else { return false }

        return fundingPreview?.canPay ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(target.subcategoryName)
                        .font(.title3.bold())

                    Text("Доступно в подкатегории: \(currency(availableFromSubcategory))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Доступно в свободном капитале: \(currency(bankAvailableAmount))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        TextField("Введите сумму", text: $expenseInput)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($isExpenseFieldFocused)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Оплатить") {
                            submitPayment()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canPay)
                        .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Порядок списания")
                            .font(.subheadline.weight(.semibold))

                        Picker("Порядок списания", selection: $fundingStrategy) {
                            ForEach(ExpenseFundingStrategy.allCases) { strategy in
                                Text(strategy.title).tag(strategy)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(fundingStrategy.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if enteredAmount > 0, let fundingPreview {
                        fundingBreakdown(fundingPreview)
                    }

                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Оплата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад", action: onCancel)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isExpenseFieldFocused = false
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isExpenseFieldFocused = true
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
        }
    }

    private func fundingBreakdown(_ preview: ExpenseFundingPreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Как будет списана сумма")
                .font(.subheadline.weight(.semibold))

            ForEach(preview.immediateLines) { line in
                fundingLine(line)
            }

            if !preview.confirmationLines.isEmpty {
                Divider()

                Text(preview.canPay
                     ? "Потребуется подтверждение: часть суммы будет взята из защищенных остатков других карточек. При выборе «Авто»:"
                     : "Будут использованы все доступные остатки других карточек:")
                    .font(.caption)
                    .foregroundStyle(preview.canPay ? .orange : .red)

                ForEach(preview.confirmationLines) { line in
                    fundingLine(line)
                }
            }

            if preview.uncoveredAmount > 0.0001 {
                Text("Не хватает \(currency(preview.uncoveredAmount)). Операция недоступна.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func submitPayment() {
        guard canPay else { return }
        if let coverageRequirement, coverageRequirement.canCover {
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
            return .blue
        case .freeCapital:
            return .green
        case .confirmedCategoryCard:
            return .orange
        }
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }
}
