import Foundation
import ServiceManagement

@MainActor
public enum LaunchAtLoginService {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static var statusLabel: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Disabled"
        case .notFound:
            return "App bundle not found"
        case .requiresApproval:
            return "Waiting for approval"
        @unknown default:
            return "Unknown"
        }
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
