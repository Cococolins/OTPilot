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

    @discardableResult
    public func pasteIntoFocusedField() -> Bool {
        guard isAccessibilityTrusted else {
            logger.warning("Auto paste skipped: Accessibility is not trusted")
            return false
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            logger.warning("Auto paste skipped: failed to create keyboard events")
            return false
        }

        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        logger.info("Posted Command-V event")
        return true
    }
}
