import SwiftUI

struct AppColor: Equatable, Sendable {
    let hex: String

    init(hex: String) {
        self.hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
    }

    var color: Color {
        guard let value = UInt64(hex, radix: 16), hex.count == 6 else { return .clear }
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

enum ThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: Self { self }

    func resolve(systemIsDark: Bool) -> ResolvedTheme {
        switch self {
        case .system: systemIsDark ? .dark : .light
        case .light: .light
        case .dark: .dark
        }
    }
}

enum ResolvedTheme: Sendable { case light, dark }

struct AppTheme: Equatable, Sendable {
    let canvas: AppColor
    let chrome: AppColor
    let primaryText: AppColor
    let secondaryText: AppColor
    let primaryAccent: AppColor
    let secondaryAccent: AppColor
    let surface: AppColor
    let divider: AppColor

    static let light = AppTheme(canvas: AppColor(hex: "FFFDF8"), chrome: AppColor(hex: "EEE7DA"), primaryText: AppColor(hex: "28241E"), secondaryText: AppColor(hex: "625B50"), primaryAccent: AppColor(hex: "2F4F3E"), secondaryAccent: AppColor(hex: "E89769"), surface: AppColor(hex: "F3EDE1"), divider: AppColor(hex: "D7CDBC"))
    static let dark = AppTheme(canvas: AppColor(hex: "161B21"), chrome: AppColor(hex: "101318"), primaryText: AppColor(hex: "EEF1F4"), secondaryText: AppColor(hex: "AAB2B9"), primaryAccent: AppColor(hex: "B8E78C"), secondaryAccent: AppColor(hex: "839A72"), surface: AppColor(hex: "20262D"), divider: AppColor(hex: "343D46"))
}
