import AppKit
import Foundation
import SwiftUI

enum AppLocalization {
    @MainActor private static var currentApplicationMenuLanguage = AppLanguage.simplifiedChinese
    @MainActor private static weak var applicationMenuDelegate: NSMenuDelegate?

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

    static func replacingApplicationName(in source: String, language: AppLanguage) -> String {
        AppLanguage.allCases.reduce(source) { result, knownLanguage in
            result.replacingOccurrences(
                of: text("app.name", language: knownLanguage),
                with: text("app.name", language: language)
            )
        }
    }

    @MainActor
    static func installApplicationMenuDelegate(_ delegate: NSMenuDelegate) {
        applicationMenuDelegate = delegate
        NSApp.mainMenu?.items.first?.submenu?.delegate = delegate
    }

    @MainActor
    static func updateApplicationMenuTitle(in menu: NSMenu?, language: AppLanguage) {
        currentApplicationMenuLanguage = language
        refreshApplicationMenu(in: menu, language: language, replacingSystemItems: false)
        DispatchQueue.main.async {
            refreshApplicationMenu(in: NSApp.mainMenu, language: language, replacingSystemItems: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                refreshApplicationMenu(in: NSApp.mainMenu, language: language, replacingSystemItems: false)
            }
        }
    }

    @MainActor
    static func refreshApplicationMenuTitle(in menu: NSMenu?) {
        refreshApplicationMenu(
            in: menu,
            language: currentApplicationMenuLanguage,
            replacingSystemItems: true
        )
    }

    @MainActor
    static func updateWindowTitle(in window: NSWindow?, language: AppLanguage) {
        window?.title = text("app.name", language: language)
    }

    @MainActor
    private static func refreshApplicationMenu(
        in menu: NSMenu?,
        language: AppLanguage,
        replacingSystemItems: Bool
    ) {
        guard let menu,
              let currentItem = menu.items.first,
              let appMenu = currentItem.submenu else { return }
        let title = text("app.name", language: language)

        appMenu.delegate = applicationMenuDelegate
        currentItem.title = title
        currentItem.attributedTitle = NSAttributedString(string: title)
        appMenu.title = title
        localizeApplicationMenuItems(
            in: appMenu,
            language: language,
            replacingSystemItems: replacingSystemItems
        )
    }

    @MainActor
    private static func localizeApplicationMenuItems(
        in menu: NSMenu?,
        language: AppLanguage,
        replacingSystemItems: Bool
    ) {
        guard let menu else { return }
        for (index, item) in menu.items.enumerated() {
            let displayedTitle = item.attributedTitle?.string.isEmpty == false
                ? item.attributedTitle!.string
                : item.title
            let title = replacingApplicationName(in: displayedTitle, language: language)
            guard displayedTitle != title || item.title != title else { continue }

            if replacingSystemItems,
               item.action == #selector(NSApplication.hide(_:))
                || item.action == #selector(NSApplication.terminate(_:)) {
                let replacement = NSMenuItem(title: title, action: item.action, keyEquivalent: item.keyEquivalent)
                replacement.target = item.target
                replacement.keyEquivalentModifierMask = item.keyEquivalentModifierMask
                replacement.tag = item.tag
                replacement.state = item.state
                replacement.isEnabled = item.isEnabled
                replacement.isHidden = item.isHidden
                replacement.identifier = item.identifier
                replacement.attributedTitle = NSAttributedString(string: title)
                menu.removeItem(at: index)
                menu.insertItem(replacement, at: index)
            } else {
                item.title = title
                item.attributedTitle = NSAttributedString(string: title)
            }
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
