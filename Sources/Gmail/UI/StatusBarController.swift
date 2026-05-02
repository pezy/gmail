import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusBarController {
    let statusItem: NSStatusItem
    let popover: NSPopover

    private let appState: AppState
    private var observationTask: Task<Void, Never>?
    private weak var pollingCoordinator: PollingCoordinator?

    init(appState: AppState, popoverContent: some View) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.popover.contentSize = NSSize(width: 380, height: 480)
        self.popover.behavior = .transient
        self.popover.contentViewController = NSHostingController(rootView: AnyView(popoverContent))

        configureButton()
    }

    func attachPolling(_ coordinator: PollingCoordinator) {
        self.pollingCoordinator = coordinator
    }

    func startObserving() {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            await self?.observeLoop()
        }
    }

    func stopObserving() {
        observationTask?.cancel()
        observationTask = nil
    }

    private func observeLoop() async {
        while !Task.isCancelled {
            apply(currentPresentation())
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    private func currentPresentation() -> StatusBarPresentation {
        StatusBarPresenter.present(
            unreadCount: appState.unreadCount,
            authState: appState.authState,
            connection: appState.connectionState,
            lastError: appState.lastError
        )
    }

    private func apply(_ presentation: StatusBarPresentation) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: presentation.symbolName, accessibilityDescription: "Gmail")
        button.title = presentation.title.isEmpty ? "" : " \(presentation.title)"
        button.imagePosition = .imageLeft
        button.contentTintColor = color(for: presentation.tone)
    }

    private func color(for tone: StatusBarTone) -> NSColor? {
        switch tone {
        case .normal: return nil
        case .auth: return .systemYellow
        case .network: return .systemGray
        case .api: return .systemRed
        }
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
    }

    @objc
    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            Task { await pollingCoordinator?.popoverClosed() }
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Task { await pollingCoordinator?.popoverOpened() }
        }
    }
}
