import Foundation

enum ExpenseCategoryType: String, Codable, CaseIterable, Hashable {
    case essentials
    case savings
    case wants

    var title: String {
        switch self {
        case .essentials: return "Основные"
        case .savings: return "Накопления"
        case .wants: return "Желаемые"
        }
    }

    /// Базовое распределение между 3 главными категориями
    var defaultPercentage: Double {
        switch self {
        case .essentials: return 60
        case .savings: return 20
        case .wants: return 20
        }
    }
}

struct ExpenseCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var type: ExpenseCategoryType

    /// Процент от общего дохода (0...100)
    var percentage: Double

    var subcategories: [Subcategory]

    init(
        id: UUID = UUID(),
        type: ExpenseCategoryType,
        percentage: Double,
        subcategories: [Subcategory]
    ) {
        self.id = id
        self.type = type
        self.percentage = percentage
        self.subcategories = subcategories
    }

    var subcategoriesTotalPercentage: Double {
        subcategories.reduce(0) { $0 + $1.percentage }
    }
}
