import SwiftUI

enum AppTypography {
    enum Style: String, CaseIterable, Identifiable, Sendable {
        case system, editorial, rounded
        var id: Self { self }
        var usesBundledFont: Bool { false }
    }

    static func display(_ style: Style) -> Font { font(style, size: 30, weight: .semibold) }
    static func title(_ style: Style) -> Font { font(style, size: 20, weight: .semibold) }
    static func body(_ style: Style) -> Font { font(style, size: 14, weight: .regular) }
    static func caption(_ style: Style) -> Font { font(style, size: 12, weight: .medium) }

    private static func font(_ style: Style, size: CGFloat, weight: Font.Weight) -> Font {
        switch style {
        case .system: .system(size: size, weight: weight, design: .default)
        case .editorial: .system(size: size, weight: weight, design: .serif)
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        }
    }
}
