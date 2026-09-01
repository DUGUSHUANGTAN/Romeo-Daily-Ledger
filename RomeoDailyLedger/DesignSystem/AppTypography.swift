import SwiftUI

enum AppTypography {
    nonisolated(unsafe) static var currentScalePercent = 100

    enum Style: String, CaseIterable, Identifiable, Sendable {
        case system, editorial, rounded
        var id: Self { self }
        var usesBundledFont: Bool { false }
    }

    static func display(_ style: Style) -> Font { font(style, size: 30, weight: .semibold) }
    static func title(_ style: Style) -> Font { font(style, size: 20, weight: .semibold) }
    static func body(_ style: Style) -> Font { font(style, size: 14, weight: .regular) }
    static func caption(_ style: Style) -> Font { font(style, size: 12, weight: .medium) }

    static func scaleFactor(percent: Int) -> CGFloat {
        CGFloat(min(max(percent, 80), 140)) / 100
    }

    private static func font(_ style: Style, size: CGFloat, weight: Font.Weight) -> Font {
        let scaledSize = size * scaleFactor(percent: currentScalePercent)
        return switch style {
        case .system: .system(size: scaledSize, weight: weight, design: .default)
        case .editorial: .system(size: scaledSize, weight: weight, design: .serif)
        case .rounded: .system(size: scaledSize, weight: weight, design: .rounded)
        }
    }
}
