import Foundation
import Testing
@testable import RomeoDailyLedger

@Suite("Ledger formatting")
struct LedgerFormattingTests {
    @Test func currencySymbolCanPrefixEditableAmounts() {
        #expect(LedgerFormatting.currencySymbol(for: "CNY") == "¥")
        #expect(LedgerFormatting.currencySymbol(for: "USD") == "$")
        #expect(LedgerFormatting.currencySymbol(for: "EUR") == "€")
    }
    @Test func amountUsesApprovedDefaultUSDCurrency() {
        #expect(LedgerFormatting.amount(Decimal(string: "12.50")!) == "$12.50")
    }

    @Test(arguments: [
        ("CNY", "¥12.50"), ("JPY", "¥12.50"), ("EUR", "€12.50"),
        ("GBP", "£12.50"), ("HKD", "HK$12.50"), ("ZZZ", "ZZZ 12.50"),
    ])
    func amountUsesApprovedCurrencySymbols(code: String, expected: String) {
        #expect(LedgerFormatting.amount(Decimal(string: "12.50")!, currencyCode: code) == expected)
    }

    @Test func negativeAmountPlacesSignBeforeCurrencySymbol() {
        #expect(LedgerFormatting.amount(Decimal(string: "-12.50")!, currencyCode: "EUR") == "-€12.50")
    }

    @Test func allEntriesGroupByLocalDateDescendingWithStableTies() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let first = LedgerEntry(kind: .expense, amount: 1, categoryID: UUID(), note: "first", occurredAt: Date(timeIntervalSince1970: 1_800_000_000))
        let second = LedgerEntry(kind: .expense, amount: 2, categoryID: UUID(), note: "second", occurredAt: first.occurredAt)
        let later = LedgerEntry(kind: .income, amount: 3, categoryID: UUID(), note: "later", occurredAt: calendar.date(byAdding: .day, value: 1, to: first.occurredAt)!)

        let groups = LedgerEntryGrouping.groups([first, second, later], calendar: calendar)

        #expect(groups.count == 2)
        #expect(groups[0].entries.map(\.note) == ["later"])
        #expect(groups[1].entries.map(\.note) == ["first", "second"])
    }

    @Test func categoryEditPolicyRestoresSystemDefaultAndRejectsEmptyCustomName() throws {
        #expect(try CategoryEditPolicy.displayName(systemKey: "food", input: "   ") == nil)
        #expect(throws: LedgerRepositoryValidationError.emptyCustomCategoryName) {
            try CategoryEditPolicy.displayName(systemKey: nil, input: "   ")
        }
        #expect(try CategoryEditPolicy.displayName(systemKey: nil, input: "  Coffee  ") == "Coffee")
    }

    @Test func fallbackDefaultExpenseNamesUseExpandedV102Wording() {
        let categories = [
            Category(kind: .expense, systemKey: "clothing", iconName: "", colorToken: "", sortOrder: 0),
            Category(kind: .expense, systemKey: "food", iconName: "", colorToken: "", sortOrder: 1),
            Category(kind: .expense, systemKey: "housing", iconName: "", colorToken: "", sortOrder: 2),
            Category(kind: .expense, systemKey: "transport", iconName: "", colorToken: "", sortOrder: 3),
        ]

        #expect(categories.map { LedgerFormatting.categoryName($0, language: .simplifiedChinese) } == ["衣物", "食物", "住宿", "行程"])
    }
}
