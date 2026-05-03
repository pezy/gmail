import Foundation
import UserNotifications

protocol NotificationDispatching: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

@MainActor
final class NotificationManager: PollingNotifying {
    private let appState: AppState
    private let dispatcher: NotificationDispatching

    init(
        appState: AppState,
        dispatcher: NotificationDispatching = SystemNotificationDispatcher()
    ) {
        self.appState = appState
        self.dispatcher = dispatcher
    }

    func requestAuthorization() async {
        do {
            _ = try await dispatcher.requestAuthorization(options: [.alert, .sound])
        } catch {
            // Silent failure; user can re-grant via System Settings.
        }
    }

    nonisolated func notifyNewMessages(_ messages: [EmailMessage]) async {
        let email = await MainActor.run { signedInEmail() }
        guard let email else { return }
        for message in messages {
            let content = UNMutableNotificationContent()
            content.title = message.from.isEmpty ? "New mail" : message.from
            content.body = message.subject.isEmpty ? "(no subject)" : message.subject
            content.userInfo = [
                "messageId": message.id,
                "url": Self.gmailURL(email: email, threadId: message.threadId).absoluteString
            ]
            let request = UNNotificationRequest(
                identifier: message.id,
                content: content,
                trigger: nil
            )
            try? await dispatcher.add(request)
        }
    }

    /// Builds a Gmail web URL that targets a specific thread in the right account.
    ///
    /// The path-based form `/mail/u/{email}/` was historically supported but
    /// regularly fails today with "account temporarily unavailable". The
    /// reliable disambiguator is the `?authuser={email}` query parameter,
    /// which Google's own products (Calendar → email) use.
    ///
    /// We pass `threadId` because the `#inbox/{id}` fragment opens the
    /// conversation view, which is keyed on thread, not individual message.
    nonisolated static func gmailURL(email: String, threadId: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "mail.google.com"
        components.path = "/mail/"
        if !email.isEmpty {
            components.queryItems = [URLQueryItem(name: "authuser", value: email)]
        }
        components.fragment = "inbox/\(threadId)"
        return components.url!
    }

    private func signedInEmail() -> String? {
        if case .signedIn(let email) = appState.authState { return email }
        return nil
    }
}

struct SystemNotificationDispatcher: NotificationDispatching {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
}
