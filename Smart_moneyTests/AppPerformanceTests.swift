import SwiftUI
import UIKit
import XCTest
@testable import Smart_money

@MainActor
final class AppPerformanceTests: XCTestCase {
    func testLargeBudgetAllocationPerformance() {
        let settings = makeLargeSettings(cardsPerCategory: 200)
        let engine = Smart_money.BudgetAllocationEngine()
        let options = measureOptions(iterations: 10)
        var allocatedTotal = 0.0

        measure(
            metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()],
            options: options
        ) {
            var baselines: [UUID: Double] = [:]
            var allocations: [UUID: Double] = [:]
            var bankBalance = 0.0
            var categoryRemainders: [UUID: Double] = [:]
            var automaticDistributions: [UUID: Double] = [:]

            engine.applyIncomeDelta(
                1_000_000,
                settings: settings,
                categoryTargetBaselineByID: &baselines,
                allocatedBySubcategoryID: &allocations,
                bankBalance: &bankBalance,
                lastIncomeToBankByCategoryID: &categoryRemainders,
                lastBankAutoDistributedBySubcategoryID: &automaticDistributions
            )

            allocatedTotal = allocations.values.reduce(0, +) + bankBalance
        }

        XCTAssertEqual(allocatedTotal, 1_000_000, accuracy: 0.01)
    }

    func testStatisticsAggregationPerformance() {
        let events = makeHistoryEvents(count: 10_000)
        let service = Smart_money.BudgetStatisticsService(calendar: performanceCalendar)
        let options = measureOptions(iterations: 10)
        var summary = Smart_money.BudgetStatisticsSummary.empty

        measure(
            metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()],
            options: options
        ) {
            summary = service.buildSummary(from: events)
        }

        XCTAssertEqual(summary.operationCount, events.count)
        XCTAssertEqual(summary.incomeOperationsCount + summary.expenseOperationsCount, events.count)
    }

    func testBudgetViewModelColdStartPerformance() throws {
        let events = makeHistoryEvents(count: 3_000)
        let directory = makeTemporaryDirectory(named: "cold-start")
        let writer = Smart_money.BudgetHistoryStorage(
            directoryURL: directory,
            fileName: "history.json"
        )
        writer.replaceAll(events)

        let options = measureOptions(iterations: 5)
        var loadedEventCount = 0

        measure(
            metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()],
            options: options
        ) {
            let suiteName = "AppPerformanceTests-cold-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            let viewModel = Smart_money.BudgetViewModel(
                income: 0,
                settings: Smart_money.BudgetSettings(),
                persistenceService: Smart_money.PersistenceService(
                    defaults: defaults,
                    storageKey: "budget-state"
                ),
                allocationEngine: Smart_money.BudgetAllocationEngine(),
                historyStorage: Smart_money.BudgetHistoryStorage(
                    directoryURL: directory,
                    fileName: "history.json"
                )
            )
            loadedEventCount = viewModel.historyEvents.count
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertEqual(loadedEventCount, events.count)
    }

    func testStatisticsInterfaceLayoutPerformance() {
        let events = makeHistoryEvents(count: 600)
        let viewModel = makeBudgetViewModel(historyEvents: events)
        let options = measureOptions(iterations: 1)
        var renderedSize = CGSize.zero

        measure(
            metrics: [XCTClockMetric(), XCTCPUMetric(), XCTMemoryMetric()],
            options: options
        ) {
            autoreleasepool {
                let controller = UIHostingController(
                    rootView: NavigationStack {
                        Smart_money.HistoryAndStatisticsView(budgetViewModel: viewModel)
                    }
                )
                let frame = CGRect(x: 0, y: 0, width: 390, height: 844)
                let window = UIWindow(frame: frame)
                window.rootViewController = controller
                window.makeKeyAndVisible()
                controller.view.frame = frame
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()

                let renderer = UIGraphicsImageRenderer(size: frame.size)
                _ = renderer.image { _ in
                    controller.view.drawHierarchy(in: frame, afterScreenUpdates: true)
                }
                renderedSize = controller.view.bounds.size
                window.resignKey()
                window.isHidden = true
                window.rootViewController = nil
            }
        }

        XCTAssertEqual(renderedSize.width, 390, accuracy: 0.01)
        XCTAssertEqual(renderedSize.height, 844, accuracy: 0.01)
    }

    private var performanceCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func measureOptions(iterations: Int) -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = iterations
        return options
    }

    private func makeLargeSettings(cardsPerCategory: Int) -> Smart_money.BudgetSettings {
        let categoryPercentages: [Double] = [60, 15, 25]
        let categories = Smart_money.ExpenseCategoryType.allCases.enumerated().map { categoryIndex, type in
            let subcategories = (0..<cardsPerCategory).map { cardIndex in
                Smart_money.Subcategory(
                    name: "Card \(categoryIndex)-\(cardIndex)",
                    iconName: "creditcard.fill",
                    percentage: Double((cardIndex % 10) + 1),
                    minLimit: Double((cardIndex % 5) * 100),
                    maxLimit: cardIndex.isMultiple(of: 7) ? 15_000 : nil,
                    priority: (cardIndex % 3) + 1
                )
            }
            return Smart_money.ExpenseCategory(
                type: type,
                percentage: categoryPercentages[categoryIndex],
                subcategories: subcategories
            )
        }
        return Smart_money.BudgetSettings(categories: categories, currencyCode: "UAH")
    }

    private func makeHistoryEvents(count: Int) -> [Smart_money.BudgetHistoryEvent] {
        let calendar = performanceCalendar
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let monthStart = calendar.date(
            from: DateComponents(year: components.year, month: components.month, day: 1)
        )!
        let cardIDs = (0..<30).map { _ in UUID() }

        return (0..<count).map { index in
            let isIncome = index.isMultiple(of: 5)
            let categoryType = Smart_money.ExpenseCategoryType.allCases[index % 3]
            return Smart_money.BudgetHistoryEvent(
                createdAt: monthStart.addingTimeInterval(Double(index % (27 * 24 * 60 * 60))),
                type: isIncome ? .income : .expense,
                amount: Double((index % 500) + 1),
                currencyCode: "UAH",
                categoryType: isIncome ? nil : categoryType,
                categoryTitleSnapshot: isIncome ? nil : categoryType.title,
                subcategoryID: isIncome ? nil : cardIDs[index % cardIDs.count],
                subcategoryNameSnapshot: isIncome ? nil : "Card \(index % cardIDs.count)",
                iconNameSnapshot: isIncome ? nil : "creditcard.fill"
            )
        }
    }

    private func makeBudgetViewModel(
        historyEvents: [Smart_money.BudgetHistoryEvent]
    ) -> Smart_money.BudgetViewModel {
        let directory = makeTemporaryDirectory(named: "interface")
        let historyStorage = Smart_money.BudgetHistoryStorage(
            directoryURL: directory,
            fileName: "history.json"
        )
        historyStorage.replaceAll(historyEvents)
        let suiteName = "AppPerformanceTests-interface-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        return Smart_money.BudgetViewModel(
            income: 0,
            settings: Smart_money.BudgetSettings(),
            persistenceService: Smart_money.PersistenceService(
                defaults: defaults,
                storageKey: "budget-state"
            ),
            allocationEngine: Smart_money.BudgetAllocationEngine(),
            historyStorage: historyStorage
        )
    }

    private func makeTemporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AppPerformanceTests-\(name)-\(UUID().uuidString)", isDirectory: true)
    }
}
