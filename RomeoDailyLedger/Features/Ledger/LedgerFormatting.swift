import Foundation

enum LedgerFormatting {
    static func amount(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        let number = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0.00"
        return number.hasPrefix("-") ? "-$" + number.dropFirst() : "$" + number
    }

    static func categoryName(_ category: Category) -> String {
        if let customName = category.customName, !customName.isEmpty { return customName }
        return switch category.systemKey {
        case "clothing": "服饰"
        case "food": "餐饮"
        case "housing": "居住"
        case "transport": "交通"
        case "entertainment": "娱乐"
        case "salary": "工资"
        case "bonus": "奖金"
        case "investment": "投资"
        case "refund": "退款"
        default: "其他"
        }
    }
}
