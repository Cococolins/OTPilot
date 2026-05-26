import AppKit
import OTPilotCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var monitor: MessageMonitor
    @EnvironmentObject private var languageStore: AppLanguageStore
    @FocusState private var isFocusSinkFocused: Bool
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginStatus = LaunchAtLoginService.statusLabel
    @State private var launchAtLoginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsHeader(versionText: appVersionText)

            SettingsSection(title: languageStore.string(.detection)) {
                SettingsLineGroup {
                    SettingsToggleRow(title: languageStore.string(.startMonitoringOnLaunch), isOn: $monitor.startMonitoringOnLaunch)
                    SettingsToggleRow(title: languageStore.string(.autoPasteAfterCopy), isOn: $monitor.autoPasteEnabled)
                        .help(languageStore.string(.autoPasteHelp))
                    SettingsToggleRow(title: languageStore.string(.restoreClipboardAfterDelay), isOn: $monitor.restoreClipboardEnabled)
                        .help(languageStore.string(.restoreClipboardHelp))
                }
            }

            SettingsSection(title: languageStore.string(.startup)) {
                SettingsLineGroup {
                    SettingsToggleRow(
                        title: languageStore.string(.openAtLogin),
                        detail: launchAtLoginError ?? localizedLaunchAtLoginStatus,
                        detailColor: launchAtLoginStatusColor,
                        isOn: Binding(
                            get: { launchAtLoginEnabled },
                            set: { updateLaunchAtLogin($0) }
                        ))
                }
            }

            SettingsSection(title: languageStore.string(.language)) {
                SettingsLineGroup {
                    SettingsPickerRow(title: languageStore.string(.language), selection: Binding(
                        get: { languageStore.selectedLanguage },
                        set: { languageStore.selectedLanguage = $0 }
                    )) { language in
                        languageName(language)
                    }
                }
            }

            SettingsSection(title: languageStore.string(.permissions)) {
                SettingsLineGroup {
                    SettingsButtonRow(title: languageStore.string(.openFullDiskAccess)) {
                        PermissionService.openFullDiskAccessSettings()
                    }
                    SettingsButtonRow(title: languageStore.string(.openAccessibility)) {
                        PermissionService.openAccessibilitySettings()
                        monitor.requestAccessibilityPermission()
                    }
                }
            }

        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            Button("") {}
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
                .focused($isFocusSinkFocused)

            WindowTitleUpdater(title: languageStore.string(.settingsWindowTitle))
        }
        .onAppear {
            refreshLaunchAtLogin()
            isFocusSinkFocused = true
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

private struct SettingsHeader: View {
    let versionText: String

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            if let icon = NSImage(named: "AppPanelIcon") ?? Bundle.main.url(forResource: "AppPanelIcon", withExtension: "png").flatMap(NSImage.init(contentsOf:)) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .accessibilityHidden(true)
            }

            Text("**OTPilot** by Cococolin")
                .font(.body)
                .multilineTextAlignment(.center)

            Text(versionText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 138)
    }
}

private struct WindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        updateWindowTitle(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        updateWindowTitle(for: nsView)
    }

    private func updateWindowTitle(for view: NSView) {
        DispatchQueue.main.async {
            view.window?.title = title
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.headline)

            content
        }
    }
}

private struct SettingsLineGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    var detail: String?
    var detailColor: Color = .secondary
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .lineLimit(1)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
        }
        .font(.body)
        .frame(height: 30)
    }
}

private struct SettingsPickerRow<Label: Hashable & CaseIterable & Identifiable>: View where Label.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: Label
    let displayName: (Label) -> String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .lineLimit(1)

            Spacer(minLength: 8)

            Picker(title, selection: $selection) {
                ForEach(Label.allCases) { option in
                    Text(displayName(option))
                        .tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 96)
            .offset(x: 3)
        }
        .font(.body)
        .frame(height: 30)
    }
}

private struct SettingsButtonRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: 30)
    }
}
