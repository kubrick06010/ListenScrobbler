import XCTest
@testable import ListenScrobbler

final class LocalizationTests: XCTestCase {
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
            guard let entry = value as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let spanish = localizations["es"] as? [String: Any],
                  let stringUnit = spanish["stringUnit"] as? [String: Any],
                  let translatedValue = stringUnit["value"] as? String,
                  !translatedValue.isEmpty else {
                return key
            }
            return nil
        }

        XCTAssertTrue(
            missingSpanish.isEmpty,
            "Every catalog key must include Spanish. Missing: \(missingSpanish.sorted().joined(separator: ", "))"
        )
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

    func testSpanishLocalizationPreservesProductNames() throws {
        let strings = try stringCatalogEntries()
        XCTAssertEqual(localizedValue(in: strings["ListenBrainz"], language: "es"), "ListenBrainz")
        XCTAssertEqual(localizedValue(in: strings["ListenScrobbler"], language: "es"), "ListenScrobbler")
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
        guard let entry = rawEntry as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any],
              let localization = localizations[language] as? [String: Any],
              let stringUnit = localization["stringUnit"] as? [String: Any] else {
            return nil
        }
        return stringUnit["value"] as? String
    }

    private func formatArguments(in value: String) -> [String] {
        let expression = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(lld|ld|d|@|\.\d+f|f|%)"#)
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard let argumentRange = Range(match.range(at: 1), in: value) else { return nil }
            return String(value[argumentRange])
        }
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
