import XCTest
@testable import PhonoDeck

@MainActor
final class AppStateTests: XCTestCase {
    func testSidebarToggleIsDeterministic() {
        let appState = AppState()
        let initial = appState.isSidebarVisible

        appState.toggleSidebar()
        XCTAssertEqual(appState.isSidebarVisible, !initial)

        appState.toggleSidebar()
        XCTAssertEqual(appState.isSidebarVisible, initial)
    }
}