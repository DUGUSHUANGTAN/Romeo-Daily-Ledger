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
        return text("category.\(systemKey)", language: language)
    }

    static func userContent(_ value: String, language _: AppLanguage) -> String { value }
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
