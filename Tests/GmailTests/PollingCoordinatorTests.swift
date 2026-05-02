import XCTest
@testable import Gmail

@MainActor
final class PollingCoordinatorTests: XCTestCase {
    private var appState: AppState!
    private var keychain: KeychainService!
    private var authorizer: MockAuthorizer!
    private var auth: AuthService!
    private var api: MockAPI!
    private var scheduler: MockScheduler!
    private var notifier: RecordingNotifier!
    private var defaults: UserDefaults!
    private var coordinator: PollingCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
        keychain = KeychainService(service: "com.pezy.gmail.tests.\(UUID().uuidString)")
        authorizer = MockAuthorizer()
        auth = AuthService(keychain: keychain, authorizer: authorizer)
        api = MockAPI()
        scheduler = MockScheduler()
        notifier = RecordingNotifier()
        let suiteName = "polling.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        coordinator = PollingCoordinator(
            appState: appState,
            auth: auth,
            api: api,
            scheduler: scheduler,
            notifier: notifier,
            userDefaults: defaults,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().description)
        try? keychain.delete(account: KeychainService.pendingAccount)
        try? keychain.delete(account: "alice@example.com")
        try await super.tearDown()
    }

    func testStartWithoutSessionStaysIdle() async {
        await coordinator.start()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(scheduler.scheduleCount, 0)
    }

    func testStartWithSessionTransitionsToPolling() async throws {
        try await signInTestSession()
        await coordinator.start()
        XCTAssertEqual(coordinator.state, .polling)
        XCTAssertEqual(scheduler.scheduleCount, 1)
    }

    func testPopoverOpenedPausesPolling() async throws {
        try await signInTestSession()
        await coordinator.start()
        await coordinator.popoverOpened()
        XCTAssertEqual(coordinator.state, .paused(.popoverOpen))
        XCTAssertEqual(scheduler.invalidateCount, 1)
    }

    func testPopoverClosedFetchesAndResumes() async throws {
        try await signInTestSession()
        api.profileResult = .success(makeProfile(historyId: "100"))
        api.listResult = .success(MessageListResponse(messageIds: [], resultSizeEstimate: 0))
        await coordinator.start()
        await coordinator.popoverOpened()

        await coordinator.popoverClosed()

        XCTAssertEqual(coordinator.state, .polling)
        XCTAssertEqual(api.profileCallCount, 1, "popoverClosed should immediately fetch once")
    }

    func testNetworkOfflineDuringPollingPauses() async throws {
        try await signInTestSession()
        await coordinator.start()
        await coordinator.networkChanged(to: .offline)
        XCTAssertEqual(coordinator.state, .paused(.network))
        XCTAssertEqual(appState.connectionState, .offline)
    }

    func testNetworkRestoreFromPausedFetches() async throws {
        try await signInTestSession()
        api.profileResult = .success(makeProfile(historyId: "100"))
        api.listResult = .success(MessageListResponse(messageIds: [], resultSizeEstimate: 0))
        await coordinator.start()
        await coordinator.networkChanged(to: .offline)

        await coordinator.networkChanged(to: .online)

        XCTAssertEqual(coordinator.state, .polling)
        XCTAssertEqual(api.profileCallCount, 1)
    }

    func testFetchInitialAttachesEmailAndPopulatesEmails() async throws {
        try await signInTestSession()
        api.profileResult = .success(makeProfile(emailAddress: "alice@example.com", historyId: "100"))
        api.listResult = .success(MessageListResponse(messageIds: ["m1"], resultSizeEstimate: 1))
        api.getResults["m1"] = .success(makeEmail(id: "m1", subject: "Hi"))

        await coordinator.performTick()

        XCTAssertEqual(appState.authState, .signedIn(email: "alice@example.com"))
        XCTAssertEqual(appState.emails.count, 1)
        XCTAssertEqual(appState.emails.first?.subject, "Hi")
        XCTAssertEqual(appState.unreadCount, 1)
        XCTAssertEqual(coordinator.lastHistoryId, "100")
    }

    func testFetchIncrementalRemovesMessagesOnLabelsRemoved() async throws {
        try await signInTestSession()
        coordinator.lastHistoryId = "100"
        try auth.attachEmail("alice@example.com")
        appState.emails = [
            makeEmail(id: "m1", subject: "old1"),
            makeEmail(id: "m2", subject: "old2")
        ]
        appState.unreadCount = 2

        api.historyResult = .success(HistoryResponse(
            historyId: "200",
            changes: [.labelRemoved(messageId: "m1", label: "UNREAD")]
        ))

        await coordinator.performTick()

        XCTAssertEqual(appState.emails.map(\.id), ["m2"])
        XCTAssertEqual(appState.unreadCount, 1)
        XCTAssertEqual(coordinator.lastHistoryId, "200")
    }

    func testFetchIncrementalAddsNewMessageAndNotifies() async throws {
        try await signInTestSession()
        coordinator.lastHistoryId = "100"
        try auth.attachEmail("alice@example.com")

        api.historyResult = .success(HistoryResponse(
            historyId: "200",
            changes: [.messageAdded(id: "m1")]
        ))
        api.getResults["m1"] = .success(makeEmail(id: "m1", subject: "Fresh"))

        await coordinator.performTick()

        XCTAssertEqual(notifier.notified.map(\.id), ["m1"])
        XCTAssertEqual(appState.emails.first?.subject, "Fresh")
    }

    func testHistoryExpiredFallsBackToFetchInitial() async throws {
        try await signInTestSession()
        coordinator.lastHistoryId = "100"
        try auth.attachEmail("alice@example.com")

        api.historyResult = .failure(AppError.api(.historyExpired))
        api.profileResult = .success(makeProfile(emailAddress: "alice@example.com", historyId: "300"))
        api.listResult = .success(MessageListResponse(messageIds: [], resultSizeEstimate: 0))

        await coordinator.performTick()

        XCTAssertEqual(coordinator.lastHistoryId, "300")
        XCTAssertEqual(api.profileCallCount, 1)
    }

    func testRefreshTokenInvalidMarksReauthorization() async throws {
        try await signInTestSession()
        api.profileResult = .failure(AppError.auth(.refreshTokenInvalid))

        await coordinator.performTick()

        XCTAssertEqual(appState.authState, .needsReauthorization)
        XCTAssertEqual(appState.lastError, .auth(.refreshTokenInvalid))
    }

    func testStopInvalidatesScheduler() async throws {
        try await signInTestSession()
        await coordinator.start()
        await coordinator.stop()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertGreaterThanOrEqual(scheduler.invalidateCount, 1)
    }

    private func signInTestSession() async throws {
        authorizer.initialResult = .success(AuthSession(
            accessToken: "atoken",
            refreshToken: "rtoken",
            idToken: nil,
            expiresAt: Date().addingTimeInterval(3600),
            email: nil
        ))
        _ = try await auth.signIn()
    }

    private func makeProfile(emailAddress: String = "alice@example.com", historyId: String) -> GmailProfile {
        GmailProfile(emailAddress: emailAddress, historyId: historyId, messagesTotal: 0)
    }

    private func makeEmail(id: String, subject: String) -> EmailMessage {
        EmailMessage(
            id: id,
            threadId: "t-\(id)",
            from: "x@example.com",
            subject: subject,
            internalDate: Date(timeIntervalSince1970: 1_700_000_000),
            snippet: nil
        )
    }
}

private final class MockAPI: GmailAPIClienting, @unchecked Sendable {
    var profileResult: Result<GmailProfile, Error> = .failure(NSError(domain: "mock", code: 0))
    var listResult: Result<MessageListResponse, Error> = .failure(NSError(domain: "mock", code: 0))
    var historyResult: Result<HistoryResponse, Error> = .failure(NSError(domain: "mock", code: 0))
    var getResults: [String: Result<EmailMessage, Error>] = [:]
    var profileCallCount = 0
    var historyCallCount = 0

    func getProfile(accessToken: String) async throws -> GmailProfile {
        profileCallCount += 1
        return try profileResult.get()
    }

    func listUnreadMessages(accessToken: String, maxResults: Int) async throws -> MessageListResponse {
        try listResult.get()
    }

    func getMessageMetadata(accessToken: String, id: String) async throws -> EmailMessage {
        guard let result = getResults[id] else {
            throw AppError.api(.malformedResponse)
        }
        return try result.get()
    }

    func listHistory(accessToken: String, startHistoryId: String) async throws -> HistoryResponse {
        historyCallCount += 1
        return try historyResult.get()
    }
}

private final class MockScheduler: PollScheduling, @unchecked Sendable {
    var scheduleCount = 0
    var invalidateCount = 0
    var lastAction: (@Sendable () async -> Void)?

    func schedule(interval: TimeInterval, action: @escaping @Sendable () async -> Void) async {
        scheduleCount += 1
        lastAction = action
    }

    func invalidate() async {
        invalidateCount += 1
    }
}

private final class RecordingNotifier: PollingNotifying, @unchecked Sendable {
    var notified: [EmailMessage] = []

    func notifyNewMessages(_ messages: [EmailMessage]) async {
        notified.append(contentsOf: messages)
    }
}
