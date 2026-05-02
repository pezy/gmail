import XCTest
@testable import Gmail

final class KeychainServiceTests: XCTestCase {
    private var keychain: KeychainService!
    private var service: String!

    override func setUp() {
        super.setUp()
        service = "com.pezy.gmail.tests.\(UUID().uuidString)"
        keychain = KeychainService(service: service)
    }

    override func tearDown() {
        try? keychain.delete(account: "alice@example.com")
        try? keychain.delete(account: "bob@example.com")
        try? keychain.delete(account: KeychainService.pendingAccount)
        super.tearDown()
    }

    func testLoadReturnsNilForMissingItem() throws {
        let data = try keychain.load(account: "alice@example.com")
        XCTAssertNil(data)
    }

    func testSaveAndLoadRoundTrip() throws {
        let token = "secret-token".data(using: .utf8)!
        try keychain.save(token, account: "alice@example.com")
        let loaded = try keychain.load(account: "alice@example.com")
        XCTAssertEqual(loaded, token)
    }

    func testSaveOverwritesExistingItem() throws {
        let first = "v1".data(using: .utf8)!
        let second = "v2".data(using: .utf8)!
        try keychain.save(first, account: "alice@example.com")
        try keychain.save(second, account: "alice@example.com")
        XCTAssertEqual(try keychain.load(account: "alice@example.com"), second)
    }

    func testDeleteRemovesItem() throws {
        try keychain.save("data".data(using: .utf8)!, account: "alice@example.com")
        try keychain.delete(account: "alice@example.com")
        XCTAssertNil(try keychain.load(account: "alice@example.com"))
    }

    func testDeleteMissingItemDoesNotThrow() {
        XCTAssertNoThrow(try keychain.delete(account: "ghost@example.com"))
    }

    func testIsolationByAccount() throws {
        try keychain.save("alice-data".data(using: .utf8)!, account: "alice@example.com")
        try keychain.save("bob-data".data(using: .utf8)!, account: "bob@example.com")
        XCTAssertEqual(try keychain.load(account: "alice@example.com"),
                       "alice-data".data(using: .utf8)!)
        XCTAssertEqual(try keychain.load(account: "bob@example.com"),
                       "bob-data".data(using: .utf8)!)
    }

    func testMigrateAccountMovesData() throws {
        let token = "pending-token".data(using: .utf8)!
        try keychain.save(token, account: KeychainService.pendingAccount)

        try keychain.migrateAccount(from: KeychainService.pendingAccount,
                                    to: "alice@example.com")

        XCTAssertEqual(try keychain.load(account: "alice@example.com"), token)
        XCTAssertNil(try keychain.load(account: KeychainService.pendingAccount))
    }

    func testMigrateAccountThrowsWhenSourceMissing() {
        XCTAssertThrowsError(try keychain.migrateAccount(
            from: KeychainService.pendingAccount,
            to: "alice@example.com"
        )) { error in
            XCTAssertEqual(error as? KeychainError, .itemNotFound)
        }
    }
}
