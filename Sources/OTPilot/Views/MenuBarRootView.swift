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
        static let actionButtonWidth: CGFloat = 80
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Divider().opacity(0.5)

            if let detection = monitor.lastDetection {
                IconColumnRow(systemImage: "message") {
                    LastCodeView(detection: detection) {
                        monitor.copyLastCode()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                IconColumnRow(systemImage: "message.badge.waveform") {
                    EmptyStateView(
                        title: languageStore.string(.noCodeYet),
                        subtitle: languageStore.string(.noCodeSubtitle)
                    )
                }
                .transition(.opacity)
            }

            Divider().opacity(0.5)

            controls

            Divider().opacity(0.5)

            permissionActions
        }
        .animation(.easeOut(duration: 0.25), value: monitor.lastDetection != nil)
        .padding(14)
        .frame(width: 240)
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

                Text(languageStore.string(.codesUnit))
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
                    .disabled(monitor.detectedCount == 0 && monitor.lastDetection == nil && monitor.state != .monitoring)
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
            PermissionActionRow(
                title: languageStore.string(.fullDiskAccess),
                systemImage: "externaldrive.badge.checkmark",
                isGranted: PermissionService.hasFullDiskAccess
            ) {
                PermissionService.openFullDiskAccessSettings()
            }

            PermissionActionRow(
                title: languageStore.string(.accessibility),
                systemImage: "hand.tap",
                isGranted: PermissionService.hasAccessibilityAccess
            ) {
                PermissionService.openAccessibilitySettings()
                monitor.requestAccessibilityPermission()
            }

            Button {
                openWindow(id: "settings")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                MenuRowLabel(languageStore.string(.settings), systemImage: "gearshape")
            }
            .accessibilityAddTraits(.isButton)

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                MenuRowLabel(languageStore.string(.quit), systemImage: "power")
            }
            .accessibilityAddTraits(.isButton)
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

// MARK: - Permission Action Row

private struct PermissionActionRow: View {
    let title: String
    let systemImage: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                IconColumnRow(systemImage: systemImage) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .font(.body)

                    Spacer(minLength: 0)
                }

                Circle()
                    .fill(isGranted ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
            }
            .frame(height: 21)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Toggle Row

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
        .frame(height: 24)
    }
}

// MARK: - Icon Column Row

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

// MARK: - Header Status Icon

private struct HeaderStatusIcon: View {
    let state: MonitorState

    var body: some View {
        Image(systemName: state == .monitoring ? "checkmark.circle.fill" : "pause.circle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(state == .monitoring ? .green : .secondary)
            .frame(width: MenuBarRootView.Layout.iconColumnWidth, height: 18, alignment: .center)
            .opacity(state == .monitoring ? 1 : 1)
            .modifier(PulseModifier(isActive: state == .monitoring))
    }
}

private struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing && isActive ? 0.65 : 1.0)
            .animation(
                isActive
                    ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onChange(of: isActive) { newValue in
                isPulsing = newValue
            }
            .onAppear {
                if isActive { isPulsing = true }
            }
    }
}

// MARK: - Mini Toggle Style

private struct MiniSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule()
                .fill(configuration.isOn ? Color.accentColor : Color.secondary.opacity(0.25))
                .frame(width: 32, height: 16)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                        .frame(width: 14, height: 14)
                        .padding(1)
                }
                .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.plain)
        .accessibilityValue(OTPilotLocalization.currentString(configuration.isOn ? .enabled : .disabled))
    }
}

// MARK: - Menu Row Label

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

// MARK: - Menu Column Icon

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

// MARK: - Last Code View

private struct LastCodeView: View {
    let detection: DetectedOTP
    let copy: () -> Void

    @State private var showCopyConfirm = false
    @State private var relativeTime = ""
    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(groupedCode(detection.code))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospaced()
                    .kerning(1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(
                        "\(OTPilotLocalization.currentString(.detectedCodes)): \(detection.code)"
                    )

                Spacer()

                Button {
                    copy()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCopyConfirm = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCopyConfirm = false
                        }
                    }
                } label: {
                    Image(systemName: showCopyConfirm ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(showCopyConfirm ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help(OTPilotLocalization.currentString(.copy))
            }

            HStack(spacing: 6) {
                Text(detection.sender)
                Text(relativeTime)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.06))
        )
        .onAppear {
            updateRelativeTime()
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
        .onChange(of: detection.code) { _ in
            updateRelativeTime()
        }
    }

    private func groupedCode(_ code: String) -> String {
        // Only group purely numeric codes of even length (4, 6, 8)
        guard code.count >= 4, code.count <= 8, code.count.isMultiple(of: 2),
              code.allSatisfy(\.isNumber) else {
            return code
        }
        let mid = code.index(code.startIndex, offsetBy: code.count / 2)
        return "\(code[code.startIndex..<mid]) \(code[mid...])"
    }

    private func updateRelativeTime() {
        let seconds = Int(-detection.detectedAt.timeIntervalSinceNow)
        if seconds < 5 {
            relativeTime = OTPilotLocalization.currentString(.justNow)
        } else if seconds < 60 {
            let template = OTPilotLocalization.currentString(.secondsAgo)
            relativeTime = String(format: template, seconds)
        } else {
            let minutes = seconds / 60
            let template = OTPilotLocalization.currentString(.minutesAgo)
            relativeTime = String(format: template, minutes)
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            Task { @MainActor in
                updateRelativeTime()
            }
        }
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
