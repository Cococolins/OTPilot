import AppKit
import OTPilotCore
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var monitor: MessageMonitor
    @Environment(\.openWindow) private var openWindow

    private enum Layout {
        static let iconColumnWidth: CGFloat = 26
        static let iconTextSpacing: CGFloat = 10
        static let actionButtonSpacing: CGFloat = 18
        static let actionButtonWidth: CGFloat = 72
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            if let detection = monitor.lastDetection {
                LastCodeView(detection: detection) {
                    monitor.copyLastCode()
                }
            } else {
                EmptyStateView()
            }

            Divider()

            controls

            Divider()

            permissionActions
        }
        .padding(14)
        .frame(width: 226)
    }

    private var header: some View {
        HStack(spacing: Layout.iconTextSpacing) {
            AppIconView()
                .frame(width: Layout.iconColumnWidth, height: Layout.iconColumnWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text("OTPilot")
                    .font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: monitor.state == .monitoring ? "checkmark.circle.fill" : "pause.circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(monitor.state == .monitoring ? .green : .secondary)

                    Text(monitor.state.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(monitor.detectedCount)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Detected codes")

                Text(AppVersion.displayVersion)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: Layout.iconTextSpacing) {
                MenuIcon("slider.horizontal.3")

                HStack(spacing: Layout.actionButtonSpacing) {
                    Button {
                        monitor.state == .monitoring ? monitor.stop() : monitor.start()
                    } label: {
                        Label(monitor.state == .monitoring ? "Stop" : "Start", systemImage: monitor.state == .monitoring ? "stop.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .help(monitor.state == .monitoring ? "Stop" : "Start")
                    .accessibilityLabel(monitor.state == .monitoring ? "Stop" : "Start")
                    .frame(width: Layout.actionButtonWidth)

                    Button {
                        monitor.resetCursorToNow()
                        monitor.resetStats()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.bordered)
                    .help("Reset")
                    .accessibilityLabel("Reset")
                    .frame(width: Layout.actionButtonWidth)
                }
            }
            .controlSize(.small)
            .frame(maxWidth: .infinity)

            MenuToggleRow(
                title: "Auto paste",
                systemImage: "keyboard",
                isOn: $monitor.autoPasteEnabled
            )
            .help(monitor.isAccessibilityTrustedForAutoPaste ? "Accessibility is enabled" : "Accessibility permission is missing")

            MenuToggleRow(
                title: "Restore clipboard",
                systemImage: "clipboard",
                isOn: $monitor.restoreClipboardEnabled
            )
        }
    }

    private var permissionActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                PermissionService.openFullDiskAccessSettings()
            } label: {
                MenuRowLabel("Full Disk Access", systemImage: "externaldrive.badge.checkmark")
            }

            Button {
                PermissionService.openAccessibilitySettings()
                monitor.requestAccessibilityPermission()
            } label: {
                MenuRowLabel("Accessibility", systemImage: "hand.tap")
            }

            Button {
                openWindow(id: "settings")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                MenuRowLabel("Settings", systemImage: "gearshape")
            }

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                MenuRowLabel("Quit", systemImage: "power")
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MenuToggleRow: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            MenuRowLabel(title, systemImage: systemImage)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(MiniSwitchToggleStyle())
        }
        .frame(minHeight: 24)
    }
}

private struct AppIconView: View {
    var body: some View {
        if let icon = NSImage(named: "AppIcon") ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:)) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "key.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
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
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

private struct MenuRowLabel: View {
    let title: String
    let systemImage: String
    private let iconTextSpacing: CGFloat = 10

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: iconTextSpacing) {
            MenuIcon(systemImage)

            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct MenuIcon: View {
    let systemName: String

    init(_ systemName: String) {
        self.systemName = systemName
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .frame(width: 26)
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
                .help("Copy")
            }

            HStack(spacing: 6) {
                Image(systemName: "message")
                Text(detection.sender)
                Text("at \(OTPilotDateFormatting.detectionTime.string(from: detection.detectedAt))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        HStack(spacing: 10) {
            MenuIcon("message.badge")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("No code yet")
                    .font(.subheadline.weight(.medium))
                Text("New SMS codes will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
