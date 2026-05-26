import OTPilotCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var monitor: MessageMonitor
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginStatus = LaunchAtLoginService.statusLabel
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section(languageStore.string(.detection)) {
                Toggle(languageStore.string(.startMonitoringOnLaunch), isOn: $monitor.startMonitoringOnLaunch)
                Toggle(languageStore.string(.autoPasteAfterCopy), isOn: $monitor.autoPasteEnabled)
                Toggle(languageStore.string(.restoreClipboardAfterDelay), isOn: $monitor.restoreClipboardEnabled)
            }

            Section(languageStore.string(.startup)) {
                Toggle(languageStore.string(.openAtLogin), isOn: Binding(
                    get: { launchAtLoginEnabled },
                    set: { updateLaunchAtLogin($0) }
                ))

                Text(launchAtLoginError ?? localizedLaunchAtLoginStatus)
                    .font(.caption)
                    .foregroundStyle(launchAtLoginStatusColor)
            }

            Section(languageStore.string(.language)) {
                Picker(languageStore.string(.language), selection: Binding(
                    get: { languageStore.selectedLanguage },
                    set: { languageStore.selectedLanguage = $0 }
                )) {
                    ForEach(OTPilotLanguage.allCases) { language in
                        Text(languageName(language))
                            .tag(language)
                    }
                }
            }

            Section(languageStore.string(.permissions)) {
                Button(languageStore.string(.openFullDiskAccess)) {
                    PermissionService.openFullDiskAccessSettings()
                }

                Button(languageStore.string(.openAccessibility)) {
                    PermissionService.openAccessibilitySettings()
                    monitor.requestAccessibilityPermission()
                }
            }

            Section(languageStore.string(.about)) {
                LabeledContent("OTPilot by Cococolin", value: appVersionText)
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

    private var appVersionText: String {
        let prefix = languageStore.selectedLanguage.resolved == .simplifiedChinese ? "版本" : "Version"
        if let buildNumber = AppVersion.buildNumber {
            return "\(prefix) \(AppVersion.shortVersion) (\(buildNumber))"
        }

        return "\(prefix) \(AppVersion.shortVersion)"
    }

    private var localizedLaunchAtLoginStatus: String {
        switch launchAtLoginStatus {
        case "Enabled":
            return languageStore.string(.enabled)
        case "Disabled":
            return languageStore.string(.disabled)
        case "App bundle not found":
            return languageStore.string(.appBundleNotFound)
        case "Waiting for approval":
            return languageStore.string(.waitingForApproval)
        default:
            return languageStore.string(.unknown)
        }
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
}
