import XCTest

final class ListenScrobblerMacUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    func testPrimaryNavigationUsesSidebarWithoutBottomTabBar() {
        XCTAssertTrue(app.windows["ListenScrobbler"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar.dashboard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["sidebar.scrobbles"].exists)
        XCTAssertEqual(app.tabBars.count, 0)
    }

    func testQueueIsReachableFromSidebar() {
        let queue = app.descendants(matching: .any)["sidebar.queue"]
        XCTAssertTrue(queue.waitForExistence(timeout: 5))
        queue.click()
        XCTAssertTrue(app.staticTexts["Submission Queue"].waitForExistence(timeout: 3))
    }
}
