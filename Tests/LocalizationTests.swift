import XCTest

final class LocalizationTests: XCTestCase {
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
}
