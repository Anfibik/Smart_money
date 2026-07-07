import Foundation

enum BudgetHistoryEventType: String, Codable, CaseIterable, Hashable {
    case income
    case expense
    case transferToFreeCapital
    case transferFromFreeCapital
    case categoryReallocation

    var title: String {
        switch self {
        case .income:
            return "Доход"
        case .expense:
            return "Расход"
        case .transferToFreeCapital:
            return "Перевод в Свободный капитал"
        case .transferFromFreeCapital:
            return "Пополнение из Свободного капитала"
        case .categoryReallocation:
            return "Внутренний перевод"
        }
    }

    var defaultIconName: String {
        switch self {
        case .income:
            return "plus.circle.fill"
        case .expense:
            return "minus.circle.fill"
        case .transferToFreeCapital:
            return "arrow.up.right.circle.fill"
        case .transferFromFreeCapital:
            return "arrow.down.left.circle.fill"
        case .categoryReallocation:
            return "arrow.left.arrow.right.circle.fill"
        }
    }

    var affectsStatisticsByDefault: Bool {
        switch self {
        case .income, .expense:
            return true
        case .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation:
            return false
        }
    }

    var isTransfer: Bool {
        switch self {
        case .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation:
            return true
        case .income, .expense:
            return false
        }
    }
}

struct BudgetHistoryEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    let type: BudgetHistoryEventType
    let amount: Double
    let currencyCode: String
    let categoryType: ExpenseCategoryType?
    let categoryTitleSnapshot: String?
    let subcategoryID: UUID?
    let subcategoryNameSnapshot: String?
    let iconNameSnapshot: String?
    let counterpartyNameSnapshot: String?
    let affectsStatistics: Bool
    let undoDelta: BudgetOperationDelta?

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case type
        case amount
        case currencyCode
        case categoryType
        case categoryTitleSnapshot
        case subcategoryID
        case subcategoryNameSnapshot
        case iconNameSnapshot
        case counterpartyNameSnapshot
        case affectsStatistics
        case undoDelta
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        type: BudgetHistoryEventType,
        amount: Double,
        currencyCode: String,
        categoryType: ExpenseCategoryType? = nil,
        categoryTitleSnapshot: String? = nil,
        subcategoryID: UUID? = nil,
        subcategoryNameSnapshot: String? = nil,
        iconNameSnapshot: String? = nil,
        counterpartyNameSnapshot: String? = nil,
        affectsStatistics: Bool? = nil,
        undoDelta: BudgetOperationDelta? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.type = type
        self.amount = max(0, amount)
        self.currencyCode = currencyCode
        self.categoryType = categoryType
        self.categoryTitleSnapshot = categoryTitleSnapshot
        self.subcategoryID = subcategoryID
        self.subcategoryNameSnapshot = subcategoryNameSnapshot
        self.iconNameSnapshot = iconNameSnapshot
        self.counterpartyNameSnapshot = counterpartyNameSnapshot
        self.affectsStatistics = affectsStatistics ?? type.affectsStatisticsByDefault
        self.undoDelta = undoDelta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        type = try container.decode(BudgetHistoryEventType.self, forKey: .type)
        amount = max(0, try container.decode(Double.self, forKey: .amount))
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        categoryType = try container.decodeIfPresent(ExpenseCategoryType.self, forKey: .categoryType)
        categoryTitleSnapshot = try container.decodeIfPresent(String.self, forKey: .categoryTitleSnapshot)
        subcategoryID = try container.decodeIfPresent(UUID.self, forKey: .subcategoryID)
        subcategoryNameSnapshot = try container.decodeIfPresent(String.self, forKey: .subcategoryNameSnapshot)
        iconNameSnapshot = try container.decodeIfPresent(String.self, forKey: .iconNameSnapshot)
        counterpartyNameSnapshot = try container.decodeIfPresent(String.self, forKey: .counterpartyNameSnapshot)
        affectsStatistics = try container.decodeIfPresent(Bool.self, forKey: .affectsStatistics) ?? type.affectsStatisticsByDefault
        undoDelta = try container.decodeIfPresent(BudgetOperationDelta.self, forKey: .undoDelta)
    }

    var canUndo: Bool {
        undoDelta != nil
    }

    var displayTitle: String {
        switch type {
        case .expense:
            return subcategoryNameSnapshot ?? type.title
        case .income, .transferToFreeCapital, .transferFromFreeCapital, .categoryReallocation:
            return type.title
        }
    }

    var displaySubtitle: String? {
        switch type {
        case .expense:
            return categoryTitleSnapshot
        case .income:
            return nil
        case .transferToFreeCapital, .transferFromFreeCapital:
            return subcategoryNameSnapshot
        case .categoryReallocation:
            if let from = subcategoryNameSnapshot, let to = counterpartyNameSnapshot {
                return "\(from) -> \(to)"
            }
            return subcategoryNameSnapshot ?? counterpartyNameSnapshot
        }
    }

    var displayIconName: String {
        if let iconNameSnapshot, !iconNameSnapshot.isEmpty {
            return iconNameSnapshot
        }
        return type.defaultIconName
    }
}

struct BudgetOperationDelta: Codable, Hashable {
    let incomeDelta: Double
    let bankBalanceDelta: Double
    let allocatedBySubcategoryIDDelta: [String: Double]
    let spentBySubcategoryIDDelta: [String: Double]
    let monthlyIncomeBySubcategoryIDDelta: [String: Double]
    let monthlyIncomeDistributionBySubcategoryIDDelta: [String: Double]
    let monthlyOtherIncomingBySubcategoryIDDelta: [String: Double]
    let monthlyOtherOutgoingBySubcategoryIDDelta: [String: Double]
    let categoryTargetBaselineByIDDelta: [String: Double]

    init(
        incomeDelta: Double = 0,
        bankBalanceDelta: Double = 0,
        allocatedBySubcategoryIDDelta: [String: Double] = [:],
        spentBySubcategoryIDDelta: [String: Double] = [:],
        monthlyIncomeBySubcategoryIDDelta: [String: Double] = [:],
        monthlyIncomeDistributionBySubcategoryIDDelta: [String: Double] = [:],
        monthlyOtherIncomingBySubcategoryIDDelta: [String: Double] = [:],
        monthlyOtherOutgoingBySubcategoryIDDelta: [String: Double] = [:],
        categoryTargetBaselineByIDDelta: [String: Double] = [:]
    ) {
        self.incomeDelta = incomeDelta
        self.bankBalanceDelta = bankBalanceDelta
        self.allocatedBySubcategoryIDDelta = allocatedBySubcategoryIDDelta
        self.spentBySubcategoryIDDelta = spentBySubcategoryIDDelta
        self.monthlyIncomeBySubcategoryIDDelta = monthlyIncomeBySubcategoryIDDelta
        self.monthlyIncomeDistributionBySubcategoryIDDelta = monthlyIncomeDistributionBySubcategoryIDDelta
        self.monthlyOtherIncomingBySubcategoryIDDelta = monthlyOtherIncomingBySubcategoryIDDelta
        self.monthlyOtherOutgoingBySubcategoryIDDelta = monthlyOtherOutgoingBySubcategoryIDDelta
        self.categoryTargetBaselineByIDDelta = categoryTargetBaselineByIDDelta
    }

    private enum CodingKeys: String, CodingKey {
        case incomeDelta
        case bankBalanceDelta
        case allocatedBySubcategoryIDDelta
        case spentBySubcategoryIDDelta
        case monthlyIncomeBySubcategoryIDDelta
        case monthlyIncomeDistributionBySubcategoryIDDelta
        case monthlyOtherIncomingBySubcategoryIDDelta
        case monthlyOtherOutgoingBySubcategoryIDDelta
        case categoryTargetBaselineByIDDelta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        incomeDelta = try container.decodeIfPresent(Double.self, forKey: .incomeDelta) ?? 0
        bankBalanceDelta = try container.decodeIfPresent(Double.self, forKey: .bankBalanceDelta) ?? 0
        allocatedBySubcategoryIDDelta = try container.decodeIfPresent([String: Double].self, forKey: .allocatedBySubcategoryIDDelta) ?? [:]
        spentBySubcategoryIDDelta = try container.decodeIfPresent([String: Double].self, forKey: .spentBySubcategoryIDDelta) ?? [:]
        monthlyIncomeBySubcategoryIDDelta = try container.decodeIfPresent([String: Double].self, forKey: .monthlyIncomeBySubcategoryIDDelta) ?? [:]
        monthlyIncomeDistributionBySubcategoryIDDelta = try container.decodeIfPresent([String: Double].self, forKey: .monthlyIncomeDistributionBySubcategoryIDDelta) ?? [:]
        monthlyOtherIncomingBySubcategoryIDDelta = try container.decodeIfPresent([String: Double].self, forKey: .monthlyOtherIncomingBySubcategoryIDDelta) ?? [:]
        monthlyOtherOutgoingBySubcategoryIDDelta = try container.decodeIfPresent([String: Double].self, forKey: .monthlyOtherOutgoingBySubcategoryIDDelta) ?? [:]
        categoryTargetBaselineByIDDelta = try container.decodeIfPresent([String: Double].self, forKey: .categoryTargetBaselineByIDDelta) ?? [:]
    }

    var isEmpty: Bool {
        abs(incomeDelta) <= 0.0001
            && abs(bankBalanceDelta) <= 0.0001
            && allocatedBySubcategoryIDDelta.isEmpty
            && spentBySubcategoryIDDelta.isEmpty
            && monthlyIncomeBySubcategoryIDDelta.isEmpty
            && monthlyIncomeDistributionBySubcategoryIDDelta.isEmpty
            && monthlyOtherIncomingBySubcategoryIDDelta.isEmpty
            && monthlyOtherOutgoingBySubcategoryIDDelta.isEmpty
            && categoryTargetBaselineByIDDelta.isEmpty
    }
}

enum HistoryPeriodMode: String, CaseIterable, Identifiable {
    case month
    case year
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month:
            return "Месяц"
        case .year:
            return "Год"
        case .allTime:
            return "Все время"
        }
    }
}

enum HistoryEntryFilter: String, CaseIterable, Identifiable {
    case all
    case income
    case expense
    case transfers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "Все"
        case .income:
            return "Доходы"
        case .expense:
            return "Расходы"
        case .transfers:
            return "Переводы"
        }
    }

    func matches(_ event: BudgetHistoryEvent) -> Bool {
        switch self {
        case .all:
            return true
        case .income:
            return event.type == .income
        case .expense:
            return event.type == .expense
        case .transfers:
            return event.type.isTransfer
        }
    }
}

struct HistoryMonthOption: Identifiable, Hashable {
    let year: Int
    let month: Int

    var id: String {
        String(format: "%04d-%02d", year, month)
    }

    func startDate(calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    func title(locale: Locale = .current, calendar: Calendar = .current) -> String {
        guard let date = startDate(calendar: calendar) else {
            return "\(month).\(year)"
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }
}
