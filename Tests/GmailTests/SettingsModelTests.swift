import XCTest
@testable import Gmail

@MainActor
final class SettingsModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "settings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    func testDefaultValuesWhenEmpty() {
        let model = SettingsModel(defaults: defaults)
        XCTAssertEqual(model.pollingInterval, .sixty)
        XCTAssertEqual(model.notificationsEnabled, true)
        XCTAssertEqual(model.launchAtLogin, false)
    }

    func testPollingIntervalPersists() {
        let first = SettingsModel(defaults: defaults)
        first.pollingInterval = .fiveMinutes

        let reloaded = SettingsModel(defaults: defaults)

        XCTAssertEqual(reloaded.pollingInterval, .fiveMinutes)
    }

    func testNotificationsToggleRoundTrips() {
        let first = SettingsModel(defaults: defaults)
        first.notificationsEnabled = false

        let reloaded = SettingsModel(defaults: defaults)
        XCTAssertEqual(reloaded.notificationsEnabled, false)
    }

    func testLaunchAtLoginRoundTrips() {
        let first = SettingsModel(defaults: defaults)
        first.launchAtLogin = true

        let reloaded = SettingsModel(defaults: defaults)
        XCTAssertEqual(reloaded.launchAtLogin, true)
    }

    func testPollingIntervalLabels() {
        XCTAssertEqual(PollingInterval.sixty.label, "60 seconds")
        XCTAssertEqual(PollingInterval.oneTwenty.label, "2 minutes")
        XCTAssertEqual(PollingInterval.fiveMinutes.label, "5 minutes")
        XCTAssertEqual(PollingInterval.tenMinutes.label, "10 minutes")
    }
}
