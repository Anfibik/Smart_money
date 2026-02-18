import SwiftUI

struct SubcategoryListView: View {
    @ObservedObject var budgetViewModel: BudgetViewModel
    let categoryType: ExpenseCategoryType
    let currencyCode: String

    @State private var selectedSubcategory: SubcategoryAllocation?
    @State private var expenseInput: String = ""
    @FocusState private var isExpenseFieldFocused: Bool

    private var currentCategory: CategoryAllocation? {
        budgetViewModel.distribution.categoryAllocations.first(where: { $0.type == categoryType })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let category = currentCategory {
                    ForEach(category.subcategoryAllocations) { sub in
                        Button {
                            selectedSubcategory = sub
                            expenseInput = ""
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(sub.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("Процент: \(sub.percentage, specifier: "%.1f")%")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Выделено: \(sub.allocatedAmount, format: .currency(code: currencyCode))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Потрачено: \(sub.spentAmount, format: .currency(code: currencyCode))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Остаток: \(sub.remainingAmount, format: .currency(code: currencyCode))")
                                    .font(.subheadline.bold())
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(categoryType.title)
        .sheet(item: $selectedSubcategory) { sub in
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(sub.name)
                        .font(.title3.bold())

                    TextField("Введите расход", text: $expenseInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isExpenseFieldFocused)

                    Button("Сохранить расход") {
                        let normalized = expenseInput.replacingOccurrences(of: ",", with: ".")
                        let value = Double(normalized) ?? 0
                        budgetViewModel.addExpense(
                            categoryType: categoryType,
                            subcategoryID: sub.id,
                            amount: value,
                            useBankIfNeeded: false
                        )
                        selectedSubcategory = nil
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .padding()
                .navigationTitle("Новый расход")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            selectedSubcategory = nil
                        }
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
}
