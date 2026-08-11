import Foundation

public enum AppLocalization {
    private struct ProcessContext {
        let selectedLanguage: AppLanguage
        let availableLanguages: [SupportedLanguage]
        let effectiveLanguageIdentifier: String
        let effectiveLanguageIdentifiers: [String]
        let effectiveLocale: Locale
        let localizedBundle: Bundle
    }

    /// One immutable context keeps the whole process in a single language.
    /// It also keeps the hot string-rendering path O(1): catalog discovery,
    /// locale matching, native-name generation, and defaults reads happen once
    /// per launch instead of once for every label or list cell.
    private static let processContext: ProcessContext = {
        let bundle = Bundle.main
        let availableLanguages = discoverSupportedLanguagesUncached(in: bundle)
        let storedLanguage = AppLanguageStore.shared.load()
        let selectedLanguage: AppLanguage
        if storedLanguage.isSystem {
            selectedLanguage = .system
        } else if let matched = fallbackIdentifiers(for: storedLanguage.rawValue)
            .first(where: { candidate in
                availableLanguages.contains { $0.identifier == candidate }
            }) {
            selectedLanguage = AppLanguage(rawValue: matched)
        } else {
            selectedLanguage = .system
        }
        if selectedLanguage != storedLanguage {
            AppLanguageStore.shared.save(selectedLanguage)
        }
        let effectiveLanguageIdentifier = resolveLanguageIdentifier(
            selectedLanguage: selectedLanguage,
            availableLanguages: availableLanguages,
            preferredLanguages: Locale.preferredLanguages,
            developmentLanguage: bundle.developmentLocalization
        )
        let effectiveLanguageIdentifiers = contentLanguageIdentifiers(
            for: effectiveLanguageIdentifier,
            availableLanguages: availableLanguages,
            developmentLanguage: bundle.developmentLocalization
        )
        let effectiveLocale = locale(
            languageCode: effectiveLanguageIdentifier,
            regionLocale: .current
        )
        let localizedBundle = resolveLocalizedBundle(
            in: bundle,
            languageIdentifier: effectiveLanguageIdentifier,
            availableLanguages: availableLanguages
        )
        return ProcessContext(
            selectedLanguage: selectedLanguage,
            availableLanguages: availableLanguages,
            effectiveLanguageIdentifier: effectiveLanguageIdentifier,
            effectiveLanguageIdentifiers: effectiveLanguageIdentifiers,
            effectiveLocale: effectiveLocale,
            localizedBundle: localizedBundle
        )
    }()

    // MARK: - Process-wide resolved state

    public static var selectedLanguage: AppLanguage {
        processContext.selectedLanguage
    }

    public static var availableLanguages: [SupportedLanguage] {
        processContext.availableLanguages
    }

    public static var effectiveLanguageIdentifier: String {
        processContext.effectiveLanguageIdentifier
    }

    /// Ordered metadata/content fallback identifiers for the effective UI
    /// language. For example, `zh-Hans-CN` becomes `zh-Hans-CN, zh-Hans, zh, en`.
    public static var effectiveLanguageIdentifiers: [String] {
        processContext.effectiveLanguageIdentifiers
    }

    public static var effectiveLocale: Locale {
        processContext.effectiveLocale
    }

    public static var localizedBundle: Bundle {
        processContext.localizedBundle
    }

    // MARK: - Explicit localized strings

    /// Resolves a string literal or interpolation using the language selected
    /// inside ListenScrobbler rather than the process' launch language.
    ///
    /// `LocalizedStringResource` preserves typed interpolation arguments, so a
    /// call such as `AppLocalization.string("Loaded \(count) listens")` uses the
    /// same catalog key and plural/format metadata as `String(localized:)`.
    public static func string(
        _ resource: LocalizedStringResource,
        bundle: Bundle = .main,
        language: AppLanguage? = nil,
        regionLocale: Locale? = nil,
        store: AppLanguageStore? = nil,
        preferredLanguages: [String]? = nil
    ) -> String {
        if bundle === Bundle.main,
           language == nil,
           regionLocale == nil,
           store == nil,
           preferredLanguages == nil {
            return String(
                localized: resource.defaultValue,
                table: resource.table,
                bundle: processContext.localizedBundle,
                locale: processContext.effectiveLocale
            )
        }

        let languages = discoverSupportedLanguages(in: bundle)
        let identifier = resolveLanguageIdentifier(
            selectedLanguage: language ?? store?.load() ?? selectedLanguage,
            availableLanguages: languages,
            preferredLanguages: preferredLanguages ?? Locale.preferredLanguages,
            developmentLanguage: bundle.developmentLocalization
        )
        let resolvedLocale = locale(
            languageCode: identifier,
            regionLocale: regionLocale ?? .current
        )
        let resolvedBundle = resolveLocalizedBundle(
            in: bundle,
            languageIdentifier: identifier,
            availableLanguages: languages
        )

        // The default value carries the localization key plus all typed format
        // arguments for normal literals/interpolations. Supplying the bundle and
        // locale explicitly is what lets an in-app choice override the process
        // language selected by the operating system at launch.
        return String(
            localized: resource.defaultValue,
            table: resource.table,
            bundle: resolvedBundle,
            locale: resolvedLocale
        )
    }

    /// Resolves operating-system-owned text using the process/device language,
    /// intentionally ignoring ListenScrobbler's in-app override. App Intents,
    /// Siri, and similar system surfaces should use this explicitly.
    public static func systemString(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    /// Formats a localized C-style resource with the app's selected locale.
    /// `String.localizedStringWithFormat` uses the device locale for plural
    /// selection, which would ignore an in-app language choice (for example,
    /// Russian `one/few/many`). This wrapper keeps both lookup and formatting
    /// on the same locale.
    public static func localizedStringWithFormat(
        _ format: String,
        locale: Locale? = nil,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: format,
            locale: locale ?? processContext.effectiveLocale,
            arguments: arguments
        )
    }

    // MARK: - Language discovery and resolution

    /// Treats the bundle's compiled localizations as the publication manifest.
    /// Adding a complete localization to the String Catalog makes it available
    /// without adding a case or editing a list in Swift.
    public static func discoverSupportedLanguages(in bundle: Bundle = .main) -> [SupportedLanguage] {
        if bundle === Bundle.main {
            return processContext.availableLanguages
        }
        return discoverSupportedLanguagesUncached(in: bundle)
    }

    private static func discoverSupportedLanguagesUncached(
        in bundle: Bundle
    ) -> [SupportedLanguage] {
        var resourceIdentifiers = bundle.localizations
        if let development = bundle.developmentLocalization,
           !resourceIdentifiers.contains(development) {
            resourceIdentifiers.append(development)
        }

        let developmentIdentifier = canonicalLanguageIdentifier(
            bundle.developmentLocalization ?? ""
        )
        var languagesByIdentifier: [String: SupportedLanguage] = [:]
        for resourceIdentifier in resourceIdentifiers where resourceIdentifier != "Base" {
            guard let identifier = canonicalLanguageIdentifier(resourceIdentifier) else { continue }
            // InfoPlist-only localizations must not appear in the app-language
            // picker. The development language is source-backed and may not
            // produce a physical Localizable.strings file in the bundle.
            guard identifier == developmentIdentifier
                    || containsLocalizableCatalog(
                        resourceIdentifier: resourceIdentifier,
                        in: bundle
                    ) else {
                continue
            }
            if languagesByIdentifier[identifier] == nil {
                languagesByIdentifier[identifier] = SupportedLanguage(
                    identifier: identifier,
                    resourceIdentifier: resourceIdentifier
                )
            }
        }

        return languagesByIdentifier.values.sorted {
            let comparison = $0.nativeName.localizedCaseInsensitiveCompare($1.nativeName)
            return comparison == .orderedSame
                ? $0.identifier < $1.identifier
                : comparison == .orderedAscending
        }
    }

    public static func resolveEffectiveLanguageIdentifier(
        bundle: Bundle = .main,
        store: AppLanguageStore? = nil,
        preferredLanguages: [String]? = nil,
        availableLanguages: [SupportedLanguage]? = nil
    ) -> String {
        if bundle === Bundle.main,
           store == nil,
           preferredLanguages == nil,
           availableLanguages == nil {
            return processContext.effectiveLanguageIdentifier
        }
        let languages = availableLanguages ?? discoverSupportedLanguages(in: bundle)
        return resolveLanguageIdentifier(
            selectedLanguage: store?.load() ?? selectedLanguage,
            availableLanguages: languages,
            preferredLanguages: preferredLanguages ?? Locale.preferredLanguages,
            developmentLanguage: bundle.developmentLocalization
        )
    }

    public static func resolveEffectiveLanguageIdentifiers(
        bundle: Bundle = .main,
        store: AppLanguageStore? = nil,
        preferredLanguages: [String]? = nil,
        availableLanguages: [SupportedLanguage]? = nil
    ) -> [String] {
        if bundle === Bundle.main,
           store == nil,
           preferredLanguages == nil,
           availableLanguages == nil {
            return processContext.effectiveLanguageIdentifiers
        }
        let languages = availableLanguages ?? discoverSupportedLanguages(in: bundle)
        let effective = resolveEffectiveLanguageIdentifier(
            bundle: bundle,
            store: store,
            preferredLanguages: preferredLanguages,
            availableLanguages: languages
        )
        return contentLanguageIdentifiers(
            for: effective,
            availableLanguages: languages,
            developmentLanguage: bundle.developmentLocalization
        )
    }

    public static func resolveEffectiveLocale(
        bundle: Bundle = .main,
        store: AppLanguageStore? = nil,
        preferredLanguages: [String]? = nil,
        regionLocale: Locale? = nil,
        availableLanguages: [SupportedLanguage]? = nil
    ) -> Locale {
        if bundle === Bundle.main,
           store == nil,
           preferredLanguages == nil,
           regionLocale == nil,
           availableLanguages == nil {
            return processContext.effectiveLocale
        }
        return locale(
            languageCode: resolveEffectiveLanguageIdentifier(
                bundle: bundle,
                store: store,
                preferredLanguages: preferredLanguages,
                availableLanguages: availableLanguages
            ),
            regionLocale: regionLocale ?? .current
        )
    }

    /// Resolves either a manual language or the system preference list against
    /// the catalogs that are actually compiled into the app.
    public static func resolveLanguageIdentifier(
        selectedLanguage: AppLanguage,
        availableLanguages: [SupportedLanguage],
        preferredLanguages: [String] = Locale.preferredLanguages,
        developmentLanguage: String? = nil
    ) -> String {
        if !selectedLanguage.isSystem,
           let selected = matchLanguage(selectedLanguage.rawValue, in: availableLanguages) {
            return selected
        }

        if selectedLanguage.isSystem {
            for preferredLanguage in preferredLanguages {
                if let matched = matchLanguage(preferredLanguage, in: availableLanguages) {
                    return matched
                }
            }
        }

        if let english = matchLanguage("en", in: availableLanguages) {
            return english
        }
        if let developmentLanguage,
           let development = matchLanguage(developmentLanguage, in: availableLanguages) {
            return development
        }
        if let first = availableLanguages.first {
            return first.identifier
        }
        return canonicalLanguageIdentifier(developmentLanguage ?? "") ?? "en"
    }

    /// Produces progressively broader BCP-47 fallbacks without collapsing all
    /// languages to two letters. Extensions are removed before parent matching.
    public static func fallbackIdentifiers(for identifier: String) -> [String] {
        guard let canonical = canonicalLanguageIdentifier(identifier) else { return [] }
        var components = canonical.split(separator: "-").map(String.init)
        if let extensionIndex = components.dropFirst().firstIndex(where: { $0.count == 1 }) {
            components = Array(components[..<extensionIndex])
        }

        var result: [String] = []
        while !components.isEmpty {
            appendUnique(components.joined(separator: "-"), to: &result)
            components.removeLast()
        }
        return result
    }

    public static func canonicalLanguageIdentifier(_ identifier: String) -> String? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.caseInsensitiveCompare("Base") != .orderedSame else {
            return nil
        }

        let canonical = Locale.canonicalLanguageIdentifier(from: trimmed)
            .replacingOccurrences(of: "_", with: "-")
        let components = canonical.split(separator: "-", omittingEmptySubsequences: false)
        guard let language = components.first,
              (2...8).contains(language.count),
              language.allSatisfy(\.isLetter),
              components.dropFirst().allSatisfy({ component in
                  (1...8).contains(component.count)
                      && component.allSatisfy { $0.isLetter || $0.isNumber }
              }) else {
            return nil
        }
        return canonical
    }

    public static func resolveLocalizedBundle(
        in bundle: Bundle = .main,
        languageIdentifier: String,
        availableLanguages: [SupportedLanguage]? = nil
    ) -> Bundle {
        let languages = availableLanguages ?? discoverSupportedLanguages(in: bundle)
        guard let matchedIdentifier = matchLanguage(languageIdentifier, in: languages),
              let language = languages.first(where: { $0.identifier == matchedIdentifier }),
              let localizationURL = bundle.url(
                  forResource: language.resourceIdentifier,
                  withExtension: "lproj"
              ),
              let localizationBundle = Bundle(url: localizationURL) else {
            return bundle
        }
        return localizationBundle
    }

    public static func languageName(
        for identifier: String,
        displayLocale: Locale,
        availableLanguages: [SupportedLanguage]
    ) -> String {
        if let language = availableLanguages.first(where: { $0.identifier == identifier }) {
            return language.localizedName(in: displayLocale)
        }
        return SupportedLanguage(identifier: identifier).localizedName(in: displayLocale)
    }

    // MARK: - Locale-aware formatting

    /// Legacy convenience for services that require a base ISO language code.
    /// Use `effectiveLanguageIdentifiers` when an API accepts BCP-47 fallbacks.
    public static func languageCode(bundle: Bundle = .main) -> String {
        let identifier = resolveEffectiveLanguageIdentifier(bundle: bundle)
        return Locale(identifier: identifier).language.languageCode?.identifier.lowercased()
            ?? identifier.split(separator: "-").first.map(String.init)?.lowercased()
            ?? "en"
    }

    public static func locale(
        bundle: Bundle = .main,
        regionLocale: Locale? = nil
    ) -> Locale {
        resolveEffectiveLocale(bundle: bundle, regionLocale: regionLocale)
    }

    public static func locale(languageCode: String, regionLocale: Locale = .current) -> Locale {
        let languageIdentifier = canonicalLanguageIdentifier(languageCode) ?? "en"
        if containsRegionSubtag(languageIdentifier) {
            return Locale(identifier: languageIdentifier)
        }
        guard let region = regionLocale.region?.identifier, !region.isEmpty else {
            return Locale(identifier: languageIdentifier)
        }
        return Locale(identifier: "\(languageIdentifier)-\(region)")
    }

    public static func integer(
        _ value: Int,
        bundle: Bundle = .main,
        regionLocale: Locale? = nil
    ) -> String {
        integer(
            value,
            locale: locale(bundle: bundle, regionLocale: regionLocale)
        )
    }

    public static func integer(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

    public static func date(
        _ value: Date,
        date: Date.FormatStyle.DateStyle,
        time: Date.FormatStyle.TimeStyle,
        bundle: Bundle = .main,
        regionLocale: Locale? = nil
    ) -> String {
        AppLocalization.date(
            value,
            date: date,
            time: time,
            locale: locale(bundle: bundle, regionLocale: regionLocale)
        )
    }

    public static func date(
        _ value: Date,
        date: Date.FormatStyle.DateStyle,
        time: Date.FormatStyle.TimeStyle,
        locale: Locale
    ) -> String {
        value.formatted(
            Date.FormatStyle(date: date, time: time)
                .locale(locale)
        )
    }

    // MARK: - Private helpers

    private static func matchLanguage(
        _ requestedIdentifier: String,
        in availableLanguages: [SupportedLanguage]
    ) -> String? {
        let availableIdentifiers = Set(availableLanguages.map(\.identifier))
        return fallbackIdentifiers(for: requestedIdentifier).first(where: availableIdentifiers.contains)
    }

    private static func appendUnique(_ value: String, to values: inout [String]) {
        if !values.contains(value) {
            values.append(value)
        }
    }

    private static func contentLanguageIdentifiers(
        for effectiveIdentifier: String,
        availableLanguages: [SupportedLanguage],
        developmentLanguage: String?
    ) -> [String] {
        var identifiers = fallbackIdentifiers(for: effectiveIdentifier)
        if let english = matchLanguage("en", in: availableLanguages) {
            appendUnique(english, to: &identifiers)
        } else if let development = canonicalLanguageIdentifier(developmentLanguage ?? "") {
            appendUnique(development, to: &identifiers)
        }
        return identifiers
    }

    private static func containsLocalizableCatalog(
        resourceIdentifier: String,
        in bundle: Bundle
    ) -> Bool {
        guard let localizationURL = bundle.url(
            forResource: resourceIdentifier,
            withExtension: "lproj"
        ) else {
            return false
        }
        let fileManager = FileManager.default
        return ["strings", "stringsdict"].contains { extensionName in
            fileManager.fileExists(
                atPath: localizationURL
                    .appendingPathComponent("Localizable.\(extensionName)")
                    .path
            )
        }
    }

    private static func containsRegionSubtag(_ identifier: String) -> Bool {
        identifier.split(separator: "-").dropFirst().contains { component in
            (component.count == 2 && component.allSatisfy(\.isLetter))
                || (component.count == 3 && component.allSatisfy(\.isNumber))
        }
    }
}
