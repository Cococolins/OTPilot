import AppKit
import OTPilotCore
import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var monitor: MessageMonitor
    @Environment(\.openWindow) private var openWindow
    private let controlColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

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
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: monitor.state == .monitoring ? "checkmark.circle.fill" : "pause.circle")
                .font(.title2)
                .foregroundStyle(monitor.state == .monitoring ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("OTPilot")
                    .font(.headline)
                Text(monitor.state.label)
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
                    .accessibilityLabel("Detected codes")

                Text(AppVersion.displayVersion)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: controlColumns, spacing: 0) {
                Button {
                    monitor.state == .monitoring ? monitor.stop() : monitor.start()
                } label: {
                    Label(monitor.state == .monitoring ? "Stop" : "Start", systemImage: monitor.state == .monitoring ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    monitor.resetCursorToNow()
                } label: {
                    Label("Skip Old", systemImage: "forward.end.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    monitor.resetStats()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
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
                .toggleStyle(.switch)
        }
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
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 26)

            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
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
            Image(systemName: "message.badge")
                .font(.title3)
                .foregroundStyle(.secondary)

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
