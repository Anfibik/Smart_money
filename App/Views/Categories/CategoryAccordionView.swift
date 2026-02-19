import Foundation
import SwiftUI

struct CategoryAccordionView: View {
    let distribution: BudgetDistribution
    let currencyCode: String
    let lastIncomeAmount: Double
    let bankAvailableAmount: Double
    let onPayExpense: (ExpenseCategoryType, UUID, Double, Bool) -> Void
    let onAddSubcategory: (
        ExpenseCategoryType,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel
    ) -> Void
    let onUpdateSubcategory: (
        ExpenseCategoryType,
        UUID,
        String,
        Double,
        Double,
        Double,
        SubcategoryPriorityLevel
    ) -> Void
    let onDeleteSubcategory: (ExpenseCategoryType, UUID) -> Void
    let onWithdrawFunds: (ExpenseCategoryType, UUID, Double) -> Void

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
    @State private var subcategoryPriority: SubcategoryPriorityLevel = .low
    @State private var useBankForExpense: Bool = false
    @State private var editNameInput: String = ""
    @State private var editPercentInput: String = ""
    @State private var editMinAmountInput: String = ""
    @State private var editMaxAmountInput: String = ""
    @State private var editPriority: SubcategoryPriorityLevel = .low
    @State private var withdrawAmountInput: String = ""
    @State private var suppressTapAfterLongPress: Bool = false
    @FocusState private var isExpenseFieldFocused: Bool
    @FocusState private var isAddSubcategoryNameFocused: Bool
    @FocusState private var isEditNameFocused: Bool

    init(
        distribution: BudgetDistribution,
        currencyCode: String,
        lastIncomeAmount: Double,
        bankAvailableAmount: Double,
        onPayExpense: @escaping (ExpenseCategoryType, UUID, Double, Bool) -> Void,
        onAddSubcategory: @escaping (
            ExpenseCategoryType,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel
        ) -> Void,
        onUpdateSubcategory: @escaping (
            ExpenseCategoryType,
            UUID,
            String,
            Double,
            Double,
            Double,
            SubcategoryPriorityLevel
        ) -> Void,
        onDeleteSubcategory: @escaping (ExpenseCategoryType, UUID) -> Void,
        onWithdrawFunds: @escaping (ExpenseCategoryType, UUID, Double) -> Void
    ) {
        self.distribution = distribution
        self.currencyCode = currencyCode
        self.lastIncomeAmount = lastIncomeAmount
        self.bankAvailableAmount = bankAvailableAmount
        self.onPayExpense = onPayExpense
        self.onAddSubcategory = onAddSubcategory
        self.onUpdateSubcategory = onUpdateSubcategory
        self.onDeleteSubcategory = onDeleteSubcategory
        self.onWithdrawFunds = onWithdrawFunds

        let essentialsID = distribution.categoryAllocations
            .first(where: { $0.type == .essentials })?
            .id
        _expandedCategoryIDs = State(initialValue: Set([essentialsID].compactMap { $0 }))
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
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            BankSummaryView(
                bankAvailableAmount: bankAvailableAmount,
                lines: distribution.lastBankAutoDistributions,
                currencyCode: currencyCode
            )
        }
        .sheet(item: $expenseTarget) { target in
            let normalizedInput = expenseInput.replacingOccurrences(of: ",", with: ".")
            let enteredAmount = max(0, Double(normalizedInput) ?? 0)
            let availableFromSubcategory = target.currentAmount
            let availableFromBank = bankAvailableAmount
            let totalAvailable = availableFromSubcategory + availableFromBank
            let needsBank = enteredAmount > availableFromSubcategory + 0.0001
            let exceedsLimit = enteredAmount > totalAvailable + 0.0001
            let canPay = enteredAmount > 0 && !exceedsLimit && (!needsBank || useBankForExpense)

            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(target.subcategoryName)
                        .font(.title3.bold())

                    Text("Доступно в подкатегории: \(availableFromSubcategory, format: .currency(code: currencyCode))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Доступно в банке: \(availableFromBank, format: .currency(code: currencyCode))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Итого доступно: \(totalAvailable, format: .currency(code: currencyCode))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("Введите сумму", text: $expenseInput)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isExpenseFieldFocused)

                    if needsBank, enteredAmount > 0, availableFromBank > 0 {
                        Toggle("Списать нехватку из банки", isOn: $useBankForExpense)
                            .tint(.blue)
                    }

                    if needsBank, enteredAmount > 0, !useBankForExpense, !exceedsLimit {
                        Text("Сумма превышает остаток подкатегории. Включите списание из банки.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if exceedsLimit {
                        Text("Оплата недоступна: сумма превышает подкатегорию + банку.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Оплатить") {
                        guard canPay else { return }
                        onPayExpense(target.categoryType, target.subcategoryID, enteredAmount, useBankForExpense)
                        expenseTarget = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canPay)

                    Spacer()
                }
                .padding()
                .navigationTitle("Оплата")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            expenseTarget = nil
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
        .sheet(item: $addSubcategoryTarget) { target in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        let freePercent = maxAllowedPercentForAdd(categoryType: target.type)
                        let requestedPercent = nonNegativeValue(from: subcategoryPercentInput)
                        let freeMoney = maxAllowedMoneyForAdd(categoryType: target.type)

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

                        priorityInfoLine(categoryType: target.type)
                        priorityControlsForAdd(target: target)

                        if freePercent <= 0 {
                            Text("Лимит 100% исчерпан. Добавление новой карточки недоступно.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        TextField("Название*", text: $subcategoryNameInput)
                            .textFieldStyle(.roundedBorder)
                            .focused($isAddSubcategoryNameFocused)

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
                            createSubcategory(for: target)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCreateSubcategory)
                    }
                    .padding()
                }
                .navigationTitle("Новая подкатегория")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            addSubcategoryTarget = nil
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Готово") {
                            isAddSubcategoryNameFocused = false
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isAddSubcategoryNameFocused = true
                    }
                }
            }
        }
        .sheet(item: $editSubcategoryTarget) { target in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        let availableForCard = maxAllowedPercentForEdit(target: target)
                        let requestedPercent = nonNegativeValue(from: editPercentInput)
                        let availableMoneyForCard = maxAllowedMoneyForEdit(target: target)
                        let currentRemaining = currentRemainingForEdit(target: target)
                        let minimumLevel = minimumLevelForEdit(target: target)
                        let maxWithdrawable = max(0, currentRemaining - minimumLevel)
                        let requestedWithdraw = nonNegativeValue(from: withdrawAmountInput)
                        let canWithdraw = requestedWithdraw > 0 && requestedWithdraw <= maxWithdrawable + 0.0001

                        Text("Категория: \(target.categoryTitle)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Свободно для этой карточки: \(formattedPercent(max(0, availableForCard)))%")
                            .font(.subheadline)
                            .foregroundColor(availableForCard > 0 ? .secondary : .red)

                        Text("Свободно денег для этой карточки: \(availableMoneyForCard, format: .currency(code: currencyCode))")
                            .font(.subheadline)
                            .foregroundColor(availableMoneyForCard > 0 ? .secondary : .red)

                        Text("Из них в банке: \(bankAvailableAmount, format: .currency(code: currencyCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        priorityInfoLine(categoryType: target.categoryType)
                        priorityControlsForEdit(target: target)

                        if availableForCard <= 0 {
                            Text("Лимит 100% исчерпан. Увеличение процента недоступно.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        TextField("Название*", text: $editNameInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(target.isSystem)
                            .focused($isEditNameFocused)

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

                        Button("Сохранить изменения") {
                            saveEditedSubcategory(target: target)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSaveEditedSubcategory)

                        Divider()
                            .padding(.vertical, 2)

                        Text("Изъятие средств в банку")
                            .font(.subheadline.weight(.semibold))

                        Text("Текущий остаток: \(currentRemaining, format: .currency(code: currencyCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Минимальный уровень: \(minimumLevel, format: .currency(code: currencyCode))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Можно изъять: \(maxWithdrawable, format: .currency(code: currencyCode))")
                            .font(.caption)
                            .foregroundColor(maxWithdrawable > 0 ? .secondary : .red)

                        TextField("Сумма для изъятия", text: $withdrawAmountInput)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)

                        if requestedWithdraw > maxWithdrawable, requestedWithdraw > 0 {
                            Text("Сумма слишком большая: после изъятия остаток не может быть ниже минимального уровня.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button("Изъять средства") {
                            withdrawFromEditedSubcategory(target: target)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canWithdraw)

                        if !target.isSystem {
                            Button("Удалить карточку", role: .destructive) {
                                onDeleteSubcategory(target.categoryType, target.subcategoryID)
                                editSubcategoryTarget = nil
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Настройка карточки")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            editSubcategoryTarget = nil
                        }
                    }
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Готово") {
                            isEditNameFocused = false
                        }
                    }
                }
                .onAppear {
                    if !target.isSystem {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isEditNameFocused = true
                        }
                    }
                }
            }
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
        return !normalizedName.isEmpty
            && normalizedPercent > 0
            && normalizedPercent <= freePercent
            && normalizedMinAmount > 0
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
        useBankForExpense = false
    }

    private func openEditSubcategorySheet(for categoryType: ExpenseCategoryType, subcategory: SubcategoryAllocation) {
        editNameInput = subcategory.name
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
        subcategoryPriority = .low
        addSubcategoryTarget = AddSubcategoryTarget(id: category.id, type: category.type, title: category.type.title)
    }

    private func createSubcategory(for target: AddSubcategoryTarget) {
        let name = subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let mainPercent = nonNegativeValue(from: subcategoryPercentInput)
        let freePercent = maxAllowedPercentForAdd(categoryType: target.type)
        let minAmount = nonNegativeValue(from: subcategoryMinAmountInput)
        guard !name.isEmpty,
              mainPercent > 0,
              mainPercent <= freePercent,
              minAmount > 0 else { return }

        let maxAmount = nonNegativeValue(from: subcategoryMaxAmountInput)

        onAddSubcategory(
            target.type,
            name,
            mainPercent,
            minAmount,
            maxAmount,
            subcategoryPriority
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
        let minimumLevel = minimumLevelForEdit(target: target)
        let maxWithdrawable = max(0, currentRemaining - minimumLevel)

        guard requested > 0, requested <= maxWithdrawable + 0.0001 else { return }

        onWithdrawFunds(target.categoryType, target.subcategoryID, requested)
        withdrawAmountInput = ""
    }

    private func priorityInfoLine(categoryType: ExpenseCategoryType) -> some View {
        let highName = priorityHolder(categoryType: categoryType, level: .high)?.name ?? "не назначен"
        let mediumName = priorityHolder(categoryType: categoryType, level: .medium)?.name ?? "не назначен"

        return VStack(alignment: .leading, spacing: 2) {
            Text("Высокий: \(highName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Средний: \(mediumName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func priorityControlsForAdd(target: AddSubcategoryTarget) -> some View {
        HStack(spacing: 8) {
            if subcategoryPriority == .high {
                Button("Высокий") {
                    requestPriorityChange(
                        categoryType: target.type,
                        desired: .high,
                        currentSubcategoryID: nil,
                        targetName: subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "новая карточка" : subcategoryNameInput,
                        form: .add
                    )
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Высокий") {
                    requestPriorityChange(
                        categoryType: target.type,
                        desired: .high,
                        currentSubcategoryID: nil,
                        targetName: subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "новая карточка" : subcategoryNameInput,
                        form: .add
                    )
                }
                .buttonStyle(.bordered)
            }

            if subcategoryPriority == .medium {
                Button("Средний") {
                    requestPriorityChange(
                        categoryType: target.type,
                        desired: .medium,
                        currentSubcategoryID: nil,
                        targetName: subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "новая карточка" : subcategoryNameInput,
                        form: .add
                    )
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Средний") {
                    requestPriorityChange(
                        categoryType: target.type,
                        desired: .medium,
                        currentSubcategoryID: nil,
                        targetName: subcategoryNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "новая карточка" : subcategoryNameInput,
                        form: .add
                    )
                }
                .buttonStyle(.bordered)
            }

            if subcategoryPriority != .low {
                Button("Снять") {
                    subcategoryPriority = .low
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func priorityControlsForEdit(target: EditSubcategoryTarget) -> some View {
        HStack(spacing: 8) {
            if editPriority == .high {
                Button("Высокий") {
                    requestPriorityChange(
                        categoryType: target.categoryType,
                        desired: .high,
                        currentSubcategoryID: target.subcategoryID,
                        targetName: target.subcategoryName,
                        form: .edit
                    )
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Высокий") {
                    requestPriorityChange(
                        categoryType: target.categoryType,
                        desired: .high,
                        currentSubcategoryID: target.subcategoryID,
                        targetName: target.subcategoryName,
                        form: .edit
                    )
                }
                .buttonStyle(.bordered)
            }

            if editPriority == .medium {
                Button("Средний") {
                    requestPriorityChange(
                        categoryType: target.categoryType,
                        desired: .medium,
                        currentSubcategoryID: target.subcategoryID,
                        targetName: target.subcategoryName,
                        form: .edit
                    )
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Средний") {
                    requestPriorityChange(
                        categoryType: target.categoryType,
                        desired: .medium,
                        currentSubcategoryID: target.subcategoryID,
                        targetName: target.subcategoryName,
                        form: .edit
                    )
                }
                .buttonStyle(.bordered)
            }

            if editPriority != .low {
                Button("Снять") {
                    editPriority = .low
                }
                .buttonStyle(.bordered)
            }
        }
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

    private func minimumLevelForEdit(target: EditSubcategoryTarget) -> Double {
        distribution.categoryAllocations
            .first(where: { $0.type == target.categoryType })?
            .subcategoryAllocations
            .first(where: { $0.id == target.subcategoryID })?
            .minLimit ?? 0
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
    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }
}

private struct ExpenseTarget: Identifiable {
    let categoryType: ExpenseCategoryType
    let subcategoryID: UUID
    let subcategoryName: String
    let currentAmount: Double

    var id: UUID { subcategoryID }
}

private struct AddSubcategoryTarget: Identifiable {
    let id: UUID
    let type: ExpenseCategoryType
    let title: String
}

private struct EditSubcategoryTarget: Identifiable {
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
