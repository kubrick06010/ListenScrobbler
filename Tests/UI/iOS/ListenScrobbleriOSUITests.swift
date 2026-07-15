import XCTest

final class ListenScrobbleriOSUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "--skip-onboarding",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
    }

    func testCompactNavigationExposesFourPrimaryTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8))
        XCTAssertTrue(tabBar.buttons["Home"].exists)
        XCTAssertTrue(tabBar.buttons["Listens"].exists)
        XCTAssertTrue(tabBar.buttons["Discover"].exists)
        XCTAssertTrue(tabBar.buttons["Account"].exists)
    }

    func testListensAndManualScrobbleAreReachable() {
        let listens = app.tabBars.buttons["Listens"]
        XCTAssertTrue(listens.waitForExistence(timeout: 8))
        listens.tap()
        XCTAssertTrue(app.navigationBars["Listens"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["listens.add"].exists)
    }
}
