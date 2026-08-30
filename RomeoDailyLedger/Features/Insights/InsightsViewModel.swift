import Foundation
import Observation

@Observable
@MainActor
final class InsightsViewModel {
    private(set) var calendar: Calendar
    private(set) var displayedMonth: Date
    private(set) var report: InsightsReport
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: LedgerRepository
    private let aggregator: InsightsAggregator
    private var categoriesByID: [UUID: Category] = [:]

    init(
        repository: LedgerRepository,
        aggregator: InsightsAggregator = InsightsAggregator(),
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        initialDate: Date = .now
    ) {
        var localCalendar = calendar
        localCalendar.timeZone = timeZone
        self.calendar = localCalendar
        self.repository = repository
        self.aggregator = aggregator
        self.displayedMonth = localCalendar.dateInterval(of: .month, for: initialDate)!.start
        let interval = localCalendar.dateInterval(of: .month, for: initialDate)!
        self.report = InsightsReport(interval: interval, income: 0, expense: 0, categories: [])
    }

    var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth)!
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await repository.seedDefaultsIfNeeded()
            let interval = monthInterval
            let entries = try await repository.entries(in: interval)
            let expenseCategories = try await repository.categories(kind: .expense)
            let incomeCategories = try await repository.categories(kind: .income)
            categoriesByID = Dictionary(uniqueKeysWithValues: (expenseCategories + incomeCategories).map { ($0.id, $0) })
            report = aggregator.makeReport(entries: entries, interval: interval)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func moveMonth(by offset: Int) async {
        guard let target = calendar.date(byAdding: .month, value: offset, to: displayedMonth),
              let start = calendar.dateInterval(of: .month, for: target)?.start else { return }
        displayedMonth = start
        await load()
    }

    func displayName(for summary: InsightsCategorySummary) -> String {
        guard !summary.isOther, let category = categoriesByID[summary.categoryID] else { return "其他" }
        return LedgerFormatting.categoryName(category)
    }
}
