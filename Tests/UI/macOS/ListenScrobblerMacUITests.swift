import XCTest

final class ListenScrobblerMacUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Do not let macOS restore a previously hidden SwiftUI Window scene in
        // the UI-test process. This keeps each test independent of the user's
        // saved window state and makes the runner deterministic on macOS.
        app.launchArguments = [
            "--skip-onboarding",
            "--ui-test",
            "-ApplePersistenceIgnoreState",
            "YES",
            "-ui.showDockIcon",
            "YES"
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    func testPrimaryNavigationUsesSidebarWithoutBottomTabBar() {
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["sidebar.dashboard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["sidebar.scrobbles"].exists)
        XCTAssertEqual(app.tabBars.count, 0)
    }

    func testQueueIsReachableFromSidebar() {
        let queue = app.descendants(matching: .any)["sidebar.queue"]
        XCTAssertTrue(queue.waitForExistence(timeout: 5))
        queue.firstMatch.click()
        XCTAssertTrue(app.descendants(matching: .any)["queue.title"].waitForExistence(timeout: 3))
    }
}
