import AppKit
import OTPilotCore
import SwiftUI

@main
struct OTPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = MessageMonitor()
    @StateObject private var languageStore = AppLanguageStore()

    private enum SettingsWindowLayout {
        static let width: CGFloat = 348
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(monitor)
                .environmentObject(languageStore)
                .task {
                    monitor.startIfEnabledOnLaunch()
                }
        } label: {
            StatusBarIconView()
        }
        .menuBarExtraStyle(.window)

        Window(languageStore.string(.settingsWindowTitle), id: "settings") {
            SettingsView()
                .environmentObject(monitor)
                .environmentObject(languageStore)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: SettingsWindowLayout.width)
        }
        .defaultSize(width: SettingsWindowLayout.width, height: 1)
        .windowResizability(.contentSize)
    }
}

private struct StatusBarIconView: View {
    var body: some View {
        if let icon = NSImage.statusBarTemplate(named: "AppStatusBarIconTemplate") {
            Image(nsImage: icon)
        } else {
            Image(systemName: "key")
        }
    }
}

private extension NSImage {
    static func statusBarTemplate(named name: String) -> NSImage? {
        let source = NSImage(named: name)
            ?? Bundle.main.url(forResource: name, withExtension: "png").flatMap(NSImage.init(contentsOf:))
        guard let image = source?.copy() as? NSImage else {
            return nil
        }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
