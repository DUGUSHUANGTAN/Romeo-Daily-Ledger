import AppKit
import SwiftUI

enum LucideIcon: String, CaseIterable, Hashable, Sendable {
    case ledger = "wallet-cards"
    case aiAssistant = "bot"
    case calendar = "calendar-days"
    case insights = "chart-no-axes-column-increasing"
    case history
    case categories = "tags"
    case settings

    static let version = "0.468.0"

    func svgData(bundle: Bundle = .main) -> Data? {
        guard let url = bundle.url(forResource: rawValue, withExtension: "svg", subdirectory: "Lucide") ?? bundle.url(forResource: rawValue, withExtension: "svg") else { return nil }
        return try? Data(contentsOf: url)
    }

    func image(bundle: Bundle = .main) -> Image {
        guard let data = svgData(bundle: bundle), let image = NSImage(data: data) else { return Image(nsImage: NSImage(size: NSSize(width: 20, height: 20))) }
        image.isTemplate = true
        return Image(nsImage: image)
    }
}

struct LucideIconView: View {
    let icon: LucideIcon
    var size: CGFloat = 18

    var body: some View {
        icon.image().resizable().renderingMode(.template).scaledToFit().frame(width: size, height: size).accessibilityHidden(true)
    }
}
