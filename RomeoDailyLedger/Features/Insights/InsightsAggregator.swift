import Foundation

struct InsightsCategorySummary: Equatable, Identifiable, Sendable {
    let categoryID: UUID
    let kind: EntryKind
    let amount: Decimal
    let share: Decimal
    let isOther: Bool

    var id: String { "\(kind.rawValue)-\(categoryID.uuidString)" }
}

struct InsightsReport: Equatable, Sendable {
    let interval: DateInterval
    let income: Decimal
    let expense: Decimal
    let categories: [InsightsCategorySummary]

    var net: Decimal { income - expense }
    var balance: Decimal { net }
    var isEmpty: Bool { income == 0 && expense == 0 && categories.isEmpty }
    var categoryTotals: [UUID: Decimal] {
        categories.reduce(into: [:]) { totals, category in
            totals[category.categoryID, default: 0] += category.amount
        }
    }

    func category(id: UUID, kind: EntryKind? = nil) -> InsightsCategorySummary? {
        categories.first { $0.categoryID == id && (kind == nil || $0.kind == kind) }
    }
}

struct InsightsAggregator: Sendable {
    /// The ledger repository normally resolves a missing category to its persisted
    /// “other” category. This stable value lets imported or legacy uncategorized
    /// entries follow the same rule without introducing repository access here.
    static let uncategorizedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    func makeReport(entries: [LedgerEntry], interval: DateInterval) -> InsightsReport {
        let included = entries.filter { interval.containsHalfOpen($0.occurredAt) }
        let income = total(for: .income, in: included)
        let expense = total(for: .expense, in: included)
        let kindTotals: [EntryKind: Decimal] = [.income: income, .expense: expense]

        struct CategoryKey: Hashable {
            let id: UUID
            let kind: EntryKind
        }

        let categoryAmounts = included.reduce(into: [CategoryKey: Decimal]()) { totals, entry in
            let key = CategoryKey(id: entry.categoryID, kind: entry.kind)
            totals[key, default: 0] += entry.amount
        }

        let categories = categoryAmounts.map { key, amount in
            let denominator = kindTotals[key.kind, default: 0]
            return InsightsCategorySummary(
                categoryID: key.id,
                kind: key.kind,
                amount: amount,
                share: denominator == 0 ? 0 : amount / denominator,
                isOther: key.id == Self.uncategorizedCategoryID
            )
        }
        .sorted {
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            if $0.amount != $1.amount { return $0.amount > $1.amount }
            return $0.categoryID.uuidString < $1.categoryID.uuidString
        }

        return InsightsReport(interval: interval, income: income, expense: expense, categories: categories)
    }

    private func total(for kind: EntryKind, in entries: [LedgerEntry]) -> Decimal {
        entries.lazy.filter { $0.kind == kind }.reduce(Decimal.zero) { $0 + $1.amount }
    }
}

private extension DateInterval {
    func containsHalfOpen(_ date: Date) -> Bool {
        date >= start && date < end
    }
}
