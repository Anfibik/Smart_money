import Foundation
import Combine

struct BudgetHistoryDaySection: Identifiable, Hashable {
    let date: Date
    let title: String
    let events: [BudgetHistoryEvent]

    var id: Date { date }
}

@MainActor
final class HistoryAndStatisticsViewModel: ObservableObject {
    @Published private(set) var currencyCode: String
    @Published private(set) var summary: BudgetStatisticsSummary = .empty
    @Published private(set) var availableMonths: [HistoryMonthOption] = []
    @Published private(set) var availableYears: [Int] = []
    @Published private(set) var historySections: [BudgetHistoryDaySection] = []

    @Published var periodMode: HistoryPeriodMode = .month {
        didSet {
            guard !isAdjustingSelection else { return }
            refreshOutputs()
        }
    }

    @Published var selectedMonth: HistoryMonthOption? {
        didSet {
            guard !isAdjustingSelection, periodMode == .month else { return }
            refreshOutputs()
        }
    }

    @Published var selectedYear: Int? {
        didSet {
            guard !isAdjustingSelection, periodMode == .year else { return }
            refreshOutputs()
        }
    }

    @Published var entryFilter: HistoryEntryFilter = .all {
        didSet {
            rebuildHistorySections()
        }
    }

    private let statisticsService: BudgetStatisticsService
    private let calendar: Calendar
    private let locale: Locale
    private var allEvents: [BudgetHistoryEvent] = []
    private var currentPeriodEvents: [BudgetHistoryEvent] = []
    private var isAdjustingSelection = false
    private var cancellables = Set<AnyCancellable>()

    init(
        budgetViewModel: BudgetViewModel,
        statisticsService: BudgetStatisticsService? = nil,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) {
        self.statisticsService = statisticsService ?? BudgetStatisticsService(calendar: calendar)
        self.calendar = calendar
        self.locale = locale
        self.currencyCode = budgetViewModel.settings.currencyCode

        let currentComponents = calendar.dateComponents([.year, .month], from: Date())
        self.selectedMonth = HistoryMonthOption(
            year: currentComponents.year ?? 0,
            month: currentComponents.month ?? 1
        )
        self.selectedYear = currentComponents.year

        bind(to: budgetViewModel)
        handleHistoryUpdate(
            events: budgetViewModel.historyEvents,
            currencyCode: budgetViewModel.settings.currencyCode
        )
    }

    private func bind(to budgetViewModel: BudgetViewModel) {
        budgetViewModel.$historyEvents
            .combineLatest(budgetViewModel.$settings.map(\.currencyCode))
            .sink { [weak self] events, currencyCode in
                self?.handleHistoryUpdate(events: events, currencyCode: currencyCode)
            }
            .store(in: &cancellables)
    }

    private func handleHistoryUpdate(events: [BudgetHistoryEvent], currencyCode: String) {
        self.currencyCode = currencyCode
        allEvents = events.sorted { $0.createdAt > $1.createdAt }
        availableMonths = statisticsService.availableMonths(from: allEvents)
        availableYears = statisticsService.availableYears(from: allEvents)
        normalizeSelection()
        refreshOutputs()
    }

    private func normalizeSelection() {
        let currentComponents = calendar.dateComponents([.year, .month], from: Date())
        let fallbackMonth = HistoryMonthOption(
            year: currentComponents.year ?? 0,
            month: currentComponents.month ?? 1
        )
        let fallbackYear = currentComponents.year ?? 0

        isAdjustingSelection = true
        defer { isAdjustingSelection = false }

        if let selectedMonth, availableMonths.contains(selectedMonth) {
            self.selectedMonth = selectedMonth
        } else {
            self.selectedMonth = availableMonths.first ?? fallbackMonth
        }

        if let selectedYear, availableYears.contains(selectedYear) {
            self.selectedYear = selectedYear
        } else {
            self.selectedYear = availableYears.first ?? fallbackYear
        }
    }

    private func refreshOutputs() {
        currentPeriodEvents = statisticsService.eventsForSelectedPeriod(
            from: allEvents,
            mode: periodMode,
            selectedMonth: selectedMonth,
            selectedYear: selectedYear
        )

        summary = statisticsService.buildSummary(from: currentPeriodEvents)

        rebuildHistorySections()
    }

    private func rebuildHistorySections() {
        let filteredEvents = currentPeriodEvents.filter { entryFilter.matches($0) }
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.createdAt)
        }

        historySections = grouped.keys
            .sorted(by: >)
            .map { date in
                BudgetHistoryDaySection(
                    date: date,
                    title: daySectionTitle(for: date),
                    events: grouped[date, default: []].sorted { $0.createdAt > $1.createdAt }
                )
            }
    }

    private func daySectionTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date).capitalized
    }
}
