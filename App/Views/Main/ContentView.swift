import SwiftUI

struct ContentView: View {
    @StateObject private var budgetViewModel = BudgetViewModel()
    @State private var incomeInput: String = ""
    @State private var isShowingInitialSetup = false
    @State private var didBootstrapInitialSetup = false
    @State private var isShowingResetSetupAlert = false
    @AppStorage("has_completed_system_setup") private var hasCompletedSystemSetup = false
    @AppStorage("system_setup_payload") private var systemSetupPayload = ""
    @FocusState private var isIncomeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Spacer()
                        Button {
                            isShowingResetSetupAlert = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                        }
                        .accessibilityLabel("Сбросить первичную настройку")
                    }

                    TextField("Введите доход", text: $incomeInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isIncomeFieldFocused)

                    HStack {
                        Spacer()

                        Button("Внести") {
                            let normalized = incomeInput.replacingOccurrences(of: ",", with: ".")
                            let value = Double(normalized) ?? 0

                            budgetViewModel.addIncome(value)

                            incomeInput = ""
                            isIncomeFieldFocused = false
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()
                    }


                    CategoryAccordionView(
                        distribution: budgetViewModel.distribution,
                        currencyCode: budgetViewModel.settings.currencyCode,
                        lastIncomeAmount: budgetViewModel.lastIncomeAmount,
                        bankAvailableAmount: budgetViewModel.bankAvailableAmount,
                        onPayExpense: { categoryType, subcategoryID, amount, useBankIfNeeded in
                            budgetViewModel.addExpense(
                                categoryType: categoryType,
                                subcategoryID: subcategoryID,
                                amount: amount,
                                useBankIfNeeded: useBankIfNeeded
                            )
                        },
                        onAddSubcategory: { categoryType, name, percentage, minAmount, maxAmount, priority in
                            budgetViewModel.addCustomSubcategory(
                                categoryType: categoryType,
                                name: name,
                                percentage: percentage,
                                minLimit: minAmount,
                                maxLimit: maxAmount,
                                priority: priority
                            )
                        },
                        onUpdateSubcategory: { categoryType, subcategoryID, name, percentage, minAmount, maxAmount, priority in
                            budgetViewModel.updateSubcategory(
                                categoryType: categoryType,
                                subcategoryID: subcategoryID,
                                name: name,
                                percentage: percentage,
                                minLimit: minAmount,
                                maxLimit: maxAmount,
                                priority: priority
                            )
                        },
                        onDeleteSubcategory: { categoryType, subcategoryID in
                            budgetViewModel.deleteSubcategory(
                                categoryType: categoryType,
                                subcategoryID: subcategoryID
                            )
                        },
                        onWithdrawFunds: { categoryType, subcategoryID, amount in
                            budgetViewModel.transferFromSubcategoryToBank(
                                categoryType: categoryType,
                                subcategoryID: subcategoryID,
                                amount: amount
                            )
                        }
                    )
                }
                .padding()
            }

            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isIncomeFieldFocused = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingInitialSetup) {
            InitialSystemSetupView(
                cards: initialSystemSetupCards
            ) { setups in
                budgetViewModel.applySystemSubcategorySetup(setups)
                saveSystemSetupPayload(setups)
                hasCompletedSystemSetup = true
                isShowingInitialSetup = false
            }
            .interactiveDismissDisabled(true)
        }
        .onAppear {
            bootstrapInitialSetupIfNeeded()
        }
        .alert("Сброс первичной настройки", isPresented: $isShowingResetSetupAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) {
                resetInitialSetup()
            }
        } message: {
            Text("Системные карточки нужно будет настроить заново.")
        }
    }

    private var initialSystemSetupCards: [InitialSystemSetupCard] {
        budgetViewModel.settings.categories.flatMap { category in
            category.subcategories
                .filter(\.isSystem)
                .map { subcategory in
                    InitialSystemSetupCard(
                        categoryType: category.type,
                        name: subcategory.name,
                        defaultPercentage: subcategory.percentage,
                        defaultMinLimit: subcategory.minLimit,
                        defaultMaxLimit: subcategory.maxLimit
                    )
                }
        }
    }

    private func bootstrapInitialSetupIfNeeded() {
        guard !didBootstrapInitialSetup else { return }
        didBootstrapInitialSetup = true

        if hasCompletedSystemSetup {
            if let data = systemSetupPayload.data(using: .utf8),
               let setups = try? JSONDecoder().decode([SystemSubcategorySetup].self, from: data),
               !setups.isEmpty {
                budgetViewModel.applySystemSubcategorySetup(setups)
            }
            return
        }

        isShowingInitialSetup = true
    }

    private func saveSystemSetupPayload(_ setups: [SystemSubcategorySetup]) {
        guard let data = try? JSONEncoder().encode(setups),
              let payload = String(data: data, encoding: .utf8) else {
            return
        }
        systemSetupPayload = payload
    }

    private func resetInitialSetup() {
        budgetViewModel.resetToInitialSystemState()
        hasCompletedSystemSetup = false
        systemSetupPayload = ""
        isShowingInitialSetup = true
    }
}
