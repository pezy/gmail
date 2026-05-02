import Foundation

enum StatusBarTone: Equatable, Sendable {
    case normal
    case auth
    case network
    case api
}

struct StatusBarPresentation: Equatable, Sendable {
    let title: String
    let tone: StatusBarTone
    let symbolName: String
}

enum StatusBarPresenter {
    static func present(unreadCount: Int, authState: AuthState, connection: ConnectionState, lastError: AppError?) -> StatusBarPresentation {
        let tone = resolveTone(authState: authState, connection: connection, lastError: lastError)
        let title = unreadCount > 0 ? String(unreadCount) : ""
        let symbolName = tone == .auth ? "envelope.badge.shield.half.filled" : "envelope"
        return StatusBarPresentation(title: title, tone: tone, symbolName: symbolName)
    }

    private static func resolveTone(authState: AuthState, connection: ConnectionState, lastError: AppError?) -> StatusBarTone {
        if case .needsReauthorization = authState { return .auth }
        if case .auth = lastError { return .auth }
        if connection == .offline { return .network }
        if case .network = lastError { return .network }
        if case .api = lastError { return .api }
        return .normal
    }
}
