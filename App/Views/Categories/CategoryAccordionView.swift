import Foundation
import SwiftUI

struct CategoryAccordionView: View {
    let distribution: BudgetDistribution
    let currencyCode: String
    let lastIncomeAmount: Double
    let bankAvailableAmount: Double
    let historyEvents: [BudgetHistoryEvent]
    @Binding var expandedCategoryIDs: Set<UUID>
    let displayMode: DashboardDisplayMode
    let availableRecommendedCards: (ExpenseCategoryType) -> [RecommendedCardTemplate]
    let onPayExpense: (ExpenseCategoryType, UUID, Double, ExpenseFundingStrategy) -> Void
    let expenseCoverageRequirement: (ExpenseCategoryType, UUID, Double) -> CategoryCoverageRequirement?
    let expenseFundingPreview: (ExpenseCategoryType, UUID, Double, ExpenseFundingStrategy) -> ExpenseFundingPreview?
    let onPayExpenseWithAutomaticForcedCoverage: (ExpenseCategoryType, UUID, Double, ExpenseFundingStrategy) -> Void
    let onPayExpenseWithManualForcedCoverage: (ExpenseCategoryType, UUID, Double, [UUID: Double], ExpenseFundingStrategy) -> Void
    let onAddSubcategory: (
        ExpenseCategoryType,
        String,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel,
        Bool
    ) -> Result<UUID, AddSubcategoryError>
    let newSubcategoryCoverageRequirement: (ExpenseCategoryType, Double) -> CategoryCoverageRequirement?
    let onAddSubcategoryWithAutomaticForcedCoverage: (
        ExpenseCategoryType,
        String,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel,
        Bool
    ) -> Result<UUID, AddSubcategoryError>
    let onAddSubcategoryWithManualForcedCoverage: (
        ExpenseCategoryType,
        String,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel,
        Bool,
        [UUID: Double]
    ) -> Result<UUID, AddSubcategoryError>
    let onUpdateSubcategory: (
        ExpenseCategoryType,
        UUID,
        String,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel,
        Bool
    ) -> Void
    let onDeleteSubcategory: (ExpenseCategoryType, UUID) -> Void
    let onAddRecommendedSubcategory: (SystemSubcategoryKey) -> Void
    let onWithdrawFunds: (ExpenseCategoryType, UUID, Double) -> Void
    let onDepositFunds: (ExpenseCategoryType, UUID, Double) -> Void
    let onManualCardDeposit: (ExpenseCategoryType, UUID, Double) -> Void
    let onManualCardDepositFromFreeCapital: (
        ExpenseCategoryType,
        UUID,
        Double,
        Double,
        Double
    ) -> Bool
    let onUpdateManualCardCurrency: (ExpenseCategoryType, UUID, ForeignCurrencyType) -> Void
    let onConvertManualCardToFreeCapital: (ExpenseCategoryType, UUID, Double, Double) -> Void

    @State private var expenseTarget: ExpenseTarget?
    @State private var addSubcategoryTarget: AddSubcategoryTarget?
    @State private var editSubcategoryTarget: EditSubcategoryTarget?
    @State private var expenseInput: String = ""
    @State private var expenseFundingStrategy: ExpenseFundingStrategy = .categoryFirst
    @State private var subcategoryNameInput: String = ""
    @State private var subcategoryPercentInput: String = ""
    @State private var subcategoryMinAmountInput: String = ""
    @State private var subcategoryMaxAmountInput: String = ""
    @State private var subcategoryRequiresMinimumAmount = false
    @State private var subcategoryIconName: String = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
    @State private var editNameInput: String = ""
    @State private var editPercentInput: String = ""
    @State private var editMinAmountInput: String = ""
    @State private var editMaxAmountInput: String = ""
    @State private var editRequiresMinimumAmount = false
    @State private var editIconName: String = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
    @State private var withdrawAmountInput: String = ""
    @State private var depositAmountInput: String = ""
    @State private var depositHryvniaAmountInput: String = ""
    @State private var depositExchangeRateInput: String = ""
    @State private var depositUsesFreeCapital = false
    @State private var editForeignCurrency: ForeignCurrencyType = .usd
    @State private var suppressTapAfterLongPress: Bool = false
    @State private var statisticsPeriod: DashboardStatisticsPeriod = .month
    @State private var addSubcategoryError: AddSubcategoryError?

    init(
        distribution: BudgetDistribution,
        currencyCode: String,
        lastIncomeAmount: Double,
        bankAvailableAmount: Double,
        historyEvents: [BudgetHistoryEvent],
        expandedCategoryIDs: Binding<Set<UUID>>,
        displayMode: DashboardDisplayMode,
        availableRecommendedCards: @escaping (ExpenseCategoryType) -> [RecommendedCardTemplate],
        onPayExpense: @escaping (ExpenseCategoryType, UUID, Double, ExpenseFundingStrategy) -> Void,
        expenseCoverageRequirement: @escaping (ExpenseCategoryType, UUID, Double) -> CategoryCoverageRequirement?,
        expenseFundingPreview: @escaping (ExpenseCategoryType, UUID, Double, ExpenseFundingStrategy) -> ExpenseFundingPreview?,
        onPayExpenseWithAutomaticForcedCoverage: @escaping (ExpenseCategoryType, UUID, Double, ExpenseFundingStrategy) -> Void,
        onPayExpenseWithManualForcedCoverage: @escaping (ExpenseCategoryType, UUID, Double, [UUID: Double], ExpenseFundingStrategy) -> Void,
        onAddSubcategory: @escaping (
            ExpenseCategoryType,
            String,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel,
            Bool
        ) -> Result<UUID, AddSubcategoryError>,
        newSubcategoryCoverageRequirement: @escaping (ExpenseCategoryType, Double) -> CategoryCoverageRequirement?,
        onAddSubcategoryWithAutomaticForcedCoverage: @escaping (
            ExpenseCategoryType,
            String,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel,
            Bool
        ) -> Result<UUID, AddSubcategoryError>,
        onAddSubcategoryWithManualForcedCoverage: @escaping (
            ExpenseCategoryType,
            String,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel,
            Bool,
            [UUID: Double]
        ) -> Result<UUID, AddSubcategoryError>,
        onUpdateSubcategory: @escaping (
            ExpenseCategoryType,
            UUID,
            String,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel,
            Bool
        ) -> Void,
        onDeleteSubcategory: @escaping (ExpenseCategoryType, UUID) -> Void,
        onAddRecommendedSubcategory: @escaping (SystemSubcategoryKey) -> Void,
        onWithdrawFunds: @escaping (ExpenseCategoryType, UUID, Double) -> Void,
        onDepositFunds: @escaping (ExpenseCategoryType, UUID, Double) -> Void,
        onManualCardDeposit: @escaping (ExpenseCategoryType, UUID, Double) -> Void,
        onManualCardDepositFromFreeCapital: @escaping (
            ExpenseCategoryType,
            UUID,
            Double,
            Double,
            Double
        ) -> Bool,
        onUpdateManualCardCurrency: @escaping (ExpenseCategoryType, UUID, ForeignCurrencyType) -> Void,
        onConvertManualCardToFreeCapital: @escaping (ExpenseCategoryType, UUID, Double, Double) -> Void
    ) {
        self.distribution = distribution
        self.currencyCode = currencyCode
        self.lastIncomeAmount = lastIncomeAmount
        self.bankAvailableAmount = bankAvailableAmount
        self.historyEvents = historyEvents
        _expandedCategoryIDs = expandedCategoryIDs
        self.displayMode = displayMode
        self.availableRecommendedCards = availableRecommendedCards
        self.onPayExpense = onPayExpense
        self.expenseCoverageRequirement = expenseCoverageRequirement
        self.expenseFundingPreview = expenseFundingPreview
        self.onPayExpenseWithAutomaticForcedCoverage = onPayExpenseWithAutomaticForcedCoverage
        self.onPayExpenseWithManualForcedCoverage = onPayExpenseWithManualForcedCoverage
        self.onAddSubcategory = onAddSubcategory
        self.newSubcategoryCoverageRequirement = newSubcategoryCoverageRequirement
        self.onAddSubcategoryWithAutomaticForcedCoverage = onAddSubcategoryWithAutomaticForcedCoverage
        self.onAddSubcategoryWithManualForcedCoverage = onAddSubcategoryWithManualForcedCoverage
        self.onUpdateSubcategory = onUpdateSubcategory
        self.onDeleteSubcategory = onDeleteSubcategory
        self.onAddRecommendedSubcategory = onAddRecommendedSubcategory
        self.onWithdrawFunds = onWithdrawFunds
        self.onDepositFunds = onDepositFunds
        self.onManualCardDeposit = onManualCardDeposit
        self.onManualCardDepositFromFreeCapital = onManualCardDepositFromFreeCapital
        self.onUpdateManualCardCurrency = onUpdateManualCardCurrency
        self.onConvertManualCardToFreeCapital = onConvertManualCardToFreeCapital

    }

    private var hasExpandedCategory: Bool {
        distribution.categoryAllocations.contains { expandedCategoryIDs.contains($0.id) }
    }

    private var isStatisticsMode: Bool {
        displayMode == .statistics
    }

    var body: some View {
        VStack(spacing: 8) {
            if isStatisticsMode {
                VStack(alignment: .leading, spacing: 12) {
                    Text(currentMonthTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 8) {
                        categoryRows

                        BankSummaryView(
                            bankAvailableAmount: bankAvailableAmount,
                            lines: distribution.lastBankAutoDistributions,
                            currencyCode: currencyCode
                        )
                    }
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.mutedIcon.opacity(0.28), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            } else {
                categoryRows
            }

            if !isStatisticsMode {
                BankSummaryView(
                    bankAvailableAmount: bankAvailableAmount,
                    lines: distribution.lastBankAutoDistributions,
                    currencyCode: currencyCode
                )
            }

            if isStatisticsMode {
                DashboardPeriodStatisticsView(
                    period: $statisticsPeriod,
                    statistics: BudgetStatisticsService().buildDashboardStatistics(
                        from: historyEvents,
                        balanceState: dashboardBalanceState,
                        currencyCode: currencyCode,
                        period: statisticsPeriod
                    ),
                    currencyCode: currencyCode
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: displayMode)
        .animation(.easeInOut(duration: 0.2), value: hasExpandedCategory)
        .sheet(item: $expenseTarget) { target in
            let coverageRequirement = expenseCoverageRequirement(
                target.categoryType,
                target.subcategoryID,
                nonNegativeValue(from: expenseInput)
            )
            let fundingPreview = expenseFundingPreview(
                target.categoryType,
                target.subcategoryID,
                nonNegativeValue(from: expenseInput),
                expenseFundingStrategy
            )

            let editTarget = target.editTarget
            let availableForCard = maxAllowedPercentForEdit(target: editTarget)
            let availableMoneyForCard = maxAllowedMoneyForEdit(target: editTarget)
            let currentRemaining = currentRemainingForEdit(target: editTarget)
            let currentMaxLimit = currentMaxLimitForEdit(target: editTarget)

            ExpenseSheetView(
                target: target,
                currencyCode: target.currencyCode,
                currentCardAmount: currentRemaining,
                bankAvailableAmount: target.isManualOnly ? 0 : bankAvailableAmount,
                isManualOnly: target.isManualOnly,
                coverageRequirement: coverageRequirement,
                fundingPreview: fundingPreview,
                managementDestination: EditSubcategorySheetView(
                    target: editTarget,
                    currencyCode: editTarget.currencyCode,
                    bankAvailableAmount: bankAvailableAmount,
                    availableForCard: availableForCard,
                    availableMoneyForCard: availableMoneyForCard,
                    currentRemaining: currentRemaining,
                    currentMaxLimit: currentMaxLimit,
                    isEmbeddedInNavigationStack: true,
                    editNameInput: $editNameInput,
                    editPercentInput: $editPercentInput,
                    editMinAmountInput: $editMinAmountInput,
                    editMaxAmountInput: $editMaxAmountInput,
                    editRequiresMinimumAmount: $editRequiresMinimumAmount,
                    editIconName: $editIconName,
                    withdrawAmountInput: $withdrawAmountInput,
                    depositAmountInput: $depositAmountInput,
                    depositHryvniaAmountInput: $depositHryvniaAmountInput,
                    depositExchangeRateInput: $depositExchangeRateInput,
                    depositUsesFreeCapital: $depositUsesFreeCapital,
                    editForeignCurrency: $editForeignCurrency,
                    canSave: canSaveEditedSubcategory(target: editTarget),
                    onSave: {
                        saveEditedSubcategory(target: editTarget, closesStandaloneSheet: false)
                    },
                    onWithdraw: {
                        withdrawFromEditedSubcategory(target: editTarget)
                    },
                    onDeposit: {
                        depositIntoEditedSubcategory(target: editTarget)
                    },
                    onCurrencyChange: { currency in
                        onUpdateManualCardCurrency(
                            editTarget.categoryType,
                            editTarget.subcategoryID,
                            currency
                        )
                    },
                    onConvertToFreeCapital: { amount, exchangeRate in
                        onConvertManualCardToFreeCapital(
                            editTarget.categoryType,
                            editTarget.subcategoryID,
                            amount,
                            exchangeRate
                        )
                    },
                    onDelete: editTarget.isRequired ? nil : {
                        onDeleteSubcategory(editTarget.categoryType, editTarget.subcategoryID)
                        expenseTarget = nil
                    },
                    onCancel: {}
                ),
                expenseInput: $expenseInput,
                fundingStrategy: $expenseFundingStrategy,
                onPay: { amount, fundingStrategy in
                    onPayExpense(target.categoryType, target.subcategoryID, amount, fundingStrategy)
                    expenseTarget = nil
                },
                onAutoForcedPay: { amount, fundingStrategy in
                    onPayExpenseWithAutomaticForcedCoverage(target.categoryType, target.subcategoryID, amount, fundingStrategy)
                    expenseTarget = nil
                },
                onManualForcedPay: { amount, allocations, fundingStrategy in
                    onPayExpenseWithManualForcedCoverage(target.categoryType, target.subcategoryID, amount, allocations, fundingStrategy)
                    expenseTarget = nil
                },
                onConvertToFreeCapital: { amount, exchangeRate in
                    onConvertManualCardToFreeCapital(
                        target.categoryType,
                        target.subcategoryID,
                        amount,
                        exchangeRate
                    )
                    expenseTarget = nil
                },
                onCancel: {
                    expenseTarget = nil
                }
            )
        }
        .sheet(item: $addSubcategoryTarget) { target in
            let freePercent = maxAllowedPercentForAdd(categoryType: target.type)
            let freeMoney = maxAllowedMoneyForAdd(categoryType: target.type)
            let coverageRequirement = newSubcategoryCoverageRequirement(
                target.type,
                nonNegativeValue(from: subcategoryMinAmountInput)
            )

            AddSubcategorySheetView(
                target: target,
                currencyCode: currencyCode,
                bankAvailableAmount: bankAvailableAmount,
                freePercent: freePercent,
                freeMoney: freeMoney,
                coverageRequirement: coverageRequirement,
                recommendedCards: availableRecommendedCards(target.type),
                subcategoryNameInput: $subcategoryNameInput,
                subcategoryPercentInput: $subcategoryPercentInput,
                subcategoryMinAmountInput: $subcategoryMinAmountInput,
                subcategoryMaxAmountInput: $subcategoryMaxAmountInput,
                subcategoryRequiresMinimumAmount: $subcategoryRequiresMinimumAmount,
                subcategoryIconName: $subcategoryIconName,
                canCreate: canCreateSubcategory,
                onCreate: {
                    createSubcategory(for: target)
                },
                onCreateWithAutomaticForcedCoverage: {
                    createSubcategoryWithAutomaticForcedCoverage(for: target)
                },
                onCreateWithManualForcedCoverage: { allocations in
                    createSubcategoryWithManualForcedCoverage(for: target, allocations: allocations)
                },
                onAddRecommendedCard: onAddRecommendedSubcategory,
                onCancel: {
                    addSubcategoryTarget = nil
                }
            )
        }
        .sheet(item: $editSubcategoryTarget) { target in
            let availableForCard = maxAllowedPercentForEdit(target: target)
            let availableMoneyForCard = maxAllowedMoneyForEdit(target: target)
            let currentRemaining = currentRemainingForEdit(target: target)
            let currentMaxLimit = currentMaxLimitForEdit(target: target)

            EditSubcategorySheetView(
                target: target,
                currencyCode: target.currencyCode,
                bankAvailableAmount: bankAvailableAmount,
                availableForCard: availableForCard,
                availableMoneyForCard: availableMoneyForCard,
                currentRemaining: currentRemaining,
                currentMaxLimit: currentMaxLimit,
                isEmbeddedInNavigationStack: false,
                editNameInput: $editNameInput,
                editPercentInput: $editPercentInput,
                editMinAmountInput: $editMinAmountInput,
                editMaxAmountInput: $editMaxAmountInput,
                editRequiresMinimumAmount: $editRequiresMinimumAmount,
                editIconName: $editIconName,
                withdrawAmountInput: $withdrawAmountInput,
                depositAmountInput: $depositAmountInput,
                depositHryvniaAmountInput: $depositHryvniaAmountInput,
                depositExchangeRateInput: $depositExchangeRateInput,
                depositUsesFreeCapital: $depositUsesFreeCapital,
                editForeignCurrency: $editForeignCurrency,
                canSave: canSaveEditedSubcategory(target: target),
                onSave: {
                    saveEditedSubcategory(target: target)
                },
                onWithdraw: {
                    withdrawFromEditedSubcategory(target: target)
                },
                onDeposit: {
                    depositIntoEditedSubcategory(target: target)
                },
                onCurrencyChange: { currency in
                    onUpdateManualCardCurrency(
                        target.categoryType,
                        target.subcategoryID,
                        currency
                    )
                },
                onConvertToFreeCapital: { amount, exchangeRate in
                    onConvertManualCardToFreeCapital(
                        target.categoryType,
                        target.subcategoryID,
                        amount,
                        exchangeRate
                    )
                },
                onDelete: target.isRequired ? nil : {
                    onDeleteSubcategory(target.categoryType, target.subcategoryID)
                    editSubcategoryTarget = nil
                },
                onCancel: {
                    editSubcategoryTarget = nil
                }
            )
        }
        .alert(item: $addSubcategoryError) { error in
            Alert(
                title: Text("Не удалось создать карточку"),
                message: Text(error.userMessage),
                dismissButton: .default(Text("ОК"))
            )
        }
    }

    @ViewBuilder
    private var categoryRows: some View {
        ForEach(distribution.categoryAllocations) { category in
            let automaticCards = category.subcategoryAllocations.filter(\.participatesInAutomaticAllocation)
            let categoryRemaining = automaticCards.reduce(0) { $0 + $1.remainingAmount }
            let categoryMonthlyIncome = automaticCards.reduce(0) { $0 + $1.monthlyIncomeAmount }
            let categoryMonthlyExpense = automaticCards.reduce(0) { $0 + $1.monthlyExpenseAmount }
            let categoryMonthlyOutgoing = automaticCards.reduce(0) { $0 + $1.monthlyOtherOutgoingAmount }
            let categoryPreviousMonthBalance = max(
                0,
                categoryRemaining
                    - categoryMonthlyIncome
                    + categoryMonthlyExpense
                    + categoryMonthlyOutgoing
            )
            let isCategoryExpanded = isExpanded(category.id)

            VStack(spacing: 0) {
                CategoryHeaderView(
                    category: category,
                    currencyCode: currencyCode,
                    categoryRemaining: categoryRemaining,
                    categoryMonthlyExpense: categoryMonthlyExpense,
                    categoryMonthlyIncome: categoryMonthlyIncome,
                    categoryPreviousMonthBalance: categoryPreviousMonthBalance,
                    isExpanded: isCategoryExpanded,
                    useCompactLayout: !isStatisticsMode,
                    isInteractive: !isStatisticsMode,
                    onTap: { toggle(categoryID: category.id) }
                )

                if !isStatisticsMode && isCategoryExpanded {
                    CategoryExpandedContentView(
                        category: category,
                        currencyCode: currencyCode,
                        canAddSubcategory: maxAllowedPercentForAdd(categoryType: category.type) > 0,
                        onSubcategoryTap: { subcategory in
                            guard !suppressTapAfterLongPress else { return }
                            openExpenseSheet(for: category.type, subcategory: subcategory)
                        },
                        onSubcategoryLongPress: { subcategory in
                            suppressTapAfterLongPress = true
                            openEditSubcategorySheet(for: category.type, subcategory: subcategory)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                suppressTapAfterLongPress = false
                            }
                        },
                        onAddTap: {
                            openAddSubcategorySheet(for: category)
                        }
                    )
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                        )
                    )
                }
            }
            .background(AppTheme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var currentMonthTitle: String {
        let locale = Locale(identifier: "ru_RU")
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date()).capitalized(with: locale)
    }

    private var dashboardBalanceState: DashboardBalanceState {
        DashboardBalanceState(
            bankAmount: distribution.bankAmount,
            cards: distribution.categoryAllocations
                .flatMap(\.subcategoryAllocations)
                .map { subcategory in
                    DashboardCardBalance(
                        systemKey: subcategory.systemKey,
                        currencyCode: subcategory.balanceCurrencyCode ?? currencyCode,
                        remainingAmount: subcategory.remainingAmount,
                        maxLimit: subcategory.maxLimit,
                        minLimit: subcategory.minLimit,
                        spentAmount: subcategory.spentAmount
                    )
                }
        )
    }

    private func isExpanded(_ id: UUID) -> Bool {
        expandedCategoryIDs.contains(id)
    }

    private func toggle(categoryID: UUID) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            if expandedCategoryIDs.contains(categoryID) {
                expandedCategoryIDs.remove(categoryID)
            } else {
                expandedCategoryIDs.insert(categoryID)
            }
        }
    }
    private var canCreateSubcategory: Bool {
        guard let target = addSubcategoryTarget else { return false }
        let normalizedName = subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPercent = nonNegativeValue(from: subcategoryPercentInput)
        let normalizedMinAmount = nonNegativeValue(from: subcategoryMinAmountInput)
        let freePercent = maxAllowedPercentForAdd(categoryType: target.type)
        let coverageRequirement = newSubcategoryCoverageRequirement(target.type, normalizedMinAmount)
        return !normalizedName.isEmpty
            && normalizedPercent > 0
            && normalizedPercent <= freePercent
            && (!subcategoryRequiresMinimumAmount || normalizedMinAmount > 0)
            && (coverageRequirement?.canCover != false)
    }

    private func canSaveEditedSubcategory(target: EditSubcategoryTarget) -> Bool {
        if target.isManualOnly {
            return true
        }
        let normalizedName = editNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPercent = nonNegativeValue(from: editPercentInput)
        let normalizedMinAmount = nonNegativeValue(from: editMinAmountInput)
        let availableForCard = maxAllowedPercentForEdit(target: target)
        return !normalizedName.isEmpty
            && normalizedPercent > 0
            && normalizedPercent <= availableForCard
            && (!editRequiresMinimumAmount || normalizedMinAmount > 0)
    }

    private func openExpenseSheet(for categoryType: ExpenseCategoryType, subcategory: SubcategoryAllocation) {
        let editTarget = prepareEditState(for: categoryType, subcategory: subcategory)
        expenseTarget = ExpenseTarget(
            categoryType: categoryType,
            subcategoryID: subcategory.id,
            subcategoryName: subcategory.name,
            currencyCode: subcategory.balanceCurrencyCode ?? currencyCode,
            editTarget: editTarget
        )
        expenseInput = ""
        expenseFundingStrategy = .categoryFirst
    }

    private func openEditSubcategorySheet(for categoryType: ExpenseCategoryType, subcategory: SubcategoryAllocation) {
        editSubcategoryTarget = prepareEditState(for: categoryType, subcategory: subcategory)
    }

    private func prepareEditState(
        for categoryType: ExpenseCategoryType,
        subcategory: SubcategoryAllocation
    ) -> EditSubcategoryTarget {
        editNameInput = subcategory.name
        editIconName = subcategory.iconName
        editRequiresMinimumAmount = subcategory.requiresMinimumAmount
        editPercentInput = String(format: "%.2f", subcategory.basePercentage).replacingOccurrences(of: ".00", with: "")
        if let minLimit = subcategory.minLimit, minLimit > 0 {
            editMinAmountInput = String(format: "%.2f", minLimit).replacingOccurrences(of: ".00", with: "")
        } else {
            editMinAmountInput = ""
        }
        if let maxLimit = subcategory.maxLimit, maxLimit > 0 {
            editMaxAmountInput = String(format: "%.2f", maxLimit).replacingOccurrences(of: ".00", with: "")
        } else {
            editMaxAmountInput = ""
        }
        withdrawAmountInput = ""
        depositAmountInput = ""
        depositHryvniaAmountInput = ""
        depositExchangeRateInput = ""
        depositUsesFreeCapital = false
        editForeignCurrency = ForeignCurrencyType(rawValue: subcategory.balanceCurrencyCode ?? "") ?? .usd
        return EditSubcategoryTarget(
            subcategoryID: subcategory.id,
            categoryType: categoryType,
            categoryTitle: categoryType.title,
            subcategoryName: subcategory.name,
            isSystem: subcategory.isSystem,
            isRequired: subcategory.isRequired,
            minimumRequirementIsLocked: subcategory.systemKey?.requiresPermanentMinimumAmount == true,
            fundingMode: subcategory.fundingMode,
            currencyCode: subcategory.balanceCurrencyCode ?? currencyCode
        )
    }

    private func openAddSubcategorySheet(for category: CategoryAllocation) {
        subcategoryNameInput = ""
        subcategoryPercentInput = ""
        subcategoryMinAmountInput = ""
        subcategoryMaxAmountInput = ""
        subcategoryRequiresMinimumAmount = false
        subcategoryIconName = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
        addSubcategoryTarget = AddSubcategoryTarget(id: category.id, type: category.type, title: category.type.title)
    }

    private func createSubcategory(for target: AddSubcategoryTarget) {
        let name = subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let mainPercent = nonNegativeValue(from: subcategoryPercentInput)
        let freePercent = maxAllowedPercentForAdd(categoryType: target.type)
        let minAmount = nonNegativeValue(from: subcategoryMinAmountInput)
        let coverageRequirement = newSubcategoryCoverageRequirement(target.type, minAmount)
        guard !name.isEmpty,
              mainPercent > 0,
              mainPercent <= freePercent,
              (!subcategoryRequiresMinimumAmount || minAmount > 0),
              coverageRequirement == nil else { return }

        let maxAmount = nonNegativeValue(from: subcategoryMaxAmountInput)

        handleAddSubcategoryResult(onAddSubcategory(
            target.type,
            name,
            subcategoryIconName,
            mainPercent,
            minAmount,
            maxAmount,
            .low,
            subcategoryRequiresMinimumAmount
        ))
    }

    private func createSubcategoryWithAutomaticForcedCoverage(for target: AddSubcategoryTarget) {
        let name = subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let mainPercent = nonNegativeValue(from: subcategoryPercentInput)
        let freePercent = maxAllowedPercentForAdd(categoryType: target.type)
        let minAmount = nonNegativeValue(from: subcategoryMinAmountInput)
        guard !name.isEmpty,
              mainPercent > 0,
              mainPercent <= freePercent,
              minAmount > 0 else { return }

        let coverageRequirement = newSubcategoryCoverageRequirement(target.type, minAmount)
        guard coverageRequirement?.canCover == true else { return }

        let maxAmount = nonNegativeValue(from: subcategoryMaxAmountInput)
        handleAddSubcategoryResult(onAddSubcategoryWithAutomaticForcedCoverage(
            target.type,
            name,
            subcategoryIconName,
            mainPercent,
            minAmount,
            maxAmount,
            .low,
            subcategoryRequiresMinimumAmount
        ))
    }

    private func createSubcategoryWithManualForcedCoverage(
        for target: AddSubcategoryTarget,
        allocations: [UUID: Double]
    ) {
        let name = subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let mainPercent = nonNegativeValue(from: subcategoryPercentInput)
        let freePercent = maxAllowedPercentForAdd(categoryType: target.type)
        let minAmount = nonNegativeValue(from: subcategoryMinAmountInput)
        guard !name.isEmpty,
              mainPercent > 0,
              mainPercent <= freePercent,
              minAmount > 0 else { return }

        let coverageRequirement = newSubcategoryCoverageRequirement(target.type, minAmount)
        guard coverageRequirement?.canCover == true else { return }

        let maxAmount = nonNegativeValue(from: subcategoryMaxAmountInput)
        handleAddSubcategoryResult(onAddSubcategoryWithManualForcedCoverage(
            target.type,
            name,
            subcategoryIconName,
            mainPercent,
            minAmount,
            maxAmount,
            .low,
            subcategoryRequiresMinimumAmount,
            allocations
        ))
    }

    private func handleAddSubcategoryResult(_ result: Result<UUID, AddSubcategoryError>) {
        switch result {
        case .success:
            addSubcategoryTarget = nil
        case .failure(let error):
            addSubcategoryError = error
        }
    }

    private func saveEditedSubcategory(
        target: EditSubcategoryTarget,
        closesStandaloneSheet: Bool = true
    ) {
        if target.isManualOnly {
            onUpdateManualCardCurrency(target.categoryType, target.subcategoryID, editForeignCurrency)
            if closesStandaloneSheet {
                editSubcategoryTarget = nil
            }
            return
        }

        let name = editNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let mainPercent = nonNegativeValue(from: editPercentInput)
        let availableForCard = maxAllowedPercentForEdit(target: target)
        let minAmount = nonNegativeValue(from: editMinAmountInput)
        guard !name.isEmpty,
              mainPercent > 0,
              mainPercent <= availableForCard,
              (!editRequiresMinimumAmount || minAmount > 0) else { return }

        let maxAmount = nonNegativeValue(from: editMaxAmountInput)

        onUpdateSubcategory(
            target.categoryType,
            target.subcategoryID,
            name,
            editIconName,
            mainPercent,
            minAmount,
            maxAmount,
            .low,
            editRequiresMinimumAmount
        )
        if closesStandaloneSheet {
            editSubcategoryTarget = nil
        }
    }

    private func withdrawFromEditedSubcategory(target: EditSubcategoryTarget) {
        let requested = nonNegativeValue(from: withdrawAmountInput)
        let currentRemaining = currentRemainingForEdit(target: target)
        let maxWithdrawable = currentRemaining

        guard requested > 0, requested <= maxWithdrawable + 0.0001 else { return }

        onWithdrawFunds(target.categoryType, target.subcategoryID, requested)
        withdrawAmountInput = ""
    }

    private func depositIntoEditedSubcategory(target: EditSubcategoryTarget) {
        let requested = nonNegativeValue(from: depositAmountInput)
        guard requested > 0 else { return }

        if target.isManualOnly {
            if depositUsesFreeCapital {
                let hryvniaAmount = nonNegativeValue(from: depositHryvniaAmountInput)
                let exchangeRate = nonNegativeValue(from: depositExchangeRateInput)
                guard exchangeRate > 0,
                      hryvniaAmount > 0,
                      hryvniaAmount <= bankAvailableAmount + 0.0001 else {
                    return
                }

                let succeeded = onManualCardDepositFromFreeCapital(
                    target.categoryType,
                    target.subcategoryID,
                    requested,
                    hryvniaAmount,
                    exchangeRate
                )
                guard succeeded else { return }
                depositAmountInput = ""
                depositHryvniaAmountInput = ""
                return
            }

            onManualCardDeposit(target.categoryType, target.subcategoryID, requested)
            depositAmountInput = ""
            return
        }

        let currentRemaining = currentRemainingForEdit(target: target)
        let maxLimit = currentMaxLimitForEdit(target: target)
        let allowedByMax: Double
        if let maxLimit, maxLimit > 0 {
            allowedByMax = max(0, maxLimit - currentRemaining)
        } else {
            allowedByMax = bankAvailableAmount
        }
        let maxDepositable = max(0, min(bankAvailableAmount, allowedByMax))

        guard requested <= maxDepositable + 0.0001 else { return }

        onDepositFunds(target.categoryType, target.subcategoryID, requested)
        depositAmountInput = ""
    }

    private func nonNegativeValue(from input: String) -> Double {
        CurrencyInputFormatter.value(from: input, allowsNegative: false)
    }

    private func maxAllowedPercentForAdd(categoryType: ExpenseCategoryType) -> Double {
        guard let category = distribution.categoryAllocations.first(where: { $0.type == categoryType }) else { return 0 }
        let total = category.subcategoryAllocations.reduce(0) { $0 + $1.basePercentage }
        return max(0, 100 - total)
    }

    private func maxAllowedPercentForEdit(target: EditSubcategoryTarget) -> Double {
        guard let category = distribution.categoryAllocations.first(where: { $0.type == target.categoryType }) else { return 0 }
        let totalWithoutCurrent = category.subcategoryAllocations
            .filter { $0.id != target.subcategoryID }
            .reduce(0) { $0 + $1.basePercentage }
        return max(0, 100 - totalWithoutCurrent)
    }

    private func maxAllowedMoneyForAdd(categoryType: ExpenseCategoryType) -> Double {
        guard let category = distribution.categoryAllocations.first(where: { $0.type == categoryType }) else { return 0 }
        let automaticCards = category.subcategoryAllocations.filter(\.participatesInAutomaticAllocation)
        let categoryRemainingAmount = automaticCards.reduce(0.0) { partialResult, subcategory in
            partialResult + subcategory.remainingAmount
        }
        let committedMinimums = automaticCards.reduce(0.0) { partialResult, subcategory in
            partialResult + minimumCommitment(for: subcategory, categoryAmount: categoryRemainingAmount)
        }
        let freeInsideCategory = max(0, categoryRemainingAmount - committedMinimums)
        return freeInsideCategory + bankAvailableAmount
    }

    private func maxAllowedMoneyForEdit(target: EditSubcategoryTarget) -> Double {
        guard let category = distribution.categoryAllocations.first(where: { $0.type == target.categoryType }) else { return 0 }
        let automaticCards = category.subcategoryAllocations.filter(\.participatesInAutomaticAllocation)
        let categoryRemainingAmount = automaticCards.reduce(0.0) { partialResult, subcategory in
            partialResult + subcategory.remainingAmount
        }
        let committedMinimumsWithoutCurrent = automaticCards
            .filter { $0.id != target.subcategoryID }
            .reduce(0.0) { partialResult, subcategory in
                partialResult + minimumCommitment(for: subcategory, categoryAmount: categoryRemainingAmount)
            }
        let freeInsideCategory = max(0, categoryRemainingAmount - committedMinimumsWithoutCurrent)
        return freeInsideCategory + bankAvailableAmount
    }

    private func currentRemainingForEdit(target: EditSubcategoryTarget) -> Double {
        distribution.categoryAllocations
            .first(where: { $0.type == target.categoryType })?
            .subcategoryAllocations
            .first(where: { $0.id == target.subcategoryID })?
            .remainingAmount ?? 0
    }

    private func currentMaxLimitForEdit(target: EditSubcategoryTarget) -> Double? {
        distribution.categoryAllocations
            .first(where: { $0.type == target.categoryType })?
            .subcategoryAllocations
            .first(where: { $0.id == target.subcategoryID })?
            .maxLimit
    }

    private func minimumCommitment(
        for subcategory: SubcategoryAllocation,
        categoryAmount _: Double
    ) -> Double {
        let maxCap = maxCap(for: subcategory)
        return min(max(0, subcategory.minLimit ?? 0), maxCap)
    }

    private func maxCap(for subcategory: SubcategoryAllocation) -> Double {
        guard let maxLimit = subcategory.maxLimit, maxLimit > 0 else {
            return .greatestFiniteMagnitude
        }
        return maxLimit
    }
}

struct ExpenseTarget: Identifiable {
    let categoryType: ExpenseCategoryType
    let subcategoryID: UUID
    let subcategoryName: String
    let currencyCode: String
    let editTarget: EditSubcategoryTarget

    var isManualOnly: Bool {
        editTarget.isManualOnly
    }

    var id: UUID { subcategoryID }
}

struct AddSubcategoryTarget: Identifiable {
    let id: UUID
    let type: ExpenseCategoryType
    let title: String
}

struct EditSubcategoryTarget: Identifiable {
    let subcategoryID: UUID
    let categoryType: ExpenseCategoryType
    let categoryTitle: String
    let subcategoryName: String
    let isSystem: Bool
    let isRequired: Bool
    let minimumRequirementIsLocked: Bool
    let fundingMode: SubcategoryFundingMode
    let currencyCode: String

    var isManualOnly: Bool {
        fundingMode == .manualOnly
    }

    var id: UUID { subcategoryID }
}
