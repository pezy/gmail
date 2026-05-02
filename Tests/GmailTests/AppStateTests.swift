import XCTest
@testable import Gmail

@MainActor
final class AppStateTests: XCTestCase {
    func testInitialState() {
        let state = AppState()
        XCTAssertEqual(state.emails, [])
        XCTAssertEqual(state.unreadCount, 0)
        XCTAssertEqual(state.connectionState, .unknown)
        XCTAssertEqual(state.authState, .signedOut)
        XCTAssertEqual(state.loadState, .idle)
        XCTAssertNil(state.lastError)
    }

    func testResetClearsAllFields() {
        let state = AppState()
        state.emails = [makeEmail("m1")]
        state.unreadCount = 5
        state.connectionState = .online
        state.authState = .signedIn(email: "user@example.com")
        state.loadState = .loaded
        state.lastError = .auth(.refreshTokenInvalid)

        state.reset()

        XCTAssertEqual(state.emails, [])
        XCTAssertEqual(state.unreadCount, 0)
        XCTAssertEqual(state.connectionState, .unknown)
        XCTAssertEqual(state.authState, .signedOut)
        XCTAssertEqual(state.loadState, .idle)
        XCTAssertNil(state.lastError)
    }

    func testTopPriorityErrorReturnsLastError() {
        let state = AppState()
        XCTAssertNil(state.topPriorityError)
        state.lastError = .network(.offline)
        XCTAssertEqual(state.topPriorityError, .network(.offline))
    }

    private func makeEmail(_ id: String) -> EmailMessage {
        EmailMessage(
            id: id,
            threadId: "t-\(id)",
            from: "alice@example.com",
            subject: "Hello",
            internalDate: Date(timeIntervalSince1970: 1_700_000_000),
            snippet: nil
        )
    }
}
