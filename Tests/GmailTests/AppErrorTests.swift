import XCTest
@testable import Gmail

final class AppErrorTests: XCTestCase {
    func testPriorityOrdering() {
        XCTAssertLessThan(ErrorPriority.notification, ErrorPriority.api)
        XCTAssertLessThan(ErrorPriority.api, ErrorPriority.network)
        XCTAssertLessThan(ErrorPriority.network, ErrorPriority.auth)
    }

    func testAuthErrorHasHighestPriority() {
        let auth = AppError.auth(.refreshTokenInvalid)
        let network = AppError.network(.offline)
        let api = AppError.api(.rateLimited(retryAfter: nil))
        let notif = AppError.notification(.permissionDenied)

        let max = [auth, network, api, notif].max(by: { $0.priority < $1.priority })
        XCTAssertEqual(max?.priority, .auth)
    }

    func testNotificationHasLowestPriority() {
        let candidates: [AppError] = [
            .auth(.refreshTokenInvalid),
            .network(.offline),
            .api(.notFound),
            .notification(.permissionDenied)
        ]
        let min = candidates.min(by: { $0.priority < $1.priority })
        XCTAssertEqual(min?.priority, .notification)
    }

    func testErrorEquatable() {
        XCTAssertEqual(AppError.auth(.refreshTokenInvalid), AppError.auth(.refreshTokenInvalid))
        XCTAssertNotEqual(AppError.auth(.refreshTokenInvalid), AppError.auth(.notSignedIn))
        XCTAssertNotEqual(AppError.auth(.notSignedIn), AppError.network(.offline))
    }

    func testAPIErrorRateLimitedCarriesRetryAfter() {
        let withRetry = APIError.rateLimited(retryAfter: 60)
        let withoutRetry = APIError.rateLimited(retryAfter: nil)
        XCTAssertNotEqual(withRetry, withoutRetry)
    }
}
