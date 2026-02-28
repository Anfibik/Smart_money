import SwiftUI

struct InitialSystemSetupCard: Identifiable, Hashable {
    let id: String
    let categoryType: ExpenseCategoryType
    let name: String
    let defaultPercentage: Double
    let defaultMinLimit: Double?
    let defaultMaxLimit: Double?

    init(
        categoryType: ExpenseCategoryType,
        name: String,
        defaultPercentage: Double,
        defaultMinLimit: Double?,
        defaultMaxLimit: Double?
    ) {
        self.id = "\(categoryType.rawValue)::\(name)"
        self.categoryType = categoryType
        self.name = name
        self.defaultPercentage = defaultPercentage
        self.defaultMinLimit = defaultMinLimit
        self.defaultMaxLimit = defaultMaxLimit
    }
}

struct InitialSystemSetupView: View {
    let cards: [InitialSystemSetupCard]
    let onComplete: ([SystemSubcategorySetup]) -> Void

    @State private var rows: [SetupRowState] = []
    @State private var didInitialize = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introText

                    ForEach(categorySections, id: \.categoryType) { section in
                        categorySection(section)
                    }

                    Button("Сохранить и начать") {
                        save()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
                .padding()
            }
            .navigationTitle("Первый запуск")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            guard !didInitialize else { return }
            rows = cards.map { SetupRowState(card: $0) }
            didInitialize = true
        }
    }

    private var introText: some View {
        Text("Заполните системные карточки. Для каждой карточки обязательны основной процент и минимальная сумма.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var categorySections: [CategorySectionData] {
        ExpenseCategoryType.allCases.compactMap { type in
            let indices = rows.indices.filter { rows[$0].categoryType == type }
            guard !indices.isEmpty else { return nil }
            return CategorySectionData(categoryType: type, rowIndices: indices)
        }
    }

    @ViewBuilder
    private func categorySection(_ section: CategorySectionData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.categoryType.title)
                .font(.headline)

            Text("Сумма процентов: \(formattedPercent(enteredPercentSum(for: section.categoryType)))% / 100%")
                .font(.caption)
                .foregroundColor(isCategoryPercentValid(section.categoryType) ? .secondary : .red)

            ForEach(section.rowIndices, id: \.self) { index in
                rowEditor(index: index)
            }
        }
    }

    @ViewBuilder
    private func rowEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rows[index].name)
                .font(.subheadline.weight(.semibold))

            TextField("Основной процент*", text: binding(for: index, keyPath: \.percentageInput))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            TextField("Минимальная сумма*", text: binding(for: index, keyPath: \.minInput))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            TextField("Максимальная сумма", text: binding(for: index, keyPath: \.maxInput))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            if !isRowValid(rows[index]) {
                Text(rowValidationMessage(for: rows[index]))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var canSave: Bool {
        guard !rows.isEmpty else { return false }
        let allRowsValid = rows.allSatisfy { isRowValid($0) }
        let categoryPercentsValid = ExpenseCategoryType.allCases.allSatisfy { isCategoryPercentValid($0) }
        return allRowsValid && categoryPercentsValid
    }

    private func save() {
        let setups = rows.map { row in
            let maxValue = nonNegativeValue(from: row.maxInput)
            return SystemSubcategorySetup(
                categoryType: row.categoryType,
                name: row.name,
                percentage: nonNegativeValue(from: row.percentageInput),
                minLimit: nonNegativeValue(from: row.minInput),
                maxLimit: maxValue > 0 ? maxValue : nil
            )
        }

        onComplete(setups)
    }

    private func isCategoryPercentValid(_ categoryType: ExpenseCategoryType) -> Bool {
        enteredPercentSum(for: categoryType) <= 100.0001
    }

    private func enteredPercentSum(for categoryType: ExpenseCategoryType) -> Double {
        rows
            .filter { $0.categoryType == categoryType }
            .reduce(0.0) { partialResult, row in
                partialResult + nonNegativeValue(from: row.percentageInput)
            }
    }

    private func isRowValid(_ row: SetupRowState) -> Bool {
        let percent = nonNegativeValue(from: row.percentageInput)
        let minValue = nonNegativeValue(from: row.minInput)
        let maxValue = nonNegativeValue(from: row.maxInput)
        if percent <= 0 || minValue <= 0 {
            return false
        }
        if maxValue > 0, maxValue < minValue {
            return false
        }
        return true
    }

    private func rowValidationMessage(for row: SetupRowState) -> String {
        let percent = nonNegativeValue(from: row.percentageInput)
        let minValue = nonNegativeValue(from: row.minInput)
        let maxValue = nonNegativeValue(from: row.maxInput)

        if percent <= 0 {
            return "Укажите основной процент больше 0."
        }
        if minValue <= 0 {
            return "Укажите минимальную сумму больше 0."
        }
        if maxValue > 0, maxValue < minValue {
            return "Максимальная сумма не может быть меньше минимальной."
        }
        return ""
    }

    private func binding(
        for index: Int,
        keyPath: WritableKeyPath<SetupRowState, String>
    ) -> Binding<String> {
        Binding(
            get: { rows[index][keyPath: keyPath] },
            set: { rows[index][keyPath: keyPath] = $0 }
        )
    }

    private func nonNegativeValue(from input: String) -> Double {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }
}

private struct SetupRowState: Identifiable, Hashable {
    let id: String
    let categoryType: ExpenseCategoryType
    let name: String
    var percentageInput: String
    var minInput: String
    var maxInput: String

    init(card: InitialSystemSetupCard) {
        id = card.id
        categoryType = card.categoryType
        name = card.name
        percentageInput = formattedSetupInput(card.defaultPercentage)
        minInput = card.defaultMinLimit.map(formattedSetupInput) ?? ""
        maxInput = card.defaultMaxLimit.map(formattedSetupInput) ?? ""
    }
}

private func formattedSetupInput(_ value: Double) -> String {
    String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
}

private struct CategorySectionData {
    let categoryType: ExpenseCategoryType
    let rowIndices: [Int]
}
