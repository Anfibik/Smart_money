import SwiftUI

struct EditSubcategorySheetView: View {
    let target: EditSubcategoryTarget
    let currencyCode: String
    let bankAvailableAmount: Double
    let availableForCard: Double
    let availableMoneyForCard: Double
    let currentRemaining: Double
    let currentMaxLimit: Double?

    @Binding var editNameInput: String
    @Binding var editPercentInput: String
    @Binding var editMinAmountInput: String
    @Binding var editMaxAmountInput: String
    @Binding var editIconName: String
    @Binding var withdrawAmountInput: String
    @Binding var depositAmountInput: String

    let canSave: Bool
    let onSave: () -> Void
    let onWithdraw: () -> Void
    let onDeposit: () -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool

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
        requestedWithdraw > 0 && requestedWithdraw <= maxWithdrawable + 0.0001
    }

    private var requestedDeposit: Double {
        nonNegativeValue(from: depositAmountInput)
    }

    private var maxAllowedByMaxLimit: Double {
        guard let currentMaxLimit, currentMaxLimit > 0 else {
            return bankAvailableAmount
        }
        return max(0, currentMaxLimit - currentRemaining)
    }

    private var maxDepositable: Double {
        max(0, min(bankAvailableAmount, maxAllowedByMaxLimit))
    }

    private var canDeposit: Bool {
        requestedDeposit > 0 && requestedDeposit <= maxDepositable + 0.0001
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Категория: \(target.categoryTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Свободно для этой карточки: \(formattedPercent(max(0, availableForCard)))%")
                        .font(.subheadline)
                        .foregroundColor(availableForCard > 0 ? .secondary : .red)

                    Text("Свободно денег для этой карточки: \(currency(availableMoneyForCard))")
                        .font(.subheadline)
                        .foregroundColor(availableMoneyForCard > 0 ? .secondary : .red)

                    Text("Из них в свободном капитале: \(currency(bankAvailableAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(target.isSystem
                        ? "Приоритет системной карточки задаётся правилами приложения."
                        : "Пользовательские карточки всегда имеют низкий приоритет.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if availableForCard <= 0 {
                        Text("Лимит 100% исчерпан. Увеличение процента недоступно.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    SubcategoryIconPickerView(selectedIconName: $editIconName)

                    TextField("Название*", text: $editNameInput)
                        .textFieldStyle(.roundedBorder)
                        .disabled(target.isSystem)
                        .focused($isNameFocused)

                    TextField("Основной процент*", text: $editPercentInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    if requestedPercent > availableForCard, requestedPercent > 0 {
                        Text("Превышение лимита: доступно не более \(formattedPercent(max(0, availableForCard)))%.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Минимальная сумма", text: $editMinAmountInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("Максимальная сумма", text: $editMaxAmountInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    Button("Сохранить изменения", action: onSave)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)

                    Divider()
                        .padding(.vertical, 2)

                    Text("Изъятие в свободный капитал")
                        .font(.subheadline.weight(.semibold))

                    Text("Текущий остаток: \(currency(currentRemaining))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Можно изъять: \(currency(maxWithdrawable))")
                        .font(.caption)
                        .foregroundColor(maxWithdrawable > 0 ? .secondary : .red)

                    TextField("Сумма для изъятия", text: $withdrawAmountInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    if requestedWithdraw > maxWithdrawable, requestedWithdraw > 0 {
                        Text("Сумма слишком большая: нельзя изъять больше текущего остатка карточки.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Изъять средства", action: onWithdraw)
                        .buttonStyle(.bordered)
                        .disabled(!canWithdraw)

                    Divider()
                        .padding(.vertical, 2)

                    Text("Пополнение из свободного капитала")
                        .font(.subheadline.weight(.semibold))

                    Text("Доступно в свободном капитале: \(currency(bankAvailableAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Лимит пополнения по максимуму: \(currency(maxAllowedByMaxLimit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Можно пополнить: \(currency(maxDepositable))")
                        .font(.caption)
                        .foregroundColor(maxDepositable > 0 ? .secondary : .red)

                    TextField("Сумма для пополнения", text: $depositAmountInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    if requestedDeposit > maxDepositable, requestedDeposit > 0 {
                        Text("Сумма слишком большая: пополнение ограничено свободным капиталом и максимальным лимитом карточки.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Пополнить из свободного капитала", action: onDeposit)
                        .buttonStyle(.bordered)
                        .disabled(!canDeposit)

                    if let onDelete {
                        Button("Удалить карточку", role: .destructive, action: onDelete)
                            .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Настройка карточки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Назад", action: onCancel)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isNameFocused = false
                    }
                }
            }
            .onAppear {
                if editIconName.isEmpty {
                    editIconName = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
                }
                if !target.isSystem {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isNameFocused = true
                    }
                }
            }
        }
    }

    private func nonNegativeValue(from input: String) -> Double {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }
}
