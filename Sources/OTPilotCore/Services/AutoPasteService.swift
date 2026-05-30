import AppKit
import ApplicationServices
import Foundation
import os

@MainActor
public final class AutoPasteService: ObservableObject {
    private let logger = Logger(subsystem: "app.otpilot.OTPilot", category: "AutoPaste")

    public init() {}

    public enum PasteResult: Equatable {
        case postedCommandV
        case accessibilityNotTrusted
        case noFocusedEditableElement
        case failed

        public var shouldShowCopiedNotification: Bool {
            switch self {
            case .postedCommandV:
                return false
            case .accessibilityNotTrusted, .noFocusedEditableElement, .failed:
                return true
            }
        }
    }

    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    public func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    public func pasteIntoFocusedField(_ text: String, pressEnterAfterPaste: Bool = false) -> PasteResult {
        guard isAccessibilityTrusted else {
            logger.warning("Auto paste skipped: Accessibility is not trusted")
            return .accessibilityNotTrusted
        }

        guard let focusedElement = focusedElementInFrontmostApplication() else {
            logger.warning("Auto paste skipped: no focused UI element found")
            return .noFocusedEditableElement
        }

        guard isEditableTextElement(focusedElement) else {
            logger.warning("Auto paste skipped: focused UI element is not an editable text field")
            return .noFocusedEditableElement
        }

        guard postCommandV() else {
            return .failed
        }

        if pressEnterAfterPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self, logger] in
                if self?.postKey(0x24) == true {
                    logger.info("Posted Return event after paste")
                } else {
                    logger.warning("Auto paste skipped Return: failed to create keyboard events")
                }
            }
        }

        return .postedCommandV
    }

    private func focusedElementInFrontmostApplication() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            logger.warning("Failed to read focused UI element: \(String(describing: error), privacy: .public)")
            return nil
        }

        return (value as! AXUIElement)
    }

    private func isEditableTextElement(_ element: AXUIElement) -> Bool {
        guard isAttributeSettable(kAXValueAttribute, on: element) else {
            return false
        }

        let role = stringAttribute(kAXRoleAttribute, from: element)
        return role == (kAXTextFieldRole as String)
            || role == (kAXTextAreaRole as String)
            || role == (kAXComboBoxRole as String)
    }

    private func postCommandV() -> Bool {
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

    private func postKey(_ virtualKey: CGKeyCode) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        else {
            return false
        }

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func isAttributeSettable(_ attribute: String, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        guard error == .success else {
            return false
        }

        return settable.boolValue
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return nil
        }

        return value as? String
    }
}
