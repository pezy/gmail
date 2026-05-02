import Foundation
import AppKit
@preconcurrency import AppAuth

/// Real AppAuth-iOS-backed implementation of AuthorizationPerforming.
///
/// All ASWebAuthenticationSession + AppAuth interactions are routed onto the
/// main actor because OIDExternalUserAgentMac touches AppKit. Network-only
/// work (discovery, refresh, revoke) does not require the main actor but is
/// kept here for cohesion.
final class AppAuthAuthorizer: AuthorizationPerforming, @unchecked Sendable {
    static let googleIssuer = URL(string: "https://accounts.google.com")!
    static let revokeEndpoint = URL(string: "https://oauth2.googleapis.com/revoke")!
    static let defaultScopes = ["https://www.googleapis.com/auth/gmail.readonly"]

    private let clientID: String
    private let redirectURL: URL
    private let scopes: [String]
    private let urlSession: URLSession

    private let configurationCache = ConfigurationCache()

    init(
        clientID: String,
        redirectURL: URL,
        scopes: [String] = AppAuthAuthorizer.defaultScopes,
        urlSession: URLSession = .shared
    ) {
        self.clientID = clientID
        self.redirectURL = redirectURL
        self.scopes = scopes
        self.urlSession = urlSession
    }

    func performInitialAuthorization() async throws -> AuthSession {
        let configuration = try await discoverConfiguration()
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: clientID,
            clientSecret: nil,
            scopes: scopes,
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: [
                "access_type": "offline",
                "prompt": "consent"
            ]
        )
        return try await presentAuthorization(request: request)
    }

    func performTokenRefresh(refreshToken: String) async throws -> AuthSession {
        let configuration = try await discoverConfiguration()
        let request = OIDTokenRequest(
            configuration: configuration,
            grantType: OIDGrantTypeRefreshToken,
            authorizationCode: nil,
            redirectURL: redirectURL,
            clientID: clientID,
            clientSecret: nil,
            scope: nil,
            refreshToken: refreshToken,
            codeVerifier: nil,
            additionalParameters: nil
        )
        return try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService.perform(request) { response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response, let accessToken = response.accessToken else {
                    continuation.resume(throwing: AppError.auth(.refreshTokenInvalid))
                    return
                }
                let session = AuthSession(
                    accessToken: accessToken,
                    refreshToken: response.refreshToken ?? "",
                    idToken: response.idToken,
                    expiresAt: response.accessTokenExpirationDate ?? Date().addingTimeInterval(3600),
                    email: nil
                )
                continuation.resume(returning: session)
            }
        }
    }

    func performRevoke(refreshToken: String) async throws {
        var request = URLRequest(url: Self.revokeEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.auth(.revocationFailed)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.auth(.revocationFailed)
        }
    }

    @MainActor
    private func presentAuthorization(request: OIDAuthorizationRequest) async throws -> AuthSession {
        try await withCheckedThrowingContinuation { continuation in
            let presentingWindow = NSApp.windows.first ?? NSWindow()
            let userAgent = OIDExternalUserAgentMac(presenting: presentingWindow)
            _ = OIDAuthState.authState(
                byPresenting: request,
                externalUserAgent: userAgent
            ) { authState, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let authState else {
                    continuation.resume(
                        throwing: AppError.auth(.authorizationFailed(reason: "no auth state"))
                    )
                    return
                }
                do {
                    let session = try Self.session(from: authState)
                    continuation.resume(returning: session)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func discoverConfiguration() async throws -> OIDServiceConfiguration {
        if let cached = await configurationCache.get() {
            return cached.value
        }
        let configuration: OIDServiceConfiguration = try await withCheckedThrowingContinuation { continuation in
            OIDAuthorizationService.discoverConfiguration(
                forIssuer: Self.googleIssuer
            ) { configuration, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let configuration else {
                    continuation.resume(
                        throwing: AppError.auth(.authorizationFailed(reason: "discovery failed"))
                    )
                    return
                }
                continuation.resume(returning: configuration)
            }
        }
        await configurationCache.set(configuration)
        return configuration
    }

    private struct UncheckedConfig: @unchecked Sendable {
        let value: OIDServiceConfiguration
    }

    private actor ConfigurationCache {
        private var stored: UncheckedConfig?
        func get() -> UncheckedConfig? { stored }
        func set(_ value: OIDServiceConfiguration) { stored = UncheckedConfig(value: value) }
    }

    private static func session(from authState: OIDAuthState) throws -> AuthSession {
        guard let accessToken = authState.lastTokenResponse?.accessToken,
              let refreshToken = authState.lastTokenResponse?.refreshToken,
              let expiresAt = authState.lastTokenResponse?.accessTokenExpirationDate else {
            throw AppError.auth(.authorizationFailed(reason: "missing tokens"))
        }
        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: authState.lastTokenResponse?.idToken,
            expiresAt: expiresAt,
            email: nil
        )
    }
}
