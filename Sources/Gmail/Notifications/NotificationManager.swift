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
                "url": Self.gmailURL(email: email, messageId: message.id).absoluteString
            ]
            let request = UNNotificationRequest(
                identifier: message.id,
                content: content,
                trigger: nil
            )
            try? await dispatcher.add(request)
        }
    }

    nonisolated static func gmailURL(email: String, messageId: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "mail.google.com"
        components.path = "/mail/u/\(email)/"
        components.fragment = "inbox/\(messageId)"
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
