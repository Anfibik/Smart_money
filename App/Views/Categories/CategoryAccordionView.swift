import Foundation
import SwiftUI

struct CategoryAccordionView: View {
    let distribution: BudgetDistribution
    let currencyCode: String
    let lastIncomeAmount: Double
    let bankAvailableAmount: Double
    let onPayExpense: (ExpenseCategoryType, UUID, Double, Bool) -> Void
    let expenseCoverageRequirement: (ExpenseCategoryType, UUID, Double) -> CategoryCoverageRequirement?
    let onPayExpenseWithAutomaticForcedCoverage: (ExpenseCategoryType, UUID, Double) -> Void
    let onPayExpenseWithManualForcedCoverage: (ExpenseCategoryType, UUID, Double, [UUID: Double]) -> Void
    let onAddSubcategory: (
        ExpenseCategoryType,
        String,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel
    ) -> Void
    let newSubcategoryCoverageRequirement: (ExpenseCategoryType, Double) -> CategoryCoverageRequirement?
    let onAddSubcategoryWithAutomaticForcedCoverage: (
        ExpenseCategoryType,
        String,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel
    ) -> Void
    let onAddSubcategoryWithManualForcedCoverage: (
        ExpenseCategoryType,
        String,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel,
        [UUID: Double]
    ) -> Void
    let onUpdateSubcategory: (
        ExpenseCategoryType,
        UUID,
        String,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel
    ) -> Void
    let onDeleteSubcategory: (ExpenseCategoryType, UUID) -> Void
    let onWithdrawFunds: (ExpenseCategoryType, UUID, Double) -> Void
    let onDepositFunds: (ExpenseCategoryType, UUID, Double) -> Void

    @State private var expandedCategoryIDs: Set<UUID>
    @State private var expenseTarget: ExpenseTarget?
    @State private var addSubcategoryTarget: AddSubcategoryTarget?
    @State private var editSubcategoryTarget: EditSubcategoryTarget?
    @State private var pendingPriorityChange: PendingPriorityChange?
    @State private var expenseInput: String = ""
    @State private var subcategoryNameInput: String = ""
    @State private var subcategoryPercentInput: String = ""
    @State private var subcategoryMinAmountInput: String = ""
    @State private var subcategoryMaxAmountInput: String = ""
    @State private var subcategoryIconName: String = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
    @State private var subcategoryPriority: SubcategoryPriorityLevel = .low
    @State private var useBankForExpense: Bool = false
    @State private var editNameInput: String = ""
    @State private var editPercentInput: String = ""
    @State private var editMinAmountInput: String = ""
    @State private var editMaxAmountInput: String = ""
    @State private var editIconName: String = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
    @State private var editPriority: SubcategoryPriorityLevel = .low
    @State private var withdrawAmountInput: String = ""
    @State private var depositAmountInput: String = ""
    @State private var suppressTapAfterLongPress: Bool = false

    init(
        distribution: BudgetDistribution,
        currencyCode: String,
        lastIncomeAmount: Double,
        bankAvailableAmount: Double,
        onPayExpense: @escaping (ExpenseCategoryType, UUID, Double, Bool) -> Void,
        expenseCoverageRequirement: @escaping (ExpenseCategoryType, UUID, Double) -> CategoryCoverageRequirement?,
        onPayExpenseWithAutomaticForcedCoverage: @escaping (ExpenseCategoryType, UUID, Double) -> Void,
        onPayExpenseWithManualForcedCoverage: @escaping (ExpenseCategoryType, UUID, Double, [UUID: Double]) -> Void,
        onAddSubcategory: @escaping (
            ExpenseCategoryType,
            String,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel
        ) -> Void,
        newSubcategoryCoverageRequirement: @escaping (ExpenseCategoryType, Double) -> CategoryCoverageRequirement?,
        onAddSubcategoryWithAutomaticForcedCoverage: @escaping (
            ExpenseCategoryType,
            String,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel
        ) -> Void,
        onAddSubcategoryWithManualForcedCoverage: @escaping (
            ExpenseCategoryType,
            String,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel,
            [UUID: Double]
        ) -> Void,
        onUpdateSubcategory: @escaping (
            ExpenseCategoryType,
            UUID,
            String,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel
        ) -> Void,
        onDeleteSubcategory: @escaping (ExpenseCategoryType, UUID) -> Void,
        onWithdrawFunds: @escaping (ExpenseCategoryType, UUID, Double) -> Void,
        onDepositFunds: @escaping (ExpenseCategoryType, UUID, Double) -> Void
    ) {
        self.distribution = distribution
        self.currencyCode = currencyCode
        self.lastIncomeAmount = lastIncomeAmount
        self.bankAvailableAmount = bankAvailableAmount
        self.onPayExpense = onPayExpense
        self.expenseCoverageRequirement = expenseCoverageRequirement
        self.onPayExpenseWithAutomaticForcedCoverage = onPayExpenseWithAutomaticForcedCoverage
        self.onPayExpenseWithManualForcedCoverage = onPayExpenseWithManualForcedCoverage
        self.onAddSubcategory = onAddSubcategory
        self.newSubcategoryCoverageRequirement = newSubcategoryCoverageRequirement
        self.onAddSubcategoryWithAutomaticForcedCoverage = onAddSubcategoryWithAutomaticForcedCoverage
        self.onAddSubcategoryWithManualForcedCoverage = onAddSubcategoryWithManualForcedCoverage
        self.onUpdateSubcategory = onUpdateSubcategory
        self.onDeleteSubcategory = onDeleteSubcategory
        self.onWithdrawFunds = onWithdrawFunds
        self.onDepositFunds = onDepositFunds

        let essentialsID = distribution.categoryAllocations
            .first(where: { $0.type == .essentials })?
            .id
        _expandedCategoryIDs = State(initialValue: Set([essentialsID].compactMap { $0 }))
    }

    private var hasExpandedCategory: Bool {
        distribution.categoryAllocations.contains { expandedCategoryIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(distribution.categoryAllocations) { category in
                let categorySpent = category.subcategoryAllocations.reduce(0) { $0 + $1.spentAmount }
                let categoryRemaining = category.subcategoryAllocations.reduce(0) { $0 + $1.remainingAmount }
                let categoryLastIncome = lastIncomeAmount * (category.percentage / 100.0)
                let isCategoryExpanded = isExpanded(category.id)

                VStack(spacing: 0) {
                    CategoryHeaderView(
                        category: category,
                        currencyCode: currencyCode,
                        categoryRemaining: categoryRemaining,
                        categorySpent: categorySpent,
                        categoryLastIncome: categoryLastIncome,
                        isExpanded: isCategoryExpanded,
                        useCompactLayout: hasExpandedCategory,
                        onTap: { toggle(categoryID: category.id) }
                    )

                    if isCategoryExpanded {
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

            BankSummaryView(
                bankAvailableAmount: bankAvailableAmount,
                lines: distribution.lastBankAutoDistributions,
                currencyCode: currencyCode
            )
        }
        .sheet(item: $expenseTarget) { target in
            let coverageRequirement = expenseCoverageRequirement(
                target.categoryType,
                target.subcategoryID,
                nonNegativeValue(from: expenseInput)
            )

            ExpenseSheetView(
                target: target,
                currencyCode: currencyCode,
                bankAvailableAmount: bankAvailableAmount,
                coverageRequirement: coverageRequirement,
                expenseInput: $expenseInput,
                onPay: { amount, useBankIfNeeded in
                    onPayExpense(target.categoryType, target.subcategoryID, amount, useBankIfNeeded)
                    expenseTarget = nil
                },
                onAutoForcedPay: { amount in
                    onPayExpenseWithAutomaticForcedCoverage(target.categoryType, target.subcategoryID, amount)
                    expenseTarget = nil
                },
                onManualForcedPay: { amount, allocations in
                    onPayExpenseWithManualForcedCoverage(target.categoryType, target.subcategoryID, amount, allocations)
                    expenseTarget = nil
                },
                onCancel: {
                    expenseTarget = nil
                }
            )
        }
        .sheet(item: $addSubcategoryTarget) { target in
            let highName = priorityHolder(categoryType: target.type, level: .high)?.name ?? "не назначен"
            let mediumName = priorityHolder(categoryType: target.type, level: .medium)?.name ?? "не назначен"
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
                highPriorityName: highName,
                mediumPriorityName: mediumName,
                subcategoryNameInput: $subcategoryNameInput,
                subcategoryPercentInput: $subcategoryPercentInput,
                subcategoryMinAmountInput: $subcategoryMinAmountInput,
                subcategoryMaxAmountInput: $subcategoryMaxAmountInput,
                subcategoryIconName: $subcategoryIconName,
                subcategoryPriority: $subcategoryPriority,
                canCreate: canCreateSubcategory,
                onRequestPriorityChange: { level, targetName in
                    requestPriorityChange(
                        categoryType: target.type,
                        desired: level,
                        currentSubcategoryID: nil,
                        targetName: targetName,
                        form: .add
                    )
                },
                onClearPriority: {
                    subcategoryPriority = .low
                },
                onCreate: {
                    createSubcategory(for: target)
                },
                onCreateWithAutomaticForcedCoverage: {
                    createSubcategoryWithAutomaticForcedCoverage(for: target)
                },
                onCreateWithManualForcedCoverage: { allocations in
                    createSubcategoryWithManualForcedCoverage(for: target, allocations: allocations)
                },
                onCancel: {
                    addSubcategoryTarget = nil
                }
            )
        }
        .sheet(item: $editSubcategoryTarget) { target in
            let highName = priorityHolder(categoryType: target.categoryType, level: .high)?.name ?? "не назначен"
            let mediumName = priorityHolder(categoryType: target.categoryType, level: .medium)?.name ?? "не назначен"
            let availableForCard = maxAllowedPercentForEdit(target: target)
            let availableMoneyForCard = maxAllowedMoneyForEdit(target: target)
            let currentRemaining = currentRemainingForEdit(target: target)
            let currentMaxLimit = currentMaxLimitForEdit(target: target)

            EditSubcategorySheetView(
                target: target,
                currencyCode: currencyCode,
                bankAvailableAmount: bankAvailableAmount,
                availableForCard: availableForCard,
                availableMoneyForCard: availableMoneyForCard,
                currentRemaining: currentRemaining,
                currentMaxLimit: currentMaxLimit,
                highPriorityName: highName,
                mediumPriorityName: mediumName,
                editNameInput: $editNameInput,
                editPercentInput: $editPercentInput,
                editMinAmountInput: $editMinAmountInput,
                editMaxAmountInput: $editMaxAmountInput,
                editIconName: $editIconName,
                withdrawAmountInput: $withdrawAmountInput,
                depositAmountInput: $depositAmountInput,
                editPriority: $editPriority,
                canSave: canSaveEditedSubcategory,
                onRequestPriorityChange: { level, targetName in
                    requestPriorityChange(
                        categoryType: target.categoryType,
                        desired: level,
                        currentSubcategoryID: target.subcategoryID,
                        targetName: targetName,
                        form: .edit
                    )
                },
                onClearPriority: {
                    editPriority = .low
                },
                onSave: {
                    saveEditedSubcategory(target: target)
                },
                onWithdraw: {
                    withdrawFromEditedSubcategory(target: target)
                },
                onDeposit: {
                    depositIntoEditedSubcategory(target: target)
                },
                onDelete: target.isSystem ? nil : {
                    onDeleteSubcategory(target.categoryType, target.subcategoryID)
                    editSubcategoryTarget = nil
                },
                onCancel: {
                    editSubcategoryTarget = nil
                }
            )
        }
        .alert(item: $pendingPriorityChange) { pending in
            Alert(
                title: Text("Смена приоритета"),
                message: Text("Приоритет \(pending.level.title.lowercased()) сейчас у карточки \"\(pending.fromName)\". Переназначить его карточке \"\(pending.toName)\"?"),
                primaryButton: .destructive(Text("Переназначить")) {
                    applyPriorityChange(pending)
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
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
            && normalizedMinAmount > 0
            && (coverageRequirement?.canCover != false)
    }

    private var canSaveEditedSubcategory: Bool {
        guard let target = editSubcategoryTarget else { return false }
        let normalizedName = editNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPercent = nonNegativeValue(from: editPercentInput)
        let availableForCard = maxAllowedPercentForEdit(target: target)
        return !normalizedName.isEmpty
            && normalizedPercent > 0
            && normalizedPercent <= availableForCard
    }

    private func openExpenseSheet(for categoryType: ExpenseCategoryType, subcategory: SubcategoryAllocation) {
        expenseTarget = ExpenseTarget(
            categoryType: categoryType,
            subcategoryID: subcategory.id,
            subcategoryName: subcategory.name,
            currentAmount: subcategory.remainingAmount
        )
        expenseInput = ""
        useBankForExpense = true
    }

    private func openEditSubcategorySheet(for categoryType: ExpenseCategoryType, subcategory: SubcategoryAllocation) {
        editNameInput = subcategory.name
        editIconName = subcategory.iconName
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
        editPriority = SubcategoryPriorityLevel(rawValue: subcategory.priority) ?? .low
        withdrawAmountInput = ""
        depositAmountInput = ""
        editSubcategoryTarget = EditSubcategoryTarget(
            subcategoryID: subcategory.id,
            categoryType: categoryType,
            categoryTitle: categoryType.title,
            subcategoryName: subcategory.name,
            isSystem: subcategory.isSystem
        )
    }

    private func openAddSubcategorySheet(for category: CategoryAllocation) {
        subcategoryNameInput = ""
        subcategoryPercentInput = ""
        subcategoryMinAmountInput = ""
        subcategoryMaxAmountInput = ""
        subcategoryIconName = SubcategoryIconCatalog.selectableSymbols.first ?? SubcategoryIconCatalog.fallbackSymbol
        subcategoryPriority = .low
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
              minAmount > 0,
              coverageRequirement == nil else { return }

        let maxAmount = nonNegativeValue(from: subcategoryMaxAmountInput)

        onAddSubcategory(
            target.type,
            name,
            subcategoryIconName,
            mainPercent,
            minAmount,
            maxAmount,
            subcategoryPriority
        )
        addSubcategoryTarget = nil
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
        onAddSubcategoryWithAutomaticForcedCoverage(
            target.type,
            name,
            subcategoryIconName,
            mainPercent,
            minAmount,
            maxAmount,
            subcategoryPriority
        )
        addSubcategoryTarget = nil
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
        onAddSubcategoryWithManualForcedCoverage(
            target.type,
            name,
            subcategoryIconName,
            mainPercent,
            minAmount,
            maxAmount,
            subcategoryPriority,
            allocations
        )
        addSubcategoryTarget = nil
    }

    private func saveEditedSubcategory(target: EditSubcategoryTarget) {
        let name = editNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let mainPercent = nonNegativeValue(from: editPercentInput)
        let availableForCard = maxAllowedPercentForEdit(target: target)
        let minAmount = nonNegativeValue(from: editMinAmountInput)
        guard !name.isEmpty,
              mainPercent > 0,
              mainPercent <= availableForCard else { return }

        let maxAmount = nonNegativeValue(from: editMaxAmountInput)

        onUpdateSubcategory(
            target.categoryType,
            target.subcategoryID,
            name,
            editIconName,
            mainPercent,
            minAmount,
            maxAmount,
            editPriority
        )
        editSubcategoryTarget = nil
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

    private func requestPriorityChange(
        categoryType: ExpenseCategoryType,
        desired: SubcategoryPriorityLevel,
        currentSubcategoryID: UUID?,
        targetName: String,
        form: PriorityForm
    ) {
        if let holder = priorityHolder(categoryType: categoryType, level: desired), holder.id != currentSubcategoryID {
            pendingPriorityChange = PendingPriorityChange(
                level: desired,
                fromName: holder.name,
                toName: targetName,
                form: form
            )
            return
        }

        applyPriority(level: desired, form: form)
    }

    private func applyPriorityChange(_ pending: PendingPriorityChange) {
        applyPriority(level: pending.level, form: pending.form)
    }

    private func applyPriority(level: SubcategoryPriorityLevel, form: PriorityForm) {
        switch form {
        case .add:
            subcategoryPriority = level
        case .edit:
            editPriority = level
        }
    }

    private func priorityHolder(categoryType: ExpenseCategoryType, level: SubcategoryPriorityLevel) -> SubcategoryAllocation? {
        distribution.categoryAllocations
            .first(where: { $0.type == categoryType })?
            .subcategoryAllocations
            .first(where: { $0.priority == level.rawValue })
    }

    private func nonNegativeValue(from input: String) -> Double {
        let normalized = input.replacingOccurrences(of: ",", with: ".")
        return max(0, Double(normalized) ?? 0)
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
        let categoryRemainingAmount = category.subcategoryAllocations.reduce(0.0) { partialResult, subcategory in
            partialResult + subcategory.remainingAmount
        }
        let committedMinimums = category.subcategoryAllocations.reduce(0.0) { partialResult, subcategory in
            partialResult + minimumCommitment(for: subcategory, categoryAmount: categoryRemainingAmount)
        }
        let freeInsideCategory = max(0, categoryRemainingAmount - committedMinimums)
        return freeInsideCategory + bankAvailableAmount
    }

    private func maxAllowedMoneyForEdit(target: EditSubcategoryTarget) -> Double {
        guard let category = distribution.categoryAllocations.first(where: { $0.type == target.categoryType }) else { return 0 }
        let categoryRemainingAmount = category.subcategoryAllocations.reduce(0.0) { partialResult, subcategory in
            partialResult + subcategory.remainingAmount
        }
        let committedMinimumsWithoutCurrent = category.subcategoryAllocations
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

    private func minimumCommitment(for subcategory: SubcategoryAllocation, categoryAmount: Double) -> Double {
        let maxCap = maxCap(for: subcategory)
        let minAmountTarget = min(max(0, subcategory.minLimit ?? 0), maxCap)
        let basePercentTarget = min(categoryAmount * (max(0, subcategory.basePercentage) / 100.0), maxCap)

        if minAmountTarget > 0 {
            return minAmountTarget
        }
        return basePercentTarget
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
    let currentAmount: Double

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

    var id: UUID { subcategoryID }
}

private enum PriorityForm {
    case add
    case edit
}

private struct PendingPriorityChange: Identifiable {
    let id = UUID()
    let level: SubcategoryPriorityLevel
    let fromName: String
    let toName: String
    let form: PriorityForm
}
