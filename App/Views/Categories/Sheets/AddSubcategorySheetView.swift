import SwiftUI

struct AddSubcategorySheetView: View {
    let target: AddSubcategoryTarget
    let currencyCode: String
    let bankAvailableAmount: Double
    let freePercent: Double
    let freeMoney: Double
    let coverageRequirement: CategoryCoverageRequirement?

    @Binding var subcategoryNameInput: String
    @Binding var subcategoryPercentInput: String
    @Binding var subcategoryMinAmountInput: String
    @Binding var subcategoryMaxAmountInput: String
    @Binding var subcategoryIconName: String

    let canCreate: Bool
    let onCreate: () -> Void
    let onCreateWithAutomaticForcedCoverage: () -> Void
    let onCreateWithManualForcedCoverage: ([UUID: Double]) -> Void
    let onCancel: () -> Void

    @FocusState private var isNameFocused: Bool
    @State private var isCoverageChoicePresented = false
    @State private var isManualCoveragePresented = false

    private var requestedPercent: Double {
        nonNegativeValue(from: subcategoryPercentInput)
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

                    Text("Свободно денег: \(currency(freeMoney))")
                        .font(.subheadline)
                        .foregroundColor(freeMoney > 0 ? .secondary : .red)

                    Text("Из них в свободном капитале: \(currency(bankAvailableAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let coverageRequirement, requestedMinAmount > 0 {
                        coverageInfo(requirement: coverageRequirement)
                    }

                    if freePercent <= 0 {
                        Text("Лимит 100% исчерпан. Добавление новой карточки недоступно.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Text("Пользовательские карточки всегда создаются с низким приоритетом.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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

                    Button("Добавить карточку") {
                        if let coverageRequirement, coverageRequirement.canCover {
                            isCoverageChoicePresented = true
                        } else {
                            onCreate()
                        }
                    }
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
            .confirmationDialog("Покрытие внутри категории", isPresented: $isCoverageChoicePresented, titleVisibility: .visible) {
                Button("Авто") {
                    onCreateWithAutomaticForcedCoverage()
                }

                Button("Ручной выбор") {
                    isManualCoveragePresented = true
                }

                Button("Отмена", role: .cancel) {}
            } message: {
                if let coverageRequirement {
                    Text("Для минимальной суммы новой карточки нужно дополнительно покрыть \(currency(coverageRequirement.shortageAmount)) из других карточек категории.")
                }
            }
            .sheet(isPresented: $isManualCoveragePresented) {
                if let coverageRequirement {
                    ForcedCoverageSheetView(
                        title: "Ручное покрытие",
                        subtitle: "Выберите, с каких карточек категории снять деньги для новой карточки.",
                        currencyCode: currencyCode,
                        requirement: coverageRequirement,
                        onConfirm: { allocations in
                            onCreateWithManualForcedCoverage(allocations)
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

    private func nonNegativeValue(from input: String) -> Double {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }

    private var requestedMinAmount: Double {
        nonNegativeValue(from: subcategoryMinAmountInput)
    }

    private func coverageInfo(requirement: CategoryCoverageRequirement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Автоматически закроется свободными деньгами категории: \(currency(requirement.automaticCategoryAmount))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Автоматически закроется свободным капиталом: \(currency(requirement.bankContributionAmount))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if requirement.canCover {
                Text("Останется покрыть внутри категории: \(currency(requirement.shortageAmount)). Можно выбрать Авто или Ручной режим.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("Новая карточка недоступна: категория не покрывает минимальную сумму даже с заходом в минимумы. Максимум доступно: \(currency(requirement.totalAvailableAmount)).")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
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

struct ForcedCoverageSheetView: View {
    let title: String
    let subtitle: String
    let currencyCode: String
    let requirement: CategoryCoverageRequirement
    let onConfirm: ([UUID: Double]) -> Void
    let onCancel: () -> Void

    @State private var allocations: [UUID: String] = [:]
    @FocusState private var focusedCandidateID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Нужно покрыть: \(currency(requirement.shortageAmount))")
                            .font(.headline)

                        Text("Выбрано: \(currency(selectedTotal))")
                            .font(.subheadline)
                            .foregroundStyle(isSelectionValid ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    ForEach(requirement.candidates) { candidate in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Image(systemName: candidate.iconName)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("Доступно: \(currency(candidate.availableAmount))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            TextField(
                                "Сумма списания",
                                text: binding(for: candidate)
                            )
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedCandidateID, equals: candidate.id)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !isSelectionValid {
                        Text("Суммы должны точно покрывать задачу и не превышать доступное в каждой карточке.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Подтвердить") {
                        onConfirm(resolvedAllocations)
                    }
                    .disabled(!isSelectionValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        focusedCandidateID = nil
                    }
                }
            }
        }
    }

    private var resolvedAllocations: [UUID: Double] {
        requirement.candidates.reduce(into: [:]) { partialResult, candidate in
            let amount = parsedAmount(allocations[candidate.id] ?? "")
            if amount > 0 {
                partialResult[candidate.id] = amount
            }
        }
    }

    private var selectedTotal: Double {
        roundToCents(resolvedAllocations.values.reduce(0, +))
    }

    private var isSelectionValid: Bool {
        guard abs(selectedTotal - requirement.shortageAmount) < 0.01 else { return false }

        for candidate in requirement.candidates {
            let amount = resolvedAllocations[candidate.id] ?? 0
            if amount > candidate.availableAmount + 0.0001 {
                return false
            }
        }

        return true
    }

    private func binding(for candidate: CategoryCoverageCandidate) -> Binding<String> {
        Binding(
            get: { allocations[candidate.id] ?? "" },
            set: { allocations[candidate.id] = $0 }
        )
    }

    private func parsedAmount(_ input: String) -> Double {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private func roundToCents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private func currency(_ value: Double) -> String {
        AppCurrencyFormatter.string(value, currencyCode: currencyCode)
    }
}
