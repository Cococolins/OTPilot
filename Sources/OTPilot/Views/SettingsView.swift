import OTPilotCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var monitor: MessageMonitor
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginStatus = "Unknown"
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("Detection") {
                Toggle("Start monitoring when OTPilot opens", isOn: $monitor.startMonitoringOnLaunch)
                Toggle("Auto paste after copy", isOn: $monitor.autoPasteEnabled)
                Toggle("Restore previous clipboard after 45 seconds", isOn: $monitor.restoreClipboardEnabled)
            }

            Section("Startup") {
                Toggle("Open OTPilot at login", isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { updateLaunchAtLogin($0) }
                ))

                Text(launchAtLoginError ?? launchAtLoginStatus)
                    .font(.caption)
                    .foregroundStyle(launchAtLoginStatusColor)
            }

            Section("Permissions") {
                Button("Open Full Disk Access") {
                    PermissionService.openFullDiskAccessSettings()
                }

                Button("Open Accessibility") {
                    PermissionService.openAccessibilitySettings()
                    monitor.requestAccessibilityPermission()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            refreshLaunchAtLogin()
        }
    }

    private func refreshLaunchAtLogin() {
        launchAtLoginEnabled = LaunchAtLoginService.isEnabled
        launchAtLoginStatus = LaunchAtLoginService.statusLabel
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil

        do {
            try LaunchAtLoginService.setEnabled(enabled)
            refreshLaunchAtLogin()
        } catch {
            refreshLaunchAtLogin()
            launchAtLoginError = error.localizedDescription
        }
    }

    private var launchAtLoginStatusColor: Color {
        launchAtLoginError == nil ? .secondary : .red
    }
}
