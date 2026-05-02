import Foundation

enum AppError: Error, Equatable {
    case auth(AuthError)
    case network(NetworkError)
    case api(APIError)
    case notification(NotificationError)

    var priority: ErrorPriority {
        switch self {
        case .auth: return .auth
        case .network: return .network
        case .api: return .api
        case .notification: return .notification
        }
    }
}

enum ErrorPriority: Int, Comparable {
    case notification = 0
    case api = 1
    case network = 2
    case auth = 3

    static func < (lhs: ErrorPriority, rhs: ErrorPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum AuthError: Error, Equatable {
    case notSignedIn
    case refreshTokenInvalid
    case authorizationFailed(reason: String)
    case revocationFailed
}

enum NetworkError: Error, Equatable {
    case offline
    case timeout
    case unknown(reason: String)
}

enum APIError: Error, Equatable {
    case rateLimited(retryAfter: TimeInterval?)
    case unauthorized
    case notFound
    case serverError(status: Int)
    case malformedResponse
    case historyExpired
}

enum NotificationError: Error, Equatable {
    case permissionDenied
    case deliveryFailed(reason: String)
}
