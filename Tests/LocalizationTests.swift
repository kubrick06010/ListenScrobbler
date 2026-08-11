import XCTest
@testable import ListenScrobbler

final class LocalizationTests: XCTestCase {
    private let publishedTranslationIdentifiers = [
        "de", "es", "fr", "it", "ja", "pl", "pt", "ru", "sv", "tr", "zh-Hans"
    ]

    func testAppLanguageUsesOpenCanonicalBCP47Identifiers() {
        XCTAssertEqual(AppLanguage.system.rawValue, "system")
        XCTAssertEqual(AppLanguage(rawValue: "es_ES").rawValue, "es-ES")
        XCTAssertEqual(AppLanguage(rawValue: "zh_CN").rawValue, "zh-Hans")
        XCTAssertEqual(AppLanguage(rawValue: "pt-BR").rawValue, "pt-BR")
        XCTAssertEqual(AppLanguage(rawValue: "not a locale!").rawValue, "system")
    }

    func testLanguageStorePersistsCanonicalIdentifierAndFallsBackSafely() throws {
        let primarySuite = "LocalizationTests-primary-\(UUID().uuidString)"
        let fallbackSuite = "LocalizationTests-fallback-\(UUID().uuidString)"
        let primary = try XCTUnwrap(UserDefaults(suiteName: primarySuite))
        let fallback = try XCTUnwrap(UserDefaults(suiteName: fallbackSuite))
        defer {
            primary.removePersistentDomain(forName: primarySuite)
            fallback.removePersistentDomain(forName: fallbackSuite)
        }

        let store = AppLanguageStore(
            primaryDefaults: primary,
            fallbackDefaults: fallback
        )
        XCTAssertEqual(store.load(), .system)

        fallback.set("fr_CA", forKey: AppLanguageStore.defaultKey)
        XCTAssertEqual(store.load().rawValue, "fr-CA")

        store.save(AppLanguage(rawValue: "zh_CN"))
        XCTAssertEqual(primary.string(forKey: AppLanguageStore.defaultKey), "zh-Hans")
        XCTAssertEqual(fallback.string(forKey: AppLanguageStore.defaultKey), "zh-Hans")

        primary.set("not a locale!", forKey: AppLanguageStore.defaultKey)
        XCTAssertEqual(store.load(), .system)
    }

    func testBCP47FallbacksPreserveScriptAndRegion() {
        XCTAssertEqual(
            AppLocalization.fallbackIdentifiers(for: "zh-Hans-CN"),
            ["zh-Hans-CN", "zh-Hans", "zh"]
        )
        XCTAssertEqual(
            AppLocalization.fallbackIdentifiers(for: "pt_BR"),
            ["pt-BR", "pt"]
        )
        XCTAssertEqual(
            AppLocalization.fallbackIdentifiers(for: "de-DE-u-co-phonebk"),
            ["de-DE", "de"]
        )
    }

    func testLanguageResolutionSupportsSystemManualAndParentFallbacks() {
        let available = [
            SupportedLanguage(identifier: "en"),
            SupportedLanguage(identifier: "es"),
            SupportedLanguage(identifier: "pt"),
            SupportedLanguage(identifier: "zh-Hans")
        ]

        XCTAssertEqual(
            AppLocalization.resolveLanguageIdentifier(
                selectedLanguage: .system,
                availableLanguages: available,
                preferredLanguages: ["ca-ES", "zh_CN"],
                developmentLanguage: "en"
            ),
            "zh-Hans"
        )
        XCTAssertEqual(
            AppLocalization.resolveLanguageIdentifier(
                selectedLanguage: AppLanguage(rawValue: "pt-BR"),
                availableLanguages: available,
                preferredLanguages: ["es"],
                developmentLanguage: "en"
            ),
            "pt"
        )
        XCTAssertEqual(
            AppLocalization.resolveLanguageIdentifier(
                selectedLanguage: AppLanguage(rawValue: "fr"),
                availableLanguages: available,
                preferredLanguages: ["es"],
                developmentLanguage: "en"
            ),
            "en"
        )
    }

    @MainActor
    func testLocalizationControllerPersistsSelectionForNextLaunchAtomically() throws {
        let suiteName = "LocalizationTests-controller-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppLanguageStore(
            primaryDefaults: defaults,
            fallbackDefaults: defaults
        )

        let controller = LocalizationController(
            bundle: .main,
            store: store,
            preferredLanguages: ["es-MX", "en"],
            regionLocale: Locale(identifier: "en_US")
        )

        XCTAssertTrue(controller.availableLanguages.contains { $0.identifier == "es" })
        XCTAssertEqual(controller.systemLanguageIdentifier, "es")
        XCTAssertEqual(controller.effectiveLanguageIdentifier, "es")
        XCTAssertEqual(controller.effectiveLocale.language.languageCode?.identifier, "es")
        XCTAssertEqual(controller.effectiveLocale.region?.identifier, "US")

        controller.selectedLanguage = AppLanguage(rawValue: "en")

        XCTAssertTrue(controller.hasPendingLanguageChange)
        XCTAssertEqual(controller.effectiveLanguageIdentifier, "es")
        XCTAssertEqual(controller.effectiveLocale.language.languageCode?.identifier, "es")
        XCTAssertEqual(store.load().rawValue, "en")

        let relaunchedController = LocalizationController(
            bundle: .main,
            store: store,
            preferredLanguages: ["es-MX", "en"],
            regionLocale: Locale(identifier: "en_US")
        )
        XCTAssertFalse(relaunchedController.hasPendingLanguageChange)
        XCTAssertEqual(relaunchedController.selectedLanguage.rawValue, "en")
        XCTAssertEqual(relaunchedController.effectiveLanguageIdentifier, "en")
        XCTAssertEqual(relaunchedController.effectiveLocale.language.languageCode?.identifier, "en")
    }

    func testExplicitStringLocalizationHonorsManualLanguageAndInterpolation() {
        XCTAssertEqual(
            AppLocalization.string(
                "Account",
                bundle: applicationBundle,
                language: AppLanguage(rawValue: "es"),
                regionLocale: Locale(identifier: "es_ES")
            ),
            "Cuenta"
        )

        let recommendationCount = 3
        let localized = AppLocalization.string(
            "Loaded \(recommendationCount) recommendations",
            bundle: applicationBundle,
            language: AppLanguage(rawValue: "es"),
            regionLocale: Locale(identifier: "es_ES")
        )
        XCTAssertTrue(localized.contains("3"))
        XCTAssertNotEqual(localized, "Loaded 3 recommendations")
    }

    private var applicationBundle: Bundle {
        var appURL = Bundle.main.bundleURL
        while appURL.pathExtension != "app" && appURL.path != "/" {
            appURL.deleteLastPathComponent()
        }
        return Bundle(url: appURL)
            ?? Bundle(identifier: "org.listenscrobbler.app")
            ?? Bundle.main
    }

    func testAppLocaleUsesSelectedLanguageAndKeepsRegionalConventions() {
        let spanishUS = AppLocalization.locale(
            languageCode: "es",
            regionLocale: Locale(identifier: "en_US")
        )
        let englishSpain = AppLocalization.locale(
            languageCode: "en",
            regionLocale: Locale(identifier: "es_ES")
        )

        XCTAssertEqual(spanishUS.language.languageCode?.identifier, "es")
        XCTAssertEqual(spanishUS.region?.identifier, "US")
        XCTAssertEqual(englishSpain.language.languageCode?.identifier, "en")
        XCTAssertEqual(englishSpain.region?.identifier, "ES")
    }

    func testLocalizedNumberAndDateFormattingFollowProvidedLocale() {
        XCTAssertEqual(
            AppLocalization.integer(1_234_567, locale: Locale(identifier: "es_ES")),
            "1.234.567"
        )
        XCTAssertEqual(
            AppLocalization.integer(1_234_567, locale: Locale(identifier: "en_US")),
            "1,234,567"
        )

        let date = Date(timeIntervalSince1970: 1_704_110_400) // 1 January 2024, UTC
        let spanish = AppLocalization.date(
            date,
            date: .long,
            time: .omitted,
            locale: Locale(identifier: "es_ES")
        )
        let english = AppLocalization.date(
            date,
            date: .long,
            time: .omitted,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertTrue(spanish.lowercased().contains("enero"))
        XCTAssertTrue(english.lowercased().contains("january"))
    }

    func testStringCatalogHasSpanishForEveryEnglishKey() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = repositoryRoot.appendingPathComponent("Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

        let missingSpanish = strings.compactMap { key, value -> String? in
            guard !localizedValues(in: value, language: "es").isEmpty,
                  localizedValues(in: value, language: "es")
                    .allSatisfy({ !$0.isEmpty }) else {
                return key
            }
            return nil
        }

        XCTAssertTrue(
            missingSpanish.isEmpty,
            "Every catalog key must include Spanish. Missing: \(missingSpanish.sorted().joined(separator: ", "))"
        )
    }

    func testWidgetSnapshotDecodesLegacyAndRoundTripsConnectionState() throws {
        let legacyJSON = #"{"connectionStatus":"Connect ListenBrainz","pendingCount":0,"updatedAt":0}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        let legacy = try decoder.decode(MobileWidgetSnapshot.self, from: legacyJSON)
        XCTAssertNil(legacy.connectionState)

        let current = MobileWidgetSnapshot(
            connectionStatus: "Connect ListenBrainz",
            connectionState: .disconnected,
            username: nil,
            recentListen: nil,
            currentPin: nil,
            recommendation: nil,
            pendingCount: 0,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        let roundTripped = try decoder.decode(
            MobileWidgetSnapshot.self,
            from: JSONEncoder().encode(current)
        )
        XCTAssertEqual(roundTripped.connectionState, .disconnected)
    }

    func testEveryPublishedLanguageCoversTheCompleteStringCatalog() throws {
        let strings = try stringCatalogEntries()

        for language in publishedTranslationIdentifiers {
            let missing = strings.compactMap { key, value -> String? in
                guard !localizedValues(in: value, language: language).isEmpty,
                      localizedValues(in: value, language: language)
                        .allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                    return key
                }
                return nil
            }
            XCTAssertTrue(
                missing.isEmpty,
                "\(language) must cover every catalog key. Missing: \(missing.sorted().joined(separator: ", "))"
            )
        }
    }

    func testBundlePublishesEveryLastFMDesktopLanguage() {
        let published = Set(AppLocalization.availableLanguages.map(\.identifier))
        XCTAssertEqual(
            published,
            Set(["en"] + publishedTranslationIdentifiers)
        )
    }

    func testNewLocalizationSurfacesAreInTheSharedCatalog() throws {
        let strings = try stringCatalogEntries()
        let requiredKeys = [
            "App", "App Language", "Connected to ListenBrainz",
            "Follow the language selected for this device.", "Language",
            "Language Changed", "Later", "Restart ListenScrobbler?", "Restart Now",
            "Some system-provided features follow the device language.",
            "System Language",
            "The selected language will be applied throughout ListenScrobbler after it restarts.",
            "The selected language will be applied throughout ListenScrobbler the next time you open the app.",
            "Archived shares", "Captured obsessions", "No shared music archived",
            "No obsessions captured", "No note captured.", "No message attached.",
            "%lld sent, %lld received, %lld imported",
            "%lld track shares ready for open playlist export", "Most shared with %@"
        ]
        let missing = requiredKeys.filter { strings[$0] == nil }
        XCTAssertTrue(missing.isEmpty, "New localization surfaces missing from catalog: \(missing.joined(separator: ", "))")
    }

    func testRussianRecommendationPluralChangesWithCount() {
        let one = AppLocalization.localizedStringWithFormat(
            AppLocalization.string(
                "%d recommendations loaded",
                language: AppLanguage(rawValue: "ru"),
                regionLocale: Locale(identifier: "ru_RU")
            ),
            locale: Locale(identifier: "ru_RU"),
            1
        )
        let many = AppLocalization.localizedStringWithFormat(
            AppLocalization.string(
                "%d recommendations loaded",
                language: AppLanguage(rawValue: "ru"),
                regionLocale: Locale(identifier: "ru_RU")
            ),
            locale: Locale(identifier: "ru_RU"),
            5
        )
        let digits = try! NSRegularExpression(pattern: #"\d+"#)
        func withoutCount(_ value: String) -> String {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            return digits.stringByReplacingMatches(in: value, range: range, withTemplate: "")
        }
        XCTAssertNotEqual(withoutCount(one), withoutCount(many))
    }

    func testSpanishLocalizationIncludesPrimaryMobileLabels() throws {
        let spanishBundle = try XCTUnwrap(
            Bundle.main.url(forResource: "es", withExtension: "lproj").flatMap(Bundle.init(url:)),
            "Expected the app bundle to include Spanish localization resources."
        )

        XCTAssertEqual(spanishBundle.localizedString(forKey: "Account", value: nil, table: nil), "Cuenta")
        XCTAssertEqual(spanishBundle.localizedString(forKey: "Discover", value: nil, table: nil), "Descubrir")
        XCTAssertEqual(spanishBundle.localizedString(forKey: "Connect ListenBrainz", value: nil, table: nil), "Conectar ListenBrainz")
        XCTAssertEqual(spanishBundle.localizedString(forKey: "Music Library Scrobbling", value: nil, table: nil), "Scrobbling de biblioteca musical")
        XCTAssertEqual(spanishBundle.localizedString(forKey: "Manual Scrobble", value: nil, table: nil), "Scrobble manual")
    }

    func testSpanishLocalizationPreservesFormatArguments() throws {
        let strings = try stringCatalogEntries()
        let mismatches = strings.compactMap { key, value -> String? in
            guard let spanish = localizedValue(in: value, language: "es") else { return key }
            let sourceArguments = formatArguments(in: key).sorted()
            let translatedArguments = formatArguments(in: spanish).sorted()
            return sourceArguments == translatedArguments ? nil : "\(key) → \(spanish)"
        }

        XCTAssertTrue(
            mismatches.isEmpty,
            "Translations must preserve format argument types. Mismatches: \(mismatches.sorted().joined(separator: ", "))"
        )
    }

    func testEveryPublishedLanguagePreservesFormatArguments() throws {
        let strings = try stringCatalogEntries()

        for language in publishedTranslationIdentifiers {
            let mismatches = strings.compactMap { key, value -> String? in
                let translatedValues = localizedValues(in: value, language: language)
                guard !translatedValues.isEmpty else { return key }
                let invalid = translatedValues.filter {
                    !formatArgumentsMatch(source: key, translated: $0)
                }
                return invalid.isEmpty ? nil : "\(key) → \(invalid.joined(separator: " | "))"
            }
            XCTAssertTrue(
                mismatches.isEmpty,
                "\(language) translations must preserve format arguments. Mismatches: \(mismatches.sorted().joined(separator: ", "))"
            )
        }
    }

    func testSpanishLocalizationPreservesProductNames() throws {
        let strings = try stringCatalogEntries()
        XCTAssertEqual(localizedValue(in: strings["ListenBrainz"], language: "es"), "ListenBrainz")
        XCTAssertEqual(localizedValue(in: strings["ListenScrobbler"], language: "es"), "ListenScrobbler")
    }

    func testEveryPublishedLanguagePreservesProductNames() throws {
        let strings = try stringCatalogEntries()
        for language in publishedTranslationIdentifiers {
            XCTAssertEqual(localizedValue(in: strings["ListenBrainz"], language: language), "ListenBrainz")
            XCTAssertEqual(localizedValue(in: strings["ListenScrobbler"], language: language), "ListenScrobbler")
        }
    }

    func testAppShortcutPhrasesAreLocalizedInSpanish() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = repositoryRoot.appendingPathComponent("Resources/AppShortcuts.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

        let invalidEntries = strings.compactMap { key, rawEntry -> String? in
            guard let entry = rawEntry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let english = localizations["en"] as? [String: Any],
                  let spanish = localizations["es"] as? [String: Any],
                  let englishSet = english["stringSet"] as? [String: Any],
                  let spanishSet = spanish["stringSet"] as? [String: Any],
                  let englishValues = englishSet["values"] as? [String],
                  let spanishValues = spanishSet["values"] as? [String],
                  !spanishValues.isEmpty else {
                return key
            }

            let englishTokens = Set(englishValues.flatMap(shortcutTokens))
            let spanishTokens = Set(spanishValues.flatMap(shortcutTokens))
            return englishTokens == spanishTokens ? nil : key
        }

        XCTAssertTrue(
            invalidEntries.isEmpty,
            "Every App Shortcut must include Spanish phrases with the same placeholders. Invalid: \(invalidEntries.sorted().joined(separator: ", "))"
        )
    }

    func testAppShortcutPhrasesCoverEveryPublishedLanguage() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = repositoryRoot.appendingPathComponent("Resources/AppShortcuts.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

        for language in publishedTranslationIdentifiers {
            let invalidEntries = strings.compactMap { key, rawEntry -> String? in
                guard let entry = rawEntry as? [String: Any],
                      let localizations = entry["localizations"] as? [String: Any],
                      let english = localizations["en"] as? [String: Any],
                      let translation = localizations[language] as? [String: Any],
                      let englishSet = english["stringSet"] as? [String: Any],
                      let translatedSet = translation["stringSet"] as? [String: Any],
                      let englishValues = englishSet["values"] as? [String],
                      let translatedValues = translatedSet["values"] as? [String],
                      !translatedValues.isEmpty else {
                    return key
                }

                return Set(englishValues.flatMap(shortcutTokens))
                    == Set(translatedValues.flatMap(shortcutTokens)) ? nil : key
            }
            XCTAssertTrue(
                invalidEntries.isEmpty,
                "\(language) App Shortcuts must preserve all tokens. Invalid: \(invalidEntries.sorted().joined(separator: ", "))"
            )
        }
    }

    func testEveryPublishedLanguageHasInfoPlistLocalization() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        for language in ["en"] + publishedTranslationIdentifiers {
            let stringsURL = repositoryRoot
                .appendingPathComponent("Resources")
                .appendingPathComponent("\(language).lproj")
                .appendingPathComponent("InfoPlist.strings")
            let contents = try String(contentsOf: stringsURL, encoding: .utf8)
            XCTAssertTrue(contents.contains("NSAppleMusicUsageDescription"), "Missing permission text for \(language)")
            XCTAssertTrue(contents.contains("NSAppleEventsUsageDescription"), "Missing Apple Events permission text for \(language)")
        }
    }

    private func stringCatalogEntries() throws -> [String: Any] {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = repositoryRoot.appendingPathComponent("Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(catalog["strings"] as? [String: Any])
    }

    private func localizedValue(in rawEntry: Any?, language: String) -> String? {
        localizedValues(in: rawEntry, language: language).first
    }

    private func localizedValues(in rawEntry: Any?, language: String) -> [String] {
        guard let entry = rawEntry as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let localization = localizations[language] as? [String: Any] else {
            return []
        }

        var values: [String] = []
        if let stringUnit = localization["stringUnit"] as? [String: Any],
           let value = stringUnit["value"] as? String {
            values.append(value)
        }
        if let variations = localization["variations"] as? [String: Any] {
            collectStringCatalogValues(from: variations, into: &values)
        }
        return values
    }

    private func collectStringCatalogValues(from rawValue: Any, into values: inout [String]) {
        if let dictionary = rawValue as? [String: Any],
           let stringUnit = dictionary["stringUnit"] as? [String: Any],
           let value = stringUnit["value"] as? String {
            values.append(value)
            return
        }
        if let dictionary = rawValue as? [String: Any] {
            for key in dictionary.keys.sorted() {
                if let child = dictionary[key] {
                    collectStringCatalogValues(from: child, into: &values)
                }
            }
        }
    }

    private func formatArguments(in value: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: #"%(?:(\d+)\$)?(lld|ld|d|@|\.\d+f|f|%)"#)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard let typeRange = Range(match.range(at: 2), in: value) else { return nil }
            let type = String(value[typeRange])
            guard match.range(at: 1).location != NSNotFound,
                  let indexRange = Range(match.range(at: 1), in: value) else {
                return type
            }
            return "\(value[indexRange])$\(type)"
        }
    }

    private func formatArgumentsMatch(source: String, translated: String) -> Bool {
        let sourceArguments = formatArguments(in: source)
        let translatedArguments = formatArguments(in: translated)
        guard sourceArguments.count == translatedArguments.count else { return false }

        let sourceTypes = sourceArguments.map { $0.split(separator: "$", maxSplits: 1).last.map(String.init) ?? $0 }
        let translatedHasExplicitPositions = translatedArguments.contains { $0.contains("$") }
        if translatedHasExplicitPositions {
            let indexes = translatedArguments.compactMap { argument -> Int? in
                let parts = argument.split(separator: "$", maxSplits: 1)
                return parts.count == 2 ? Int(parts[0]) : nil
            }
            guard Set(indexes) == Set(1...sourceTypes.count) else { return false }
            return translatedArguments.allSatisfy { argument in
                let parts = argument.split(separator: "$", maxSplits: 1)
                guard parts.count == 2,
                      let index = Int(parts[0]),
                      (1...sourceTypes.count).contains(index) else {
                    return false
                }
                return String(parts[1]) == sourceTypes[index - 1]
            }
        }
        return translatedArguments.map { $0.split(separator: "$", maxSplits: 1).last.map(String.init) ?? $0 }
            == sourceTypes
    }

    private func shortcutTokens(in value: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: #"\$\{[^}]+\}"#)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: value) else { return nil }
            return String(value[tokenRange])
        }
    }
}
