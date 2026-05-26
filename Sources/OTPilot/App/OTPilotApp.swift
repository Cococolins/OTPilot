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
            Image(systemName: monitor.state == .monitoring ? "key.fill" : "key")
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
