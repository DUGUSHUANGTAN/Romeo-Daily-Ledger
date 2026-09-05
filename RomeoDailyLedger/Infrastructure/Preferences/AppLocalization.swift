import AppKit
import Foundation
import SwiftUI

enum AppLocalization {
    static func text(_ key: String, language: AppLanguage) -> String {
        let localizedBundle: Bundle
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            localizedBundle = bundle
        } else {
            localizedBundle = .main
        }
        return localizedBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func format(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: text(key, language: language), locale: language.locale, arguments: arguments)
    }

    static func categoryName(systemKey: String?, customName: String? = nil, language: AppLanguage) -> String {
        if let customName, !customName.isEmpty { return customName }
        guard let systemKey else { return text("category.other", language: language) }
        let key = "category.\(systemKey)"
        let localized = text(key, language: language)
        return localized == key ? systemKey : localized
    }

    @MainActor
    static func updateApplicationMenuTitle(in menu: NSMenu?, language: AppLanguage) {
        refreshApplicationMenu(in: menu, language: language)
        DispatchQueue.main.async {
            refreshApplicationMenu(in: NSApp.mainMenu, language: language)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                refreshApplicationMenu(in: NSApp.mainMenu, language: language)
            }
        }
    }

    @MainActor
    private static func refreshApplicationMenu(in menu: NSMenu?, language: AppLanguage) {
        guard let menu,
              let currentItem = menu.items.first,
              let appMenu = currentItem.submenu else { return }
        let title = text("app.name", language: language)

        currentItem.title = title
        currentItem.attributedTitle = NSAttributedString(string: title)
        appMenu.title = title
        localizeApplicationMenuItems(in: appMenu, language: language)
    }

    @MainActor
    private static func localizeApplicationMenuItems(in menu: NSMenu?, language: AppLanguage) {
        guard let menu else { return }
        let appName = text("app.name", language: language)
        let knownNames = AppLanguage.allCases.map { text("app.name", language: $0) }
        for item in menu.items {
            let title = knownNames.reduce(item.title) { result, knownName in
                result.replacingOccurrences(of: knownName, with: appName)
            }
            if item.title != title { item.title = title }
        }
    }

}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .simplifiedChinese
}

private struct AppCurrencyCodeEnvironmentKey: EnvironmentKey {
    static let defaultValue = "USD"
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }

    var appCurrencyCode: String {
        get { self[AppCurrencyCodeEnvironmentKey.self] }
        set { self[AppCurrencyCodeEnvironmentKey.self] = newValue }
    }
}
