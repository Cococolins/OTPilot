import AppKit
import ApplicationServices
import Foundation
import os

@MainActor
public final class AutoPasteService: ObservableObject {
    private let logger = Logger(subsystem: "app.otpilot.OTPilot", category: "AutoPaste")

    public init() {}

    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    public func pasteIntoFocusedField() {
        guard isAccessibilityTrusted else {
            logger.warning("Auto paste skipped: Accessibility is not trusted")
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        logger.info("Posted Command-V event")
    }
}
