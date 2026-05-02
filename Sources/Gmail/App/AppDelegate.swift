import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let appState = AppState()

    private var auth: AuthService!
    private var api: GmailAPIClient!
    private var coordinator: PollingCoordinator!
    private var notificationManager: NotificationManager!
    private var statusBar: StatusBarController!
    private var networkMonitor: NetworkMonitor!
    private var networkTask: Task<Void, Never>?
    private var settingsModel: SettingsModel!
    private var settingsWindow: NSWindowController?
    private let loginItems = LoginItemsManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "OAuthClientID") as? String,
              let scheme = Bundle.main.object(forInfoDictionaryKey: "OAuthRedirectURLScheme") as? String,
              !clientID.contains("YOUR_CLIENT_ID"), !scheme.contains("YOUR_REVERSED") else {
            presentMissingClientIDAlert()
            return
        }

        let redirectURL = URL(string: "\(scheme):/oauth2redirect")!
        let keychain = KeychainService()
        let authorizer = AppAuthAuthorizer(clientID: clientID, redirectURL: redirectURL)
        auth = AuthService(keychain: keychain, authorizer: authorizer)
        api = GmailAPIClient()
        notificationManager = NotificationManager(appState: appState)
        settingsModel = SettingsModel()

        let scheduler = BackgroundActivityPollScheduler()
        coordinator = PollingCoordinator(
            appState: appState,
            auth: auth,
            api: api,
            scheduler: scheduler,
            notifier: notificationManager
        )
        coordinator.interval = settingsModel.pollingInterval.rawValue

        let popoverContent = PopoverView(
            appState: appState,
            onRefresh: { [weak self] in Task { await self?.coordinator.performTick() } },
            onSignIn: { [weak self] in Task { await self?.signIn() } },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        statusBar = StatusBarController(appState: appState, popoverContent: popoverContent)
        statusBar.attachPolling(coordinator)
        statusBar.startObserving()

        networkMonitor = NetworkMonitor()
        startNetworkObservation()

        UNUserNotificationCenter.current().delegate = self
        Task { await notificationManager.requestAuthorization() }

        Task { await restoreSession() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startNetworkObservation() {
        networkTask?.cancel()
        networkTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.networkMonitor.start()
            for await state in await self.networkMonitor.stateStream {
                await self.coordinator.networkChanged(to: state)
            }
        }
    }

    private func restoreSession() async {
        guard let session = try? auth.restore() else { return }
        if let email = session.email {
            appState.authState = .signedIn(email: email)
        }
        await coordinator.start()
    }

    private func signIn() async {
        do {
            _ = try await auth.signIn()
            if let email = auth.session?.email {
                appState.authState = .signedIn(email: email)
            }
            await coordinator.start()
        } catch let error as AppError {
            appState.lastError = error
        } catch {
            appState.lastError = .auth(.authorizationFailed(reason: error.localizedDescription))
        }
    }

    private func signOut() async {
        try? await auth.signOut()
        await coordinator.stop()
        appState.reset()
    }

    private func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(
                settings: settingsModel,
                appState: appState,
                onSignOut: { [weak self] in Task { await self?.signOut() } },
                onSignIn: { [weak self] in Task { await self?.signIn() } },
                onLaunchAtLoginChanged: { [weak self] enabled in
                    self?.loginItems.setEnabled(enabled)
                },
                onPollingIntervalChanged: { [weak self] interval in
                    self?.coordinator.interval = interval
                }
            )
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Gmail Settings"
            window.styleMask = [.titled, .closable]
            settingsWindow = NSWindowController(window: window)
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentMissingClientIDAlert() {
        let alert = NSAlert()
        alert.messageText = "OAuth client ID missing"
        alert.informativeText = """
        Set OAuthClientID and OAuthRedirectURLScheme in Info.plist.
        See README.md for the build steps.
        """
        alert.alertStyle = .critical
        alert.runModal()
        NSApp.terminate(nil)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["url"] as? String, let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
