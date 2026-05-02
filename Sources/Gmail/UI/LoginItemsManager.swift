import Foundation
import ServiceManagement

@MainActor
struct LoginItemsManager {
    func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            // Silent failure; user can flip the toggle in System Settings.
        }
    }

    func isEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
