import Foundation

protocol AuthorizationPerforming: Sendable {
    func performInitialAuthorization() async throws -> AuthSession
    func performTokenRefresh(refreshToken: String) async throws -> AuthSession
    func performRevoke(refreshToken: String) async throws
}
