import AppKit
import OTPilotCore
import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    var body: some View {
        VStack(spacing: 10) {
            if let icon = NSImage(named: "AppPanelIcon") ?? Bundle.main.url(forResource: "AppPanelIcon", withExtension: "png").flatMap(NSImage.init(contentsOf:)) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)
            }

            Text("**OTPilot** by Cococolin")
                .font(.title3)
                .multilineTextAlignment(.center)

            Text(appVersionText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            WindowTitleUpdater(title: languageStore.string(.settingsWindowTitle))
        }
    }

    private var appVersionText: String {
        let prefix = languageStore.selectedLanguage.resolved == .simplifiedChinese ? "版本" : "Version"
        if let buildNumber = AppVersion.buildNumber {
            return "\(prefix) \(AppVersion.shortVersion) (\(buildNumber))"
        }

        return "\(prefix) \(AppVersion.shortVersion)"
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
