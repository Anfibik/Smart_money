import SwiftUI

struct ExpenseSheetView: View {
    let target: ExpenseTarget
    let currencyCode: String
    let bankAvailableAmount: Double
    @Binding var expenseInput: String
    @Binding var useBankForExpense: Bool
    let onPay: (Double, Bool) -> Void
    let onCancel: () -> Void

    @FocusState private var isExpenseFieldFocused: Bool

    private var enteredAmount: Double {
        let normalized = expenseInput.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private var availableFromSubcategory: Double {
        target.currentAmount
    }

    private var totalAvailable: Double {
        availableFromSubcategory + bankAvailableAmount
    }

    private var needsBank: Bool {
        enteredAmount > availableFromSubcategory + 0.0001
    }

    private var exceedsLimit: Bool {
        enteredAmount > totalAvailable + 0.0001
    }

    private var canPay: Bool {
        enteredAmount > 0 && !exceedsLimit && (!needsBank || useBankForExpense)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(target.subcategoryName)
                    .font(.title3.bold())

                Text("Доступно в подкатегории: \(availableFromSubcategory, format: .currency(code: currencyCode))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Доступно в банке: \(bankAvailableAmount, format: .currency(code: currencyCode))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Итого доступно: \(totalAvailable, format: .currency(code: currencyCode))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Введите сумму", text: $expenseInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isExpenseFieldFocused)

                if needsBank, enteredAmount > 0, bankAvailableAmount > 0 {
                    Toggle("Списать нехватку из банки", isOn: $useBankForExpense)
                        .tint(.blue)
                }

                if needsBank, enteredAmount > 0, !useBankForExpense, !exceedsLimit {
                    Text("Сумма превышает остаток подкатегории. Включите списание из банки.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if exceedsLimit {
                    Text("Оплата недоступна: сумма превышает подкатегорию + банку.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Оплатить") {
                    guard canPay else { return }
                    onPay(enteredAmount, useBankForExpense)
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
        }
    }
}
