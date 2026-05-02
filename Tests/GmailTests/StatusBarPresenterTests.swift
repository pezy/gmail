import XCTest
@testable import Gmail

final class StatusBarPresenterTests: XCTestCase {
    func testNormalStateShowsCount() {
        let presentation = StatusBarPresenter.present(
            unreadCount: 5,
            authState: .signedIn(email: "alice@example.com"),
            connection: .online,
            lastError: nil
        )
        XCTAssertEqual(presentation.title, "5")
        XCTAssertEqual(presentation.tone, .normal)
        XCTAssertEqual(presentation.symbolName, "envelope")
    }

    func testZeroUnreadShowsEmptyTitle() {
        let presentation = StatusBarPresenter.present(
            unreadCount: 0,
            authState: .signedIn(email: "alice@example.com"),
            connection: .online,
            lastError: nil
        )
        XCTAssertEqual(presentation.title, "")
    }

    func testNeedsReauthorizationOverridesEverything() {
        let presentation = StatusBarPresenter.present(
            unreadCount: 5,
            authState: .needsReauthorization,
            connection: .offline,
            lastError: .api(.serverError(status: 500))
        )
        XCTAssertEqual(presentation.tone, .auth)
        XCTAssertEqual(presentation.symbolName, "envelope.badge.shield.half.filled")
    }

    func testAuthErrorBeatsNetworkAndAPI() {
        let presentation = StatusBarPresenter.present(
            unreadCount: 5,
            authState: .signedIn(email: "alice@example.com"),
            connection: .offline,
            lastError: .auth(.refreshTokenInvalid)
        )
        XCTAssertEqual(presentation.tone, .auth)
    }

    func testOfflineBeatsAPIError() {
        let presentation = StatusBarPresenter.present(
            unreadCount: 0,
            authState: .signedIn(email: "alice@example.com"),
            connection: .offline,
            lastError: .api(.serverError(status: 500))
        )
        XCTAssertEqual(presentation.tone, .network)
    }

    func testAPIErrorWhenOnline() {
        let presentation = StatusBarPresenter.present(
            unreadCount: 3,
            authState: .signedIn(email: "alice@example.com"),
            connection: .online,
            lastError: .api(.rateLimited(retryAfter: 60))
        )
        XCTAssertEqual(presentation.tone, .api)
    }

    func testSignedOutWithoutErrorIsNormal() {
        let presentation = StatusBarPresenter.present(
            unreadCount: 0,
            authState: .signedOut,
            connection: .online,
            lastError: nil
        )
        XCTAssertEqual(presentation.tone, .normal)
    }
}
