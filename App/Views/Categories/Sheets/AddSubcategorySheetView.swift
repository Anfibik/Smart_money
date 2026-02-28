import SwiftUI

struct AddSubcategorySheetView: View {
    let target: AddSubcategoryTarget
    let currencyCode: String
    let bankAvailableAmount: Double
    let freePercent: Double
    let freeMoney: Double
    let highPriorityName: String
    let mediumPriorityName: String

    @Binding var subcategoryNameInput: String
    @Binding var subcategoryPercentInput: String
    @Binding var subcategoryMinAmountInput: String
    @Binding var subcategoryMaxAmountInput: String
    @Binding var subcategoryIconName: String
    @Binding var subcategoryPriority: SubcategoryPriorityLevel

    let canCreate: Bool
    let onRequestPriorityChange: (SubcategoryPriorityLevel, String) -> Void
    let onClearPriority: () -> Void
    let onCreate: () -> Void
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool

    private var requestedPercent: Double {
        nonNegativeValue(from: subcategoryPercentInput)
    }

    private var priorityTargetName: String {
        let trimmed = subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "новая карточка" : trimmed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Категория: \(target.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Свободно: \(formattedPercent(max(0, freePercent)))%")
                        .font(.subheadline)
                        .foregroundColor(freePercent > 0 ? .secondary : .red)

                    Text("Свободно денег: \(freeMoney, format: .currency(code: currencyCode))")
                        .font(.subheadline)
                        .foregroundColor(freeMoney > 0 ? .secondary : .red)

                    Text("Из них в банке: \(bankAvailableAmount, format: .currency(code: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Высокий: \(highPriorityName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Средний: \(mediumPriorityName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button("Высокий") {
                            onRequestPriorityChange(.high, priorityTargetName)
                        }
                        .priorityButtonStyle(selected: subcategoryPriority == .high)

                        Button("Средний") {
                            onRequestPriorityChange(.medium, priorityTargetName)
                        }
                        .priorityButtonStyle(selected: subcategoryPriority == .medium)

                        if subcategoryPriority != .low {
                            Button("Снять", action: onClearPriority)
                                .buttonStyle(.bordered)
                        }
                    }

                    if freePercent <= 0 {
                        Text("Лимит 100% исчерпан. Добавление новой карточки недоступно.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    SubcategoryIconPickerView(selectedIconName: $subcategoryIconName)

                    TextField("Название*", text: $subcategoryNameInput)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFocused)

                    TextField("Основной процент*", text: $subcategoryPercentInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    if requestedPercent > freePercent, requestedPercent > 0 {
                        Text("Превышение лимита: доступно не более \(formattedPercent(max(0, freePercent)))%.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    TextField("Минимальная сумма", text: $subcategoryMinAmountInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    TextField("Максимальная сумма", text: $subcategoryMaxAmountInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)

                    Button("Добавить карточку", action: onCreate)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreate)
                }
                .padding()
            }
            .navigationTitle("Новая подкатегория")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isNameFocused = false
                    }
                }
            }
            .onAppear {
                if subcategoryIconName.isEmpty {
                    subcategoryIconName = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isNameFocused = true
                }
            }
        }
    }

    private func nonNegativeValue(from input: String) -> Double {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }
}

struct SubcategoryIconPickerView: View {
    @Binding var selectedIconName: String
    @State private var isPickerPresented = false

    private var currentIconName: String {
        let normalized = selectedIconName.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? SubcategoryIconCatalog.fallbackSymbol : normalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Значок")
                .font(.subheadline.weight(.semibold))

            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 8) {
                    Text("Иконка")
                        .font(.body)

                    Spacer(minLength: 8)

                    Image(systemName: currentIconName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isPickerPresented) {
            SubcategoryIconPickerSheetView(
                selectedIconName: $selectedIconName,
                isPresented: $isPickerPresented
            )
            .presentationDetents([.medium, .large])
        }
    }
}

private struct SubcategoryIconPickerSheetView: View {
    @Binding var selectedIconName: String
    @Binding var isPresented: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(SubcategoryIconCatalog.selectableSymbols, id: \.self) { iconName in
                        Button {
                            selectedIconName = iconName
                            isPresented = false
                        } label: {
                            Image(systemName: iconName)
                                .font(.title2)
                                .frame(width: 48, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIconName == iconName ? Color.accentColor.opacity(0.18) : Color(.systemGray6))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedIconName == iconName ? Color.accentColor : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(iconName)
                    }
                }
                .padding()
            }
            .navigationTitle("Выбор иконки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func priorityButtonStyle(selected: Bool) -> some View {
        if selected {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }
}
