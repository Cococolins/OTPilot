import AppKit
import OTPilotCore
import SwiftUI

@main
struct OTPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = MessageMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(monitor)
                .task {
                    monitor.startIfEnabledOnLaunch()
                }
        } label: {
            Image(systemName: monitor.state == .monitoring ? "key.fill" : "key")
        }
        .menuBarExtraStyle(.window)

        Window("OTPilot Settings", id: "settings") {
            SettingsView()
                .environmentObject(monitor)
                .frame(width: 520, height: 460)
        }
        .defaultSize(width: 520, height: 460)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
