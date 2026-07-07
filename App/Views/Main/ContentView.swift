import SwiftUI

struct ContentView: View {
    @StateObject private var budgetViewModel = BudgetViewModel()
    @State private var incomeInput: String = ""
    @State private var isIncomeInputVisible = false
    @State private var isShowingInitialSetup = false
    @State private var didBootstrapInitialSetup = false
    @State private var isShowingResetSetupAlert = false
    @State private var isSideMenuOpen = false
    @State private var isShowingHistory = false
    @State private var isShowingHistoryAndStatistics = false
    @AppStorage("has_completed_start_onboarding_v2") private var hasCompletedStartOnboarding = false
    @FocusState private var isIncomeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    AppTheme.appBackground
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            incomeTopBar

                            CategoryAccordionView(
                                distribution: budgetViewModel.distribution,
                                currencyCode: budgetViewModel.settings.currencyCode,
                                lastIncomeAmount: budgetViewModel.lastIncomeAmount,
                                bankAvailableAmount: budgetViewModel.bankAvailableAmount,
                                onPayExpense: { categoryType, subcategoryID, amount, fundingStrategy in
                                    budgetViewModel.addExpense(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        amount: amount,
                                        fundingStrategy: fundingStrategy
                                    )
                                },
                                expenseCoverageRequirement: { categoryType, subcategoryID, amount in
                                    budgetViewModel.expenseCoverageRequirement(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        amount: amount
                                    )
                                },
                                expenseFundingPreview: { categoryType, subcategoryID, amount, fundingStrategy in
                                    budgetViewModel.expenseFundingPreview(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        amount: amount,
                                        fundingStrategy: fundingStrategy
                                    )
                                },
                                onPayExpenseWithAutomaticForcedCoverage: { categoryType, subcategoryID, amount, fundingStrategy in
                                    budgetViewModel.addExpenseWithAutomaticForcedCoverage(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        amount: amount,
                                        fundingStrategy: fundingStrategy
                                    )
                                },
                                onPayExpenseWithManualForcedCoverage: { categoryType, subcategoryID, amount, allocations, fundingStrategy in
                                    budgetViewModel.addExpenseWithManualForcedCoverage(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        amount: amount,
                                        allocations: allocations,
                                        fundingStrategy: fundingStrategy
                                    )
                                },
                                onAddSubcategory: { categoryType, name, iconName, percentage, minAmount, maxAmount, priority in
                                    budgetViewModel.addCustomSubcategory(
                                        categoryType: categoryType,
                                        name: name,
                                        iconName: iconName,
                                        percentage: percentage,
                                        minLimit: minAmount,
                                        maxLimit: maxAmount,
                                        priority: priority
                                    )
                                },
                                newSubcategoryCoverageRequirement: { categoryType, minAmount in
                                    budgetViewModel.newSubcategoryCoverageRequirement(
                                        categoryType: categoryType,
                                        minLimit: minAmount
                                    )
                                },
                                onAddSubcategoryWithAutomaticForcedCoverage: { categoryType, name, iconName, percentage, minAmount, maxAmount, priority in
                                    budgetViewModel.addCustomSubcategoryWithAutomaticForcedCoverage(
                                        categoryType: categoryType,
                                        name: name,
                                        iconName: iconName,
                                        percentage: percentage,
                                        minLimit: minAmount,
                                        maxLimit: maxAmount,
                                        priority: priority
                                    )
                                },
                                onAddSubcategoryWithManualForcedCoverage: { categoryType, name, iconName, percentage, minAmount, maxAmount, priority, allocations in
                                    budgetViewModel.addCustomSubcategoryWithManualForcedCoverage(
                                        categoryType: categoryType,
                                        name: name,
                                        iconName: iconName,
                                        percentage: percentage,
                                        minLimit: minAmount,
                                        maxLimit: maxAmount,
                                        priority: priority,
                                        allocations: allocations
                                    )
                                },
                                onUpdateSubcategory: { categoryType, subcategoryID, name, iconName, percentage, minAmount, maxAmount, priority in
                                    budgetViewModel.updateSubcategory(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        name: name,
                                        iconName: iconName,
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
                                },
                                onDepositFunds: { categoryType, subcategoryID, amount in
                                    budgetViewModel.transferFromBankToSubcategory(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        amount: amount
                                    )
                                }
                            )
                        }
                        .padding()
                    }
                    .disabled(isSideMenuOpen)

                    if isSideMenuOpen {
                        sideMenuOverlayColor
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                closeSideMenu()
                            }
                            .transition(.opacity)
                    }

                    SideMenuDrawerView(
                        items: sideMenuItems,
                        onSelectItem: handleSideMenuSelection,
                        onReset: {
                            closeSideMenu()
                            isShowingResetSetupAlert = true
                        }
                    )
                    .frame(width: geometry.size.width * 0.50)
                    .frame(maxHeight: .infinity)
                    .offset(x: isSideMenuOpen ? 0 : (geometry.size.width * 0.50) + 24)
                    .shadow(radius: isSideMenuOpen ? 8 : 0)
                }
                .animation(.easeInOut(duration: 0.22), value: isSideMenuOpen)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        isIncomeFieldFocused = false
                    }
                }
            }
            .navigationDestination(isPresented: $isShowingHistoryAndStatistics) {
                HistoryAndStatisticsView(budgetViewModel: budgetViewModel)
            }
            .navigationDestination(isPresented: $isShowingHistory) {
                BudgetHistoryView(budgetViewModel: budgetViewModel)
            }
        }
        .fullScreenCover(isPresented: $isShowingInitialSetup) {
            StartOnboardingFlowView { configuration in
                budgetViewModel.applyStartOnboardingConfiguration(configuration)
                hasCompletedStartOnboarding = true
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

    private var incomeTopBar: some View {
        HStack(spacing: 8) {
            Button {
                handleLeftIncomeButtonTap()
            } label: {
                Image(systemName: isIncomeInputVisible ? "xmark.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel(isIncomeInputVisible ? "Скрыть ввод дохода" : "Показать ввод дохода")
            if isIncomeInputVisible {
                TextField("Введите доход", text: $incomeInput)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isIncomeFieldFocused)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Spacer(minLength: 0)
            }

            Button {
                handleRightTopButtonTap()
            } label: {
                Image(systemName: shouldShowSubmitIncomeAction ? "checkmark.circle.fill" : "line.3.horizontal.circle.fill")
                    .font(.title2)
                    .foregroundStyle(shouldShowSubmitIncomeAction ? .green : .secondary)
            }
            .accessibilityLabel(shouldShowSubmitIncomeAction ? "Подтвердить доход" : "Открыть меню")
        }
        .animation(.easeInOut(duration: 0.22), value: isIncomeInputVisible)
        .animation(.easeInOut(duration: 0.18), value: shouldShowSubmitIncomeAction)
    }

    private var shouldShowSubmitIncomeAction: Bool {
        isIncomeInputVisible && hasIncomeDigits
    }

    private var hasIncomeDigits: Bool {
        incomeInput.unicodeScalars.contains(where: CharacterSet.decimalDigits.contains)
    }

    private var sideMenuOverlayColor: Color {
        AppTheme.sideMenuOverlay
    }

    private var sideMenuItems: [SideMenuItemDescriptor] {
        [
            SideMenuItemDescriptor(
                id: "history",
                title: "История",
                systemImage: "clock.arrow.circlepath"
            ),
            SideMenuItemDescriptor(
                id: "statistics",
                title: "Статистика",
                systemImage: "chart.bar.xaxis"
            )
        ]
    }

    private func handleLeftIncomeButtonTap() {
        if isIncomeInputVisible {
            collapseIncomeInput()
            return
        }

        closeSideMenu()
        withAnimation(.easeInOut(duration: 0.22)) {
            isIncomeInputVisible = true
        }

        DispatchQueue.main.async {
            isIncomeFieldFocused = true
        }
    }

    private func handleRightTopButtonTap() {
        if shouldShowSubmitIncomeAction {
            submitIncome()
        } else {
            toggleSideMenu()
        }
    }

    private func submitIncome() {
        let normalized = incomeInput.replacingOccurrences(of: ",", with: ".")
        let value = Double(normalized) ?? 0
        budgetViewModel.addIncome(value)
        collapseIncomeInput()
    }

    private func collapseIncomeInput() {
        isIncomeFieldFocused = false
        withAnimation(.easeInOut(duration: 0.22)) {
            isIncomeInputVisible = false
            incomeInput = ""
        }
    }

    private func toggleSideMenu() {
        isIncomeFieldFocused = false
        withAnimation(.easeInOut(duration: 0.22)) {
            isSideMenuOpen.toggle()
        }
    }

    private func closeSideMenu() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isSideMenuOpen = false
        }
    }

    private func handleSideMenuSelection(_ item: SideMenuItemDescriptor) {
        closeSideMenu()
        if item.id == "history" {
            isShowingHistory = true
        } else if item.id == "statistics" {
            isShowingHistoryAndStatistics = true
        }
    }

    private func bootstrapInitialSetupIfNeeded() {
        guard !didBootstrapInitialSetup else { return }
        didBootstrapInitialSetup = true

        if hasCompletedStartOnboarding {
            return
        }

        isShowingInitialSetup = true
    }

    private func resetInitialSetup() {
        budgetViewModel.resetToInitialSystemState()
        hasCompletedStartOnboarding = false
        isShowingInitialSetup = true
    }
}
