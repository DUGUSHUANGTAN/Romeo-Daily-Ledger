import Foundation

enum LedgerFormatting {
    static func amount(_ value: Decimal, currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        let number = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0.00"
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let symbol = currencySymbol(for: code)
        return number.hasPrefix("-") ? "-" + symbol + number.dropFirst() : symbol + number
    }

    static func currencySymbol(for code: String) -> String {
        let approved = ["CNY": "¥", "JPY": "¥", "USD": "$", "EUR": "€", "GBP": "£", "HKD": "HK$"]
        if let symbol = approved[code] { return symbol }
        if Locale.commonISOCurrencyCodes.contains(code),
           let locale = Locale.availableIdentifiers.lazy.map(Locale.init(identifier:)).first(where: { $0.currency?.identifier == code }),
           let symbol = locale.currencySymbol, symbol != code { return symbol }
        return "\(code) "
    }

    static func categoryName(_ category: Category) -> String {
        if let customName = category.customName, !customName.isEmpty { return customName }
        return switch category.systemKey {
        case "clothing": "衣物"
        case "food": "食物"
        case "housing": "住宿"
        case "transport": "行程"
        case "entertainment": "娱乐"
        case "salary": "工资"
        case "bonus": "奖金"
        case "investment": "投资"
        case "refund": "退款"
        default: "其他"
        }
    }

    static func categoryName(_ category: Category, language: AppLanguage) -> String {
        AppLocalization.categoryName(systemKey: category.systemKey, customName: category.customName, language: language)
    }
}

enum LedgerEntryGrouping {
    struct Group: Identifiable {
        let date: Date
        let entries: [LedgerEntry]
        var id: Date { date }
    }

    static func groups(_ entries: [LedgerEntry], calendar: Calendar = .autoupdatingCurrent) -> [Group] {
        let sorted = entries.enumerated().sorted { lhs, rhs in
            lhs.element.occurredAt == rhs.element.occurredAt ? lhs.offset < rhs.offset : lhs.element.occurredAt > rhs.element.occurredAt
        }.map(\.element)
        let grouped = Dictionary(grouping: sorted) { calendar.startOfDay(for: $0.occurredAt) }
        return grouped.keys.sorted(by: >).map { Group(date: $0, entries: grouped[$0] ?? []) }
    }
}

enum CategorySelection {
    static func available(from categories: [Category], selectedID: UUID?) -> [Category] {
        categories.filter { !$0.isHidden || $0.id == selectedID }
    }
}
