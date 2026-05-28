import AppKit
import ApplicationServices
import Foundation

public enum PermissionService {
    public static var hasFullDiskAccess: Bool {
        let dbPath = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Messages/chat.db")
            .path
        return FileManager.default.isReadableFile(atPath: dbPath)
    }

    public static var hasAccessibilityAccess: Bool {
        AXIsProcessTrusted()
    }

    public static func openFullDiskAccessSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }

    public static func openAccessibilitySettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    public static func openNotificationSettings() {
        openSettingsPane("x-apple.systempreferences:com.apple.preference.notifications")
    }

    private static func openSettingsPane(_ string: String) {
        guard let url = URL(string: string) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
