import Foundation

enum PollingState: Equatable, Sendable {
    case idle
    case polling
    case paused(PollingPauseReason)
    case backoff(until: Date)
}

enum PollingPauseReason: Equatable, Sendable {
    case popoverOpen
    case network
    case userPaused
}

protocol PollingNotifying: Sendable {
    func notifyNewMessages(_ messages: [EmailMessage]) async
}

@MainActor
final class PollingCoordinator {
    private(set) var state: PollingState = .idle
    var interval: TimeInterval = 60

    private let appState: AppState
    private let auth: AuthService
    private let api: GmailAPIClienting
    private let scheduler: PollScheduling
    private let notifier: PollingNotifying?
    private let now: @Sendable () -> Date
    private let userDefaults: UserDefaults

    init(
        appState: AppState,
        auth: AuthService,
        api: GmailAPIClienting,
        scheduler: PollScheduling,
        notifier: PollingNotifying? = nil,
        userDefaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.appState = appState
        self.auth = auth
        self.api = api
        self.scheduler = scheduler
        self.notifier = notifier
        self.userDefaults = userDefaults
        self.now = now
    }

    var lastHistoryId: String? {
        get { userDefaults.string(forKey: "lastHistoryId") }
        set { userDefaults.set(newValue, forKey: "lastHistoryId") }
    }

    var lastFetchTime: Date {
        get {
            if let interval = userDefaults.object(forKey: "lastFetchTime") as? TimeInterval {
                return Date(timeIntervalSince1970: interval)
            }
            return .distantPast
        }
        set { userDefaults.set(newValue.timeIntervalSince1970, forKey: "lastFetchTime") }
    }

    func start() async {
        guard auth.session != nil else {
            state = .idle
            return
        }
        await beginPolling()
    }

    func stop() async {
        state = .idle
        await scheduler.invalidate()
    }

    func popoverOpened() async {
        guard case .polling = state else { return }
        state = .paused(.popoverOpen)
        await scheduler.invalidate()
    }

    func popoverClosed() async {
        guard case .paused(.popoverOpen) = state else { return }
        await tickAndReschedule()
    }

    func networkChanged(to connection: ConnectionState) async {
        appState.connectionState = connection
        switch (state, connection) {
        case (_, .offline):
            if state != .idle {
                state = .paused(.network)
                await scheduler.invalidate()
            }
        case (.paused(.network), .online):
            await tickAndReschedule()
        default:
            break
        }
    }

    func performTick() async {
        guard auth.session != nil else { return }
        appState.loadState = .loading
        do {
            try await fetch()
            appState.loadState = .loaded
            appState.lastError = nil
            lastFetchTime = now()
        } catch let error as AppError {
            handle(error)
        } catch {
            appState.loadState = .failed(.api(.malformedResponse))
            appState.lastError = .api(.malformedResponse)
        }
    }

    private func beginPolling() async {
        state = .polling
        await scheduler.schedule(interval: interval) { [weak self] in
            await self?.performTick()
        }
    }

    private func tickAndReschedule() async {
        state = .polling
        await performTick()
        if case .polling = state {
            await scheduler.schedule(interval: interval) { [weak self] in
                await self?.performTick()
            }
        }
    }

    private func fetch() async throws {
        let token = try await auth.freshAccessToken()
        if let historyId = lastHistoryId {
            try await fetchIncremental(token: token, since: historyId)
        } else {
            try await fetchInitial(token: token)
        }
    }

    private func fetchInitial(token: String) async throws {
        let profile = try await api.getProfile(accessToken: token)
        if auth.session?.email == nil {
            try? auth.attachEmail(profile.emailAddress)
            appState.authState = .signedIn(email: profile.emailAddress)
        }

        let list = try await api.listUnreadMessages(accessToken: token, maxResults: 20)
        var messages: [EmailMessage] = []
        for id in list.messageIds {
            do {
                let message = try await api.getMessageMetadata(accessToken: token, id: id)
                messages.append(message)
            } catch AppError.api(.notFound) {
                // Message disappeared between list and get; skip.
                continue
            }
        }
        appState.emails = messages.sorted { $0.internalDate > $1.internalDate }
        appState.unreadCount = list.resultSizeEstimate
        lastHistoryId = profile.historyId
    }

    private func fetchIncremental(token: String, since historyId: String) async throws {
        // Defense-in-depth: if we somehow got here without an email on the session
        // (e.g., a stale historyId from a previous binary version), fall back to the
        // initial path so attachEmail runs and authState transitions to .signedIn.
        if auth.session?.email == nil {
            lastHistoryId = nil
            try await fetchInitial(token: token)
            return
        }

        let response: HistoryResponse
        do {
            response = try await api.listHistory(accessToken: token, startHistoryId: historyId)
        } catch AppError.api(.historyExpired) {
            // Normal flow: full reload then suppress notifications for old mail.
            lastHistoryId = nil
            try await fetchInitial(token: token)
            return
        }

        var addedIds: [String] = []
        var removedIds: Set<String> = []
        for change in response.changes {
            switch change {
            case .messageAdded(let id):
                addedIds.append(id)
            case .messageDeleted(let id):
                removedIds.insert(id)
            case .labelAdded(let id, let label):
                if label == "INBOX" { addedIds.append(id) }
            case .labelRemoved(let id, let label):
                if label == "INBOX" || label == "UNREAD" {
                    removedIds.insert(id)
                }
            }
        }

        if !addedIds.isEmpty {
            var newMessages: [EmailMessage] = []
            for id in Array(Set(addedIds)) {
                do {
                    let message = try await api.getMessageMetadata(accessToken: token, id: id)
                    newMessages.append(message)
                } catch AppError.api(.notFound) {
                    continue
                }
            }
            await notifier?.notifyNewMessages(newMessages)
            appState.emails = (newMessages + appState.emails)
                .reduce(into: [EmailMessage]()) { acc, message in
                    if !acc.contains(where: { $0.id == message.id }) { acc.append(message) }
                }
                .sorted { $0.internalDate > $1.internalDate }
        }
        if !removedIds.isEmpty {
            appState.emails.removeAll { removedIds.contains($0.id) }
        }
        appState.unreadCount = appState.emails.count
        lastHistoryId = response.historyId
    }

    private func handle(_ error: AppError) {
        switch error {
        case .api(.unauthorized):
            // 401 shouldn't reach here normally — AuthService refreshes proactively.
            // If it does, mark as needing reauthorization.
            appState.authState = .needsReauthorization
            appState.lastError = error
        case .auth(.refreshTokenInvalid):
            appState.authState = .needsReauthorization
            appState.lastError = error
        case .api(.rateLimited(let retryAfter)):
            let backoffUntil = now().addingTimeInterval(retryAfter ?? 60)
            state = .backoff(until: backoffUntil)
            appState.lastError = error
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64((retryAfter ?? 60) * 1_000_000_000))
                await self?.recoverFromBackoff()
            }
        case .network:
            state = .paused(.network)
            appState.lastError = error
        default:
            appState.lastError = error
        }
        appState.loadState = .failed(error)
    }

    private func recoverFromBackoff() async {
        guard case .backoff = state else { return }
        await beginPolling()
    }
}
