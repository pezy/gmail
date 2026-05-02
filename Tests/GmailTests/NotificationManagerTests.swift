import XCTest
import UserNotifications
@testable import Gmail

@MainActor
final class NotificationManagerTests: XCTestCase {
    private var appState: AppState!
    private var dispatcher: RecordingDispatcher!
    private var manager: NotificationManager!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
        dispatcher = RecordingDispatcher()
        manager = NotificationManager(appState: appState, dispatcher: dispatcher)
    }

    func testGmailURLUsesEmailNotAccountIndex() {
        let url = NotificationManager.gmailURL(email: "alice@example.com", messageId: "abc123")
        XCTAssertEqual(
            url.absoluteString,
            "https://mail.google.com/mail/u/alice@example.com/#inbox/abc123"
        )
    }

    func testNotifySkipsWhenNotSignedIn() async {
        appState.authState = .signedOut

        await manager.notifyNewMessages([makeMessage(id: "m1", from: "A", subject: "S")])

        XCTAssertEqual(dispatcher.added.count, 0)
    }

    func testNotifyDispatchesOnePerMessage() async {
        appState.authState = .signedIn(email: "alice@example.com")

        await manager.notifyNewMessages([
            makeMessage(id: "m1", from: "Alice", subject: "Hi"),
            makeMessage(id: "m2", from: "Bob", subject: "Hey")
        ])

        XCTAssertEqual(dispatcher.added.map(\.identifier), ["m1", "m2"])
    }

    func testNotificationContentHasFromAndSubject() async {
        appState.authState = .signedIn(email: "alice@example.com")

        await manager.notifyNewMessages([
            makeMessage(id: "m1", from: "Alice", subject: "Hello world")
        ])

        let request = dispatcher.added.first!
        XCTAssertEqual(request.content.title, "Alice")
        XCTAssertEqual(request.content.body, "Hello world")
        XCTAssertEqual(request.content.userInfo["messageId"] as? String, "m1")
        XCTAssertEqual(
            request.content.userInfo["url"] as? String,
            "https://mail.google.com/mail/u/alice@example.com/#inbox/m1"
        )
    }

    func testNotificationFallsBackForEmptyHeaders() async {
        appState.authState = .signedIn(email: "alice@example.com")

        await manager.notifyNewMessages([
            makeMessage(id: "m1", from: "", subject: "")
        ])

        let request = dispatcher.added.first!
        XCTAssertEqual(request.content.title, "New mail")
        XCTAssertEqual(request.content.body, "(no subject)")
    }

    private func makeMessage(id: String, from: String, subject: String) -> EmailMessage {
        EmailMessage(
            id: id,
            threadId: "t-\(id)",
            from: from,
            subject: subject,
            internalDate: Date(timeIntervalSince1970: 1_700_000_000),
            snippet: nil
        )
    }
}

private final class RecordingDispatcher: NotificationDispatching, @unchecked Sendable {
    var added: [UNNotificationRequest] = []
    var authorizationGranted = true
    var authorizationError: Error?

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let authorizationError { throw authorizationError }
        return authorizationGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        added.append(request)
    }
}
