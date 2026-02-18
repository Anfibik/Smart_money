import Foundation
import Combine


@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: BudgetSettings

    init(settings: BudgetSettings) {
        self.settings = settings
    }

    init() {
        self.settings = BudgetSettings()
    }

    func updateAllSettings(_ newSettings: BudgetSettings) {
        settings = newSettings
    }

    func updateCategoryPercentage(_ type: ExpenseCategoryType, percentage: Double) {
        guard let index = settings.categories.firstIndex(where: { $0.type == type }) else { return }
        settings.categories[index].percentage = max(0, min(100, percentage))
    }

    func updateSubcategoryPercentage(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        percentage: Double
    ) {
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }
        guard let subIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }

        let fixedMin = settings.categories[categoryIndex].subcategories[subIndex].fixedMinimumPercentage ?? 0
        let clamped = max(fixedMin, min(100, percentage))
        settings.categories[categoryIndex].subcategories[subIndex].percentage = clamped
    }

    func updateSubcategoryLimits(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        minLimit: Double?,
        maxLimit: Double?
    ) {
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }
        guard let subIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }

        let minValue = minLimit.map { max(0, $0) }
        let maxValue = maxLimit.map { max(0, $0) }

        if let minValue, let maxValue, minValue > maxValue {
            settings.categories[categoryIndex].subcategories[subIndex].minLimit = maxValue
            settings.categories[categoryIndex].subcategories[subIndex].maxLimit = minValue
            return
        }

        settings.categories[categoryIndex].subcategories[subIndex].minLimit = minValue
        settings.categories[categoryIndex].subcategories[subIndex].maxLimit = maxValue
    }

    func updateSubcategoryPriority(
        categoryType: ExpenseCategoryType,
        subcategoryID: UUID,
        priority: Int
    ) {
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }
        guard let subIndex = settings.categories[categoryIndex].subcategories.firstIndex(where: { $0.id == subcategoryID }) else { return }

        settings.categories[categoryIndex].subcategories[subIndex].priority = max(1, priority)
    }

    func addSubcategory(
        categoryType: ExpenseCategoryType,
        name: String,
        percentage: Double,
        minLimit: Double? = nil,
        maxLimit: Double? = nil,
        priority: Int = 1
    ) {
        guard let categoryIndex = settings.categories.firstIndex(where: { $0.type == categoryType }) else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newSubcategory = Subcategory(
            name: trimmed,
            percentage: max(0, min(100, percentage)),
            fixedMinimumPercentage: nil,
            minLimit: minLimit.map { max(0, $0) },
            maxLimit: maxLimit.map { max(0, $0) },
            priority: max(1, priority)
        )

        settings.categories[categoryIndex].subcategories.append(newSubcategory)
    }

    func canSaveSubcategoryPercents(for categoryType: ExpenseCategoryType) -> Bool {
        guard let category = settings.categories.first(where: { $0.type == categoryType }) else { return false }
        return category.subcategoriesTotalPercentage <= 100.0001
    }

    func currentSettings() -> BudgetSettings {
        settings
    }
}
