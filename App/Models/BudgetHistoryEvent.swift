import Foundation

enum BudgetHistoryEventType: String, Codable, CaseIterable, Hashable {
    case income
    case expense
    case transferToFreeCapital
    case transferFromFreeCapital

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
        }
    }

    var affectsStatisticsByDefault: Bool {
        switch self {
        case .income, .expense:
            return true
        case .transferToFreeCapital, .transferFromFreeCapital:
            return false
        }
    }

    var isTransfer: Bool {
        switch self {
        case .transferToFreeCapital, .transferFromFreeCapital:
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
    let affectsStatistics: Bool

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
        affectsStatistics: Bool? = nil
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
        self.affectsStatistics = affectsStatistics ?? type.affectsStatisticsByDefault
    }

    var displayTitle: String {
        switch type {
        case .expense:
            return subcategoryNameSnapshot ?? type.title
        case .income, .transferToFreeCapital, .transferFromFreeCapital:
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
        }
    }

    var displayIconName: String {
        if let iconNameSnapshot, !iconNameSnapshot.isEmpty {
            return iconNameSnapshot
        }
        return type.defaultIconName
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
