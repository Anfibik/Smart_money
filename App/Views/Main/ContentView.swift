import SwiftUI

enum DashboardDisplayMode: String, CaseIterable, Identifiable {
    case categories
    case statistics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categories: return "Категории"
        case .statistics: return "Статистика"
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var budgetViewModel = BudgetViewModel()
    private let installMetadataService = AppInstallMetadataService()
    @State private var incomeInput: String = ""
    @State private var isIncomeInputVisible = false
    @State private var isShowingInitialSetup = false
    @State private var didBootstrapInitialSetup = false
    @State private var isShowingResetSetupAlert = false
    @State private var isSideMenuOpen = false
    @State private var isShowingHistory = false
    @State private var isShowingHistoryAndStatistics = false
    @State private var expandedCategoryIDs: Set<UUID> = []
    @State private var dashboardDisplayMode: DashboardDisplayMode = .categories
    @State private var didInitializeCategoryExpansion = false
    @AppStorage("has_completed_start_onboarding_v2") private var hasCompletedStartOnboarding = false
    @State private var isIncomeFieldFocused = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .trailing) {
                    AppTheme.appBackground
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        incomeTopBar
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(AppTheme.appBackground)

                        ScrollView {
                            CategoryAccordionView(
                                distribution: budgetViewModel.distribution,
                                currencyCode: budgetViewModel.settings.currencyCode,
                                lastIncomeAmount: budgetViewModel.lastIncomeAmount,
                                bankAvailableAmount: budgetViewModel.bankAvailableAmount,
                                historyEvents: budgetViewModel.historyEvents,
                                expandedCategoryIDs: $expandedCategoryIDs,
                                displayMode: dashboardDisplayMode,
                                availableRecommendedCards: { categoryType in
                                    budgetViewModel.availableRecommendedCards(for: categoryType)
                                },
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
                                onAddSubcategory: { categoryType, name, iconName, percentage, minAmount, maxAmount, priority, requiresMinimumAmount in
                                    budgetViewModel.addCustomSubcategory(
                                        categoryType: categoryType,
                                        name: name,
                                        iconName: iconName,
                                        percentage: percentage,
                                        minLimit: minAmount,
                                        maxLimit: maxAmount,
                                        priority: priority,
                                        requiresMinimumAmount: requiresMinimumAmount
                                    )
                                },
                                newSubcategoryCoverageRequirement: { categoryType, minAmount in
                                    budgetViewModel.newSubcategoryCoverageRequirement(
                                        categoryType: categoryType,
                                        minLimit: minAmount
                                    )
                                },
                                onAddSubcategoryWithAutomaticForcedCoverage: { categoryType, name, iconName, percentage, minAmount, maxAmount, priority, requiresMinimumAmount in
                                    budgetViewModel.addCustomSubcategoryWithAutomaticForcedCoverage(
                                        categoryType: categoryType,
                                        name: name,
                                        iconName: iconName,
                                        percentage: percentage,
                                        minLimit: minAmount,
                                        maxLimit: maxAmount,
                                        priority: priority,
                                        requiresMinimumAmount: requiresMinimumAmount
                                    )
                                },
                                onAddSubcategoryWithManualForcedCoverage: { categoryType, name, iconName, percentage, minAmount, maxAmount, priority, requiresMinimumAmount, allocations in
                                    budgetViewModel.addCustomSubcategoryWithManualForcedCoverage(
                                        categoryType: categoryType,
                                        name: name,
                                        iconName: iconName,
                                        percentage: percentage,
                                        minLimit: minAmount,
                                        maxLimit: maxAmount,
                                        priority: priority,
                                        allocations: allocations,
                                        requiresMinimumAmount: requiresMinimumAmount
                                    )
                                },
                                onUpdateSubcategory: { categoryType, subcategoryID, name, iconName, percentage, minAmount, maxAmount, priority, requiresMinimumAmount in
                                    budgetViewModel.updateSubcategory(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        name: name,
                                        iconName: iconName,
                                        percentage: percentage,
                                        minLimit: minAmount,
                                        maxLimit: maxAmount,
                                        priority: priority,
                                        requiresMinimumAmount: requiresMinimumAmount
                                    )
                                },
                                onDeleteSubcategory: { categoryType, subcategoryID in
                                    budgetViewModel.deleteSubcategory(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID
                                    )
                                },
                                onAddRecommendedSubcategory: { systemKey in
                                    budgetViewModel.addRecommendedSubcategory(systemKey: systemKey)
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
                                },
                                onManualCardDeposit: { categoryType, subcategoryID, amount in
                                    budgetViewModel.depositToManualCard(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        amount: amount
                                    )
                                },
                                onManualCardDepositFromFreeCapital: { categoryType, subcategoryID, foreignAmount, hryvniaAmount, exchangeRate in
                                    budgetViewModel.depositToManualCardFromFreeCapital(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        foreignAmount: foreignAmount,
                                        hryvniaAmount: hryvniaAmount,
                                        exchangeRateToUAH: exchangeRate
                                    )
                                },
                                onUpdateManualCardCurrency: { categoryType, subcategoryID, currency in
                                    budgetViewModel.updateManualCardCurrency(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        currency: currency
                                    )
                                },
                                onConvertManualCardToFreeCapital: { categoryType, subcategoryID, amount, exchangeRate in
                                    budgetViewModel.convertManualCardToFreeCapital(
                                        categoryType: categoryType,
                                        subcategoryID: subcategoryID,
                                        amount: amount,
                                        exchangeRateToUAH: exchangeRate
                                    )
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 16)
                        }
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

                    if budgetViewModel.storageRecoveryReport.hasUnrecoverableData {
                        Color.black.opacity(0.72)
                            .ignoresSafeArea()

                        StorageRecoveryFailureView(
                            report: budgetViewModel.storageRecoveryReport,
                            onDiscardDamagedData: resolveUnrecoverableStorage
                        )
                        .padding(24)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .center
                        )
                    } else if budgetViewModel.storageRecoveryReport.hasRecoveredData {
                        StorageRecoveryNoticeView(
                            message: budgetViewModel.storageRecoveryReport.recoveryNoticeMessage,
                            onDismiss: budgetViewModel.acknowledgeStorageRecovery
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .top
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: isSideMenuOpen)
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
            installMetadataService.registerFirstLaunchIfNeeded()
            bootstrapInitialSetupIfNeeded()
            initializeCategoryExpansionIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            budgetViewModel.flushPendingPersistence()
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
                if isIncomeInputVisible {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppTheme.positive)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.appBackground)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(AppTheme.positive, lineWidth: 2)
                        }
                        .frame(width: 56, height: 56)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isIncomeInputVisible ? "Скрыть ввод дохода" : "Показать ввод дохода")
            if isIncomeInputVisible {
                CurrencyInput(
                    text: $incomeInput,
                    placeholder: "Введите доход",
                    currencyCode: budgetViewModel.settings.currencyCode,
                    externalFocus: $isIncomeFieldFocused
                )
                    .frame(maxWidth: .infinity)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Spacer(minLength: 8)

                Picker("Режим", selection: $dashboardDisplayMode) {
                    ForEach(DashboardDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
                .accessibilityLabel("Режим главного экрана")

                Spacer(minLength: 8)
            }

            Button {
                handleRightTopButtonTap()
            } label: {
                if shouldShowSubmitIncomeAction {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(AppTheme.positive)
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.appBackground)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(AppTheme.accent, lineWidth: 2)
                        }
                        .frame(width: 56, height: 56)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(shouldShowSubmitIncomeAction ? "Подтвердить доход" : "Открыть меню")
        }
        .animation(.easeInOut(duration: 0.22), value: isIncomeInputVisible)
        .animation(.easeInOut(duration: 0.18), value: shouldShowSubmitIncomeAction)
    }

    private var shouldShowSubmitIncomeAction: Bool {
        isIncomeInputVisible && hasIncomeDigits
    }

    private var hasIncomeDigits: Bool {
        CurrencyInputFormatter.value(from: incomeInput, allowsNegative: false) > 0
    }

    private var defaultExpandedCategoryIDs: Set<UUID> {
        Set(
            budgetViewModel.distribution.categoryAllocations
                .filter { $0.type == .essentials }
                .map(\.id)
        )
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
                title: "Бухгалтерия",
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

    private func initializeCategoryExpansionIfNeeded() {
        guard !didInitializeCategoryExpansion else { return }
        didInitializeCategoryExpansion = true

        let initialIDs = defaultExpandedCategoryIDs
        expandedCategoryIDs = initialIDs
    }

    private func handleRightTopButtonTap() {
        if shouldShowSubmitIncomeAction {
            submitIncome()
        } else {
            toggleSideMenu()
        }
    }

    private func submitIncome() {
        let value = CurrencyInputFormatter.value(from: incomeInput, allowsNegative: false)
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

        guard !budgetViewModel.storageRecoveryReport.hasUnrecoverableData else {
            return
        }

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

    private func resolveUnrecoverableStorage() {
        closeSideMenu()
        let requiresOnboarding = budgetViewModel.discardUnrecoverableStoredData()
        guard requiresOnboarding else { return }

        hasCompletedStartOnboarding = false
        isShowingInitialSetup = true
    }
}

private extension StorageRecoveryReport {
    var recoveryNoticeMessage: String {
        switch (budgetState, history) {
        case (.recoveredFromBackup, .recoveredFromBackup):
            return "Бюджет и история восстановлены из резервных копий."
        case (.recoveredFromBackup, _):
            return "Бюджет восстановлен из резервной копии."
        case (_, .recoveredFromBackup):
            return "История операций восстановлена из резервной копии."
        default:
            return "Данные восстановлены из резервной копии."
        }
    }

    var failureTitle: String {
        switch (budgetState, history) {
        case (.unrecoverable, .unrecoverable):
            return "Не удалось восстановить данные"
        case (.unrecoverable, _):
            return "Не удалось прочитать бюджет"
        default:
            return "Не удалось прочитать историю"
        }
    }

    var failureMessage: String {
        if budgetState == .unrecoverable {
            return "Основная и резервная копии бюджета повреждены. Приложение не перезаписывало их пустыми данными. Для продолжения потребуется удалить сохранённый бюджет и историю, затем пройти настройку заново."
        }

        return "Основная и резервная копии истории повреждены. Сам бюджет сохранён и не будет сброшен. Можно удалить только повреждённую историю."
    }

    var discardButtonTitle: String {
        budgetState == .unrecoverable
            ? "Сбросить и настроить заново"
            : "Удалить повреждённую историю"
    }
}

private struct StorageRecoveryNoticeView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .foregroundStyle(AppTheme.info)

            Text(message)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть сообщение")
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }
}

private struct StorageRecoveryFailureView: View {
    let report: StorageRecoveryReport
    let onDiscardDamagedData: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.fill.badge.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(AppTheme.negative)

            Text(report.failureTitle)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            Text(report.failureMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(role: .destructive, action: onDiscardDamagedData) {
                Text(report.discardButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .frame(maxWidth: 420)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
    }
}
