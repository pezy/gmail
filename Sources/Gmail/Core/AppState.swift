import Foundation
import Observation

enum ConnectionState: Equatable {
    case unknown
    case online
    case offline
}

enum AuthState: Equatable {
    case signedOut
    case signedIn(email: String)
    case needsReauthorization
}

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(AppError)
}

@MainActor
@Observable
final class AppState {
    var emails: [EmailMessage] = []
    var unreadCount: Int = 0
    var connectionState: ConnectionState = .unknown
    var authState: AuthState = .signedOut
    var loadState: LoadState = .idle
    var lastError: AppError?

    var topPriorityError: AppError? {
        guard let lastError else { return nil }
        return lastError
    }

    func reset() {
        emails = []
        unreadCount = 0
        connectionState = .unknown
        authState = .signedOut
        loadState = .idle
        lastError = nil
    }
}
