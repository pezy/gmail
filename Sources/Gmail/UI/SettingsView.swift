import SwiftUI

enum PollingInterval: TimeInterval, CaseIterable, Identifiable {
    case sixty = 60
    case oneTwenty = 120
    case fiveMinutes = 300
    case tenMinutes = 600

    var id: TimeInterval { rawValue }

    var label: String {
        switch self {
        case .sixty: return "60 seconds"
        case .oneTwenty: return "2 minutes"
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        }
    }
}

@MainActor
@Observable
final class SettingsModel {
    var pollingInterval: PollingInterval {
        didSet { defaults.set(pollingInterval.rawValue, forKey: Keys.pollingInterval) }
    }
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }
    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedInterval = defaults.object(forKey: Keys.pollingInterval) as? TimeInterval
        self.pollingInterval = storedInterval.flatMap(PollingInterval.init(rawValue:)) ?? .sixty
        self.notificationsEnabled = (defaults.object(forKey: Keys.notificationsEnabled) as? Bool) ?? true
        self.launchAtLogin = (defaults.object(forKey: Keys.launchAtLogin) as? Bool) ?? false
    }

    enum Keys {
        static let pollingInterval = "settings.pollingInterval"
        static let notificationsEnabled = "settings.notificationsEnabled"
        static let launchAtLogin = "settings.launchAtLogin"
    }
}

struct SettingsView: View {
    @Bindable var settings: SettingsModel
    @Bindable var appState: AppState
    let onSignOut: () -> Void
    let onSignIn: () -> Void
    let onLaunchAtLoginChanged: (Bool) -> Void
    let onPollingIntervalChanged: (TimeInterval) -> Void

    var body: some View {
        Form {
            Section("Polling") {
                Picker("Check for mail every", selection: Binding(
                    get: { settings.pollingInterval },
                    set: { newValue in
                        settings.pollingInterval = newValue
                        onPollingIntervalChanged(newValue.rawValue)
                    }
                )) {
                    ForEach(PollingInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
            }
            Section("Notifications") {
                Toggle("Show macOS notifications for new mail", isOn: $settings.notificationsEnabled)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { newValue in
                        settings.launchAtLogin = newValue
                        onLaunchAtLoginChanged(newValue)
                    }
                ))
            }
            Section("Account") {
                if case .signedIn(let email) = appState.authState {
                    LabeledContent("Signed in as", value: email)
                    Button("Sign out", role: .destructive, action: onSignOut)
                } else {
                    Button("Connect Gmail", action: onSignIn)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 360)
    }
}
