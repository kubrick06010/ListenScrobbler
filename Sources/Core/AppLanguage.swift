import Combine
import Foundation

/// An open language selection stored as a canonical BCP-47 identifier.
///
/// Unlike an enum of known languages, this type does not need to change when a
/// new localization is added to the app bundle. The special `system` value asks
/// the resolver to follow the user's preferred system languages.
public struct AppLanguage: RawRepresentable, Codable, Hashable, Identifiable, Sendable {
    public static let system = AppLanguage(rawValue: "system")

    public let rawValue: String

    public var id: String { rawValue }
    public var isSystem: Bool { rawValue == Self.system.rawValue }

    public init(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        // Do not reference `Self.system` while initializing the `Self.system`
        // static itself; doing so recursively enters Swift's dispatch-once lock.
        if trimmed.caseInsensitiveCompare("system") == .orderedSame {
            self.rawValue = "system"
        } else {
            self.rawValue = AppLocalization.canonicalLanguageIdentifier(trimmed) ?? "system"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A localization that is compiled into, and therefore published by, the app.
public struct SupportedLanguage: Identifiable, Hashable, Sendable {
    public let identifier: String
    public let resourceIdentifier: String

    public var id: String { identifier }
    public var locale: Locale { Locale(identifier: identifier) }

    /// The language name in that language, so a user can always recognize it.
    public var nativeName: String {
        languageName(in: locale)
    }

    public init(identifier: String, resourceIdentifier: String? = nil) {
        let canonical = AppLocalization.canonicalLanguageIdentifier(identifier) ?? identifier
        self.identifier = canonical
        self.resourceIdentifier = resourceIdentifier ?? identifier
    }

    /// The language name translated into a particular UI locale.
    public func localizedName(in locale: Locale) -> String {
        languageName(in: locale)
    }

    private func languageName(in displayLocale: Locale) -> String {
        let name = displayLocale.localizedString(forIdentifier: identifier)
            ?? displayLocale.localizedString(
                forLanguageCode: locale.language.languageCode?.identifier ?? identifier
            )
            ?? identifier
        return name.capitalized(with: displayLocale)
    }
}

/// Persists the selected language in the shared app group, with standard
/// defaults as a migration and non-entitled-process fallback.
public struct AppLanguageStore: @unchecked Sendable {
    public static let defaultSuiteName = "group.org.listenscrobbler.app"
    public static let defaultKey = "localization.selectedLanguage"
    public static let shared = AppLanguageStore()

    private let primaryDefaults: UserDefaults?
    private let fallbackDefaults: UserDefaults
    private let key: String

    public init(
        suiteName: String = AppLanguageStore.defaultSuiteName,
        fallbackDefaults: UserDefaults = .standard,
        key: String = AppLanguageStore.defaultKey
    ) {
        self.primaryDefaults = UserDefaults(suiteName: suiteName)
        self.fallbackDefaults = fallbackDefaults
        self.key = key
    }

    /// Dependency-injection initializer used by tests and isolated processes.
    public init(
        primaryDefaults: UserDefaults?,
        fallbackDefaults: UserDefaults,
        key: String = AppLanguageStore.defaultKey
    ) {
        self.primaryDefaults = primaryDefaults
        self.fallbackDefaults = fallbackDefaults
        self.key = key
    }

    public func load() -> AppLanguage {
        guard let storedValue = primaryDefaults?.string(forKey: key)
                ?? fallbackDefaults.string(forKey: key) else {
            return .system
        }
        return AppLanguage(rawValue: storedValue)
    }

    public func save(_ language: AppLanguage) {
        if let primaryDefaults {
            primaryDefaults.set(language.rawValue, forKey: key)
        }
        // Mirroring the tiny preference makes the fallback real even when a
        // process can construct the suite but lacks a usable app-group domain.
        fallbackDefaults.set(language.rawValue, forKey: key)
    }
}

/// Observable application-wide language state for SwiftUI scenes.
@MainActor
public final class LocalizationController: ObservableObject {
    @Published public var selectedLanguage: AppLanguage {
        didSet {
            guard selectedLanguage != oldValue else { return }
            store.save(selectedLanguage)
            hasPendingLanguageChange = selectedLanguage != activeLanguage
        }
    }

    @Published public private(set) var availableLanguages: [SupportedLanguage]
    @Published public private(set) var hasPendingLanguageChange: Bool
    @Published public private(set) var effectiveLanguageIdentifier: String
    @Published public private(set) var effectiveLocale: Locale
    @Published public private(set) var effectiveLanguageName: String
    @Published public private(set) var systemLanguageIdentifier: String
    @Published public private(set) var systemLanguageName: String
    public private(set) var localizedBundle: Bundle

    private let bundle: Bundle
    private let store: AppLanguageStore
    private let activeLanguage: AppLanguage
    private let preferredLanguagesOverride: [String]?
    private let regionLocaleOverride: Locale?

    public init(
        bundle: Bundle = .main,
        store: AppLanguageStore = .shared,
        preferredLanguages: [String]? = nil,
        regionLocale: Locale? = nil
    ) {
        self.bundle = bundle
        self.store = store
        self.preferredLanguagesOverride = preferredLanguages
        self.regionLocaleOverride = regionLocale

        let discovered = AppLocalization.discoverSupportedLanguages(in: bundle)
        let storedSelection = store.load()
        let selected: AppLanguage
        if storedSelection.isSystem {
            selected = .system
        } else if let matched = AppLocalization.fallbackIdentifiers(for: storedSelection.rawValue)
            .first(where: { candidate in
                discovered.contains { $0.identifier == candidate }
            }) {
            selected = AppLanguage(rawValue: matched)
        } else {
            selected = .system
        }
        if selected != storedSelection {
            store.save(selected)
        }
        let systemIdentifier = AppLocalization.resolveLanguageIdentifier(
            selectedLanguage: .system,
            availableLanguages: discovered,
            preferredLanguages: preferredLanguages ?? Locale.preferredLanguages,
            developmentLanguage: bundle.developmentLocalization
        )
        let effectiveIdentifier = AppLocalization.resolveLanguageIdentifier(
            selectedLanguage: selected,
            availableLanguages: discovered,
            preferredLanguages: preferredLanguages ?? Locale.preferredLanguages,
            developmentLanguage: bundle.developmentLocalization
        )
        let resolvedLocale = AppLocalization.locale(
            languageCode: effectiveIdentifier,
            regionLocale: regionLocale ?? .current
        )

        availableLanguages = discovered
        selectedLanguage = selected
        activeLanguage = selected
        hasPendingLanguageChange = false
        systemLanguageIdentifier = systemIdentifier
        systemLanguageName = AppLocalization.languageName(
            for: systemIdentifier,
            displayLocale: resolvedLocale,
            availableLanguages: discovered
        )
        effectiveLanguageIdentifier = effectiveIdentifier
        effectiveLocale = resolvedLocale
        effectiveLanguageName = AppLocalization.languageName(
            for: effectiveIdentifier,
            displayLocale: resolvedLocale,
            availableLanguages: discovered
        )
        localizedBundle = AppLocalization.resolveLocalizedBundle(
            in: bundle,
            languageIdentifier: effectiveIdentifier,
            availableLanguages: discovered
        )

    }

    public func select(_ language: AppLanguage) {
        selectedLanguage = language
    }

    /// Re-discovers bundled catalogs and re-evaluates the system-language match.
    public func refresh() {
        availableLanguages = AppLocalization.discoverSupportedLanguages(in: bundle)
        recalculateEffectiveLanguage()
    }

    private func recalculateEffectiveLanguage() {
        let preferredLanguages = preferredLanguagesOverride ?? Locale.preferredLanguages
        let regionLocale = regionLocaleOverride ?? .current

        systemLanguageIdentifier = AppLocalization.resolveLanguageIdentifier(
            selectedLanguage: .system,
            availableLanguages: availableLanguages,
            preferredLanguages: preferredLanguages,
            developmentLanguage: bundle.developmentLocalization
        )
        effectiveLanguageIdentifier = AppLocalization.resolveLanguageIdentifier(
            selectedLanguage: activeLanguage,
            availableLanguages: availableLanguages,
            preferredLanguages: preferredLanguages,
            developmentLanguage: bundle.developmentLocalization
        )
        effectiveLocale = AppLocalization.locale(
            languageCode: effectiveLanguageIdentifier,
            regionLocale: regionLocale
        )
        systemLanguageName = AppLocalization.languageName(
            for: systemLanguageIdentifier,
            displayLocale: effectiveLocale,
            availableLanguages: availableLanguages
        )
        effectiveLanguageName = AppLocalization.languageName(
            for: effectiveLanguageIdentifier,
            displayLocale: effectiveLocale,
            availableLanguages: availableLanguages
        )
        localizedBundle = AppLocalization.resolveLocalizedBundle(
            in: bundle,
            languageIdentifier: effectiveLanguageIdentifier,
            availableLanguages: availableLanguages
        )
    }
}
