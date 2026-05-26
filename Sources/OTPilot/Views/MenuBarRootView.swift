import AppKit
import OTPilotCore
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var monitor: MessageMonitor
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Environment(\.openWindow) private var openWindow
    @FocusState private var isFocusSinkFocused: Bool

    enum Layout {
        static let iconColumnWidth: CGFloat = 24
        static let iconTextSpacing: CGFloat = 10
        static let actionButtonSpacing: CGFloat = 14
        static let actionButtonWidth: CGFloat = 76
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider()

            if let detection = monitor.lastDetection {
                IconColumnRow(systemImage: "message") {
                    LastCodeView(detection: detection) {
                        monitor.copyLastCode()
                    }
                }
            } else {
                IconColumnRow(systemImage: "message.badge") {
                    EmptyStateView(
                        title: languageStore.string(.noCodeYet),
                        subtitle: languageStore.string(.noCodeSubtitle)
                    )
                }
            }

            Divider()

            controls

            Divider()

            permissionActions
        }
        .padding(14)
        .frame(width: 226)
        .background {
            Button("") {}
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
                .focused($isFocusSinkFocused)
        }
        .onAppear {
            isFocusSinkFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: Layout.iconTextSpacing) {
            HeaderStatusIcon(state: monitor.state)
                .frame(width: Layout.iconColumnWidth, height: Layout.iconColumnWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text("OTPilot")
                    .font(.headline)
                Text(localizedStateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(monitor.detectedCount)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .accessibilityLabel(languageStore.string(.detectedCodes))

                Text(AppVersion.displayVersion)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconColumnRow(systemImage: "slider.horizontal.3") {
                HStack(spacing: Layout.actionButtonSpacing) {
                    Button {
                        monitor.state == .monitoring ? monitor.stop() : monitor.start()
                    } label: {
                        Label(primaryActionTitle, systemImage: monitor.state == .monitoring ? "stop.fill" : "play.fill")
                            .font(.body)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help(primaryActionTitle)
                    .accessibilityLabel(primaryActionTitle)
                    .frame(width: Layout.actionButtonWidth)

                    Button {
                        monitor.resetCursorToNow()
                        monitor.resetStats()
                    } label: {
                        Label(languageStore.string(.reset), systemImage: "arrow.counterclockwise")
                            .font(.body)
                            .frame(maxWidth: .infinity)
                            .frame(height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(languageStore.string(.reset))
                    .accessibilityLabel(languageStore.string(.reset))
                    .frame(width: Layout.actionButtonWidth)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            MenuToggleRow(
                title: languageStore.string(.autoPaste),
                systemImage: "keyboard",
                isOn: $monitor.autoPasteEnabled
            )
            .help(autoPasteHelp)

            MenuToggleRow(
                title: languageStore.string(.restoreClipboard),
                systemImage: "clipboard",
                isOn: $monitor.restoreClipboardEnabled
            )
            .help(languageStore.string(.restoreClipboardHelp))
        }
    }

    private var permissionActions: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button {
                PermissionService.openFullDiskAccessSettings()
            } label: {
                MenuRowLabel(languageStore.string(.fullDiskAccess), systemImage: "externaldrive.badge.checkmark")
            }

            Button {
                PermissionService.openAccessibilitySettings()
                monitor.requestAccessibilityPermission()
            } label: {
                MenuRowLabel(languageStore.string(.accessibility), systemImage: "hand.tap")
            }

            Button {
                openWindow(id: "settings")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                MenuRowLabel(languageStore.string(.settings), systemImage: "gearshape")
            }

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                MenuRowLabel(languageStore.string(.quit), systemImage: "power")
            }
        }
        .buttonStyle(.plain)
    }

    private var primaryActionTitle: String {
        languageStore.string(monitor.state == .monitoring ? .stop : .start)
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

    private var autoPasteHelp: String {
        if monitor.isAccessibilityTrustedForAutoPaste {
            return languageStore.string(.autoPasteHelp)
        }

        return "\(languageStore.string(.autoPasteHelp)) \(languageStore.string(.accessibilityMissingHelp))"
    }
}

private struct MenuToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            MenuRowLabel(title, systemImage: systemImage)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(MiniSwitchToggleStyle())
        }
        .frame(height: 21)
    }
}

private struct IconColumnRow<Content: View>: View {
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            MenuColumnIcon(systemImage)

            content
        }
    }
}

private struct HeaderStatusIcon: View {
    let state: MonitorState

    var body: some View {
        Image(systemName: state == .monitoring ? "checkmark.circle.fill" : "pause.circle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(state == .monitoring ? .green : .secondary)
            .frame(width: MenuBarRootView.Layout.iconColumnWidth, height: 18, alignment: .center)
    }
}

private struct MiniSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule()
                .fill(configuration.isOn ? Color.accentColor : Color.secondary.opacity(0.25))
                .frame(width: 28, height: 14)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                        .frame(width: 12, height: 12)
                        .padding(1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(OTPilotLocalization.currentString(configuration.isOn ? .enabled : .disabled))
    }
}

private struct MenuRowLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        IconColumnRow(systemImage: systemImage) {
            Text(title)
                .foregroundStyle(.primary)
                .font(.body)

            Spacer(minLength: 0)
        }
        .frame(height: 21)
        .contentShape(Rectangle())
    }
}

private struct MenuColumnIcon: View {
    let systemName: String

    init(_ systemName: String) {
        self.systemName = systemName
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: MenuBarRootView.Layout.iconColumnWidth, height: 18, alignment: .center)
    }
}

private struct LastCodeView: View {
    let detection: DetectedOTP
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(detection.code)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospaced()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help(OTPilotLocalization.currentString(.copy))
            }

            HStack(spacing: 6) {
                Text(detection.sender)
                Text("\(OTPilotLocalization.currentString(.timePrefix)) \(OTPilotDateFormatting.detectionTime.string(from: detection.detectedAt))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
