import Foundation

@MainActor
final class AuthService {
    private let keychain: KeychainService
    private let authorizer: AuthorizationPerforming
    private let now: @Sendable () -> Date
    private(set) var session: AuthSession?

    init(
        keychain: KeychainService,
        authorizer: AuthorizationPerforming,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.keychain = keychain
        self.authorizer = authorizer
        self.now = now
    }

    @discardableResult
    func restore() throws -> AuthSession? {
        if let session = try loadSession(account: KeychainService.pendingAccount) {
            self.session = session
            return session
        }
        return nil
    }

    @discardableResult
    func restore(email: String) throws -> AuthSession? {
        if let session = try loadSession(account: email) {
            self.session = session
            return session
        }
        return nil
    }

    func signIn() async throws -> AuthSession {
        let session = try await authorizer.performInitialAuthorization()
        try persist(session, account: KeychainService.pendingAccount)
        self.session = session
        return session
    }

    func attachEmail(_ email: String) throws {
        guard let current = session else {
            throw AppError.auth(.notSignedIn)
        }
        let updated = current.withEmail(email)
        try keychain.migrateAccount(
            from: KeychainService.pendingAccount,
            to: email
        )
        try persist(updated, account: email)
        self.session = updated
    }

    func freshAccessToken() async throws -> String {
        guard let current = session else {
            throw AppError.auth(.notSignedIn)
        }
        if current.isAccessTokenFresh(now: now()) {
            return current.accessToken
        }
        return try await refreshAccessToken(current: current)
    }

    func signOut() async throws {
        guard let current = session else { return }
        do {
            try await authorizer.performRevoke(refreshToken: current.refreshToken)
        } catch {
            // Best-effort; clear local state regardless.
        }
        try keychain.delete(account: accountKey(for: current))
        self.session = nil
    }

    private func refreshAccessToken(current: AuthSession) async throws -> String {
        do {
            let refreshed = try await authorizer.performTokenRefresh(
                refreshToken: current.refreshToken
            )
            let merged = AuthSession(
                accessToken: refreshed.accessToken,
                refreshToken: refreshed.refreshToken.isEmpty
                    ? current.refreshToken
                    : refreshed.refreshToken,
                idToken: refreshed.idToken ?? current.idToken,
                expiresAt: refreshed.expiresAt,
                email: current.email
            )
            try persist(merged, account: accountKey(for: merged))
            self.session = merged
            return merged.accessToken
        } catch {
            self.session = nil
            try? keychain.delete(account: accountKey(for: current))
            throw AppError.auth(.refreshTokenInvalid)
        }
    }

    private func persist(_ session: AuthSession, account: String) throws {
        let data = try JSONEncoder().encode(session)
        try keychain.save(data, account: account)
    }

    private func loadSession(account: String) throws -> AuthSession? {
        guard let data = try keychain.load(account: account) else { return nil }
        return try JSONDecoder().decode(AuthSession.self, from: data)
    }

    private func accountKey(for session: AuthSession) -> String {
        session.email ?? KeychainService.pendingAccount
    }
}
