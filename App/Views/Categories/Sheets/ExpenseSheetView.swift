import SwiftUI

struct ExpenseSheetView: View {
    let target: ExpenseTarget
    let currencyCode: String
    let bankAvailableAmount: Double
    let coverageRequirement: CategoryCoverageRequirement?
    @Binding var expenseInput: String
    let onPay: (Double, Bool) -> Void
    let onAutoForcedPay: (Double) -> Void
    let onManualForcedPay: (Double, [UUID: Double]) -> Void
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

        if let coverageRequirement {
            return coverageRequirement.canCover
        }

        return true
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(target.subcategoryName)
                    .font(.title3.bold())

                Text("Доступно в подкатегории: \(availableFromSubcategory, format: .currency(code: currencyCode))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Доступно в свободном капитале: \(bankAvailableAmount, format: .currency(code: currencyCode))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Введите сумму", text: $expenseInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isExpenseFieldFocused)

                if let coverageRequirement, enteredAmount > 0 {
                    coverageInfo(requirement: coverageRequirement)
                } else if enteredAmount > availableFromSubcategory + 0.0001 {
                    Text("Нехватка будет автоматически покрыта свободными деньгами категории и свободным капиталом.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let coverageRequirement, enteredAmount > 0, !coverageRequirement.canCover {
                    Text("Операция недоступна: даже вся категория не покрывает эту сумму.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Оплатить") {
                    guard canPay else { return }
                    if let coverageRequirement, coverageRequirement.canCover {
                        isCoverageChoicePresented = true
                    } else {
                        onPay(enteredAmount, true)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canPay)

                Spacer()
            }
            .padding()
            .navigationTitle("Оплата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
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
                    onAutoForcedPay(enteredAmount)
                }

                Button("Ручной выбор") {
                    isManualCoveragePresented = true
                }

                Button("Отмена", role: .cancel) {}
            } message: {
                if let coverageRequirement {
                    Text("Нужно дополнительно покрыть \(coverageRequirement.shortageAmount, format: .currency(code: currencyCode)) за счет других карточек категории.")
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
                            onManualForcedPay(enteredAmount, allocations)
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

    private func coverageInfo(requirement: CategoryCoverageRequirement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Автоматически закроется из свободных денег категории: \(requirement.automaticCategoryAmount, format: .currency(code: currencyCode))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Автоматически закроется из свободного капитала: \(requirement.bankContributionAmount, format: .currency(code: currencyCode))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if requirement.canCover {
                Text("Останется покрыть внутри категории: \(requirement.shortageAmount, format: .currency(code: currencyCode)). Можно выбрать Авто или Ручной режим.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Даже с заходом в минимумы других карточек категория не покрывает сумму. Максимум доступно: \(requirement.totalAvailableAmount, format: .currency(code: currencyCode)).")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
