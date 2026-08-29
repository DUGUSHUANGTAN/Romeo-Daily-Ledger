import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var systemKey: String?
    var customName: String?
    var iconName: String
    var colorToken: String
    var sortOrder: Int
    var isHidden: Bool

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw)! }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        kind: EntryKind,
        systemKey: String? = nil,
        customName: String? = nil,
        iconName: String,
        colorToken: String,
        sortOrder: Int,
        isHidden: Bool = false
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.systemKey = systemKey
        self.customName = customName
        self.iconName = iconName
        self.colorToken = colorToken
        self.sortOrder = sortOrder
        self.isHidden = isHidden
    }
}
