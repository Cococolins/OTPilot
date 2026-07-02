import AppKit
import OTPilotCore
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var monitor: MessageMonitor
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLoginEnabled = false

    var body: some View {
        Text(localizedStateLabel)
            .foregroundStyle(.secondary)

        Divider()

        recentCodesMenu

        Divider()

        Toggle(isOn: monitoringBinding) {
            Label(languageStore.string(.monitorMessages), systemImage: "dot.radiowaves.left.and.right")
        }
        .disabled(monitor.state == .missingMessagesDatabase || monitor.state == .fullDiskAccessRequired)

        Button {
            monitor.resetCursorToNow()
            monitor.resetStats()
        } label: {
            Label(languageStore.string(.reset), systemImage: "arrow.counterclockwise")
        }
        .disabled(monitor.detectedCount == 0 && monitor.lastDetection == nil && monitor.state != .monitoring)

        Divider()

        settingsMenu

        Button(role: .destructive) {
            NSApplication.shared.terminate(nil)
        } label: {
            Label(languageStore.string(.quit), systemImage: "power")
        }
        .onAppear {
            launchAtLoginEnabled = LaunchAtLoginService.isEnabled
        }
    }

    private var recentCodesMenu: some View {
        Menu {
            if monitor.recentDetections.isEmpty {
                Text(languageStore.string(.noCodeYet))
            } else {
                ForEach(monitor.recentDetections, id: \.rowID) { detection in
                    Button {
                        monitor.copy(detection: detection)
                    } label: {
                        Text(recentCodeTitle(for: detection))
                    }
                }
            }
        } label: {
            Label(languageStore.string(.copyVerificationCode), systemImage: "doc.on.doc")
        }
        .disabled(monitor.recentDetections.isEmpty)
    }

    private var settingsMenu: some View {
        Menu {
            Button {
                openWindow(id: "about")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Label(languageStore.string(.about), systemImage: "info.circle")
            }

            Divider()

            Toggle(isOn: launchAtLoginBinding) {
                Label(languageStore.string(.openAtLogin), systemImage: "loginwindow")
            }

            Toggle(isOn: $monitor.startMonitoringOnLaunch) {
                Label(languageStore.string(.startMonitoringOnLaunch), systemImage: "play.circle")
            }

            Toggle(isOn: $monitor.autoPasteEnabled) {
                Label(languageStore.string(.autoPaste), systemImage: "keyboard")
            }
            .help(autoPasteHelp)

            Toggle(isOn: $monitor.pressEnterAfterPasteEnabled) {
                Label(languageStore.string(.pressEnterAfterPaste), systemImage: "return")
            }
            .disabled(!monitor.autoPasteEnabled)
            .help(languageStore.string(.pressEnterAfterPasteHelp))

            Toggle(isOn: $monitor.restoreClipboardEnabled) {
                Label(languageStore.string(.restoreClipboard), systemImage: "clipboard")
            }
            .help(languageStore.string(.restoreClipboardHelp))

            languageMenu

            Divider()

            Button {
                PermissionService.openFullDiskAccessSettings()
            } label: {
                Label(fullDiskAccessTitle, systemImage: PermissionService.hasFullDiskAccess ? "checkmark.circle" : "exclamationmark.circle")
            }

            Button {
                PermissionService.openAccessibilitySettings()
                monitor.requestAccessibilityPermission()
            } label: {
                Label(accessibilityTitle, systemImage: PermissionService.hasAccessibilityAccess ? "checkmark.circle" : "exclamationmark.circle")
            }
        } label: {
            Label(languageStore.string(.settings), systemImage: "gearshape")
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(OTPilotLanguage.allCases) { language in
                Toggle(isOn: languageSelectionBinding(for: language)) {
                    Text(languageName(language))
                }
            }
        } label: {
            Label(languageStore.string(.language), systemImage: "globe")
        }
    }

    private var monitoringBinding: Binding<Bool> {
        Binding {
            monitor.isMonitoring
        } set: { isMonitoring in
            if isMonitoring {
                monitor.start()
            } else {
                monitor.stop()
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding {
            launchAtLoginEnabled
        } set: { isEnabled in
            updateLaunchAtLogin(isEnabled)
        }
    }

    private func languageSelectionBinding(for language: OTPilotLanguage) -> Binding<Bool> {
        Binding {
            languageStore.selectedLanguage == language
        } set: { isSelected in
            if isSelected {
                languageStore.selectedLanguage = language
            }
        }
    }

    private var localizedStateLabel: String {
        switch monitor.state {
        case .idle:
            return languageStore.string(.idle)
        case .monitoring:
            return languageStore.string(.monitoring)
        case .missingMessagesDatabase:
            return languageStore.string(.messagesDatabaseNotFound)
        case .fullDiskAccessRequired:
            return languageStore.string(.fullDiskAccessRequired)
        case .databaseError(let message):
            return message
        }
    }

    private func updateLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(isEnabled)
        } catch {
            // Keep the menu state aligned with the system if registration needs approval or fails.
        }
        launchAtLoginEnabled = LaunchAtLoginService.isEnabled
    }

    private func languageName(_ language: OTPilotLanguage) -> String {
        switch language {
        case .system:
            return languageStore.string(.languageSystem)
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        }
    }

    private var autoPasteHelp: String {
        if monitor.isAccessibilityTrustedForAutoPaste {
            return languageStore.string(.autoPasteHelp)
        }

        return "\(languageStore.string(.autoPasteHelp)) \(languageStore.string(.accessibilityMissingHelp))"
    }

    private var fullDiskAccessTitle: String {
        permissionTitle(
            name: languageStore.string(.fullDiskAccess),
            isGranted: PermissionService.hasFullDiskAccess
        )
    }

    private var accessibilityTitle: String {
        permissionTitle(
            name: languageStore.string(.accessibility),
            isGranted: PermissionService.hasAccessibilityAccess
        )
    }

    private func permissionTitle(name: String, isGranted: Bool) -> String {
        let status = languageStore.string(isGranted ? .permissionGranted : .permissionMissing)
        return "\(name): \(status)"
    }

    private func recentCodeTitle(for detection: DetectedOTP) -> String {
        let sender = detection.sender.isEmpty ? languageStore.string(.unknown) : detection.sender
        return "\(groupedCode(detection.code))   \(sender)   \(relativeTime(for: detection))"
    }

    private func groupedCode(_ code: String) -> String {
        guard code.count >= 4, code.count <= 8, code.count.isMultiple(of: 2),
              code.allSatisfy(\.isNumber) else {
            return code
        }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[code.startIndex..<mid]) \(code[mid...])"
    }

    private func relativeTime(for detection: DetectedOTP) -> String {
        let seconds = Int(-detection.detectedAt.timeIntervalSinceNow)
        if seconds < 5 {
            return languageStore.string(.justNow)
        }
        if seconds < 60 {
            return String(format: languageStore.string(.secondsAgo), seconds)
        }
        return String(format: languageStore.string(.minutesAgo), seconds / 60)
    }
}
