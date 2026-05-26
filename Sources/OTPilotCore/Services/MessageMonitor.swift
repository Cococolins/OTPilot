import Combine
import Foundation
import os

@MainActor
public final class MessageMonitor: ObservableObject {
    @Published public private(set) var state: MonitorState = .idle
    @Published public private(set) var lastDetection: DetectedOTP?
    @Published public private(set) var detectedCount: Int
    @Published public var autoPasteEnabled: Bool {
        didSet { userDefaults.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled) }
    }
    @Published public var restoreClipboardEnabled: Bool {
        didSet { userDefaults.set(restoreClipboardEnabled, forKey: Keys.restoreClipboardEnabled) }
    }
    @Published public var startMonitoringOnLaunch: Bool {
        didSet { userDefaults.set(startMonitoringOnLaunch, forKey: Keys.startMonitoringOnLaunch) }
    }

    private enum Keys {
        static let lastRowID = "lastRowID"
        static let detectedCount = "detectedCount"
        static let autoPasteEnabled = "autoPasteEnabled"
        static let restoreClipboardEnabled = "restoreClipboardEnabled"
        static let startMonitoringOnLaunch = "startMonitoringOnLaunch"
    }

    private let store: MessagesStore
    private let parser: OTPParser
    private let clipboard: ClipboardService
    private let autoPaste: AutoPasteService
    private let notifications: NotificationService
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "app.otpilot.OTPilot", category: "MessageMonitor")
    private var timer: Timer?
    private var lastRowID: Int64

    public init(
        store: MessagesStore = MessagesStore(),
        parser: OTPParser = OTPParser(),
        clipboard: ClipboardService = ClipboardService(),
        autoPaste: AutoPasteService = AutoPasteService(),
        notifications: NotificationService = NotificationService(),
        userDefaults: UserDefaults = .standard
    ) {
        self.store = store
        self.parser = parser
        self.clipboard = clipboard
        self.autoPaste = autoPaste
        self.notifications = notifications
        self.userDefaults = userDefaults
        self.lastRowID = Int64(userDefaults.integer(forKey: Keys.lastRowID))
        self.detectedCount = userDefaults.integer(forKey: Keys.detectedCount)
        self.autoPasteEnabled = userDefaults.object(forKey: Keys.autoPasteEnabled) as? Bool ?? false
        self.restoreClipboardEnabled = userDefaults.object(forKey: Keys.restoreClipboardEnabled) as? Bool ?? true
        self.startMonitoringOnLaunch = userDefaults.object(forKey: Keys.startMonitoringOnLaunch) as? Bool ?? true
    }

    public func startIfEnabledOnLaunch() {
        guard startMonitoringOnLaunch else {
            return
        }

        start()
    }

    public func start() {
        guard timer == nil else {
            return
        }

        guard store.exists else {
            state = .missingMessagesDatabase
            return
        }

        if lastRowID == 0 {
            do {
                lastRowID = try store.latestRowID()
                saveLastRowID()
            } catch {
                state = state(for: error)
                return
            }
        }

        state = .monitoring
        notifications.requestPermission()
        poll()

        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
    }

    public func poll() {
        guard state == .monitoring else {
            return
        }

        do {
            let messages = try store.incomingMessages(after: lastRowID)
            for message in messages {
                process(message)
                lastRowID = max(lastRowID, message.rowID)
            }
            saveLastRowID()
        } catch {
            state = state(for: error)
            stopTimerOnly()
        }
    }

    public func resetCursorToNow() {
        do {
            lastRowID = try store.latestRowID()
            saveLastRowID()
            state = timer == nil ? .idle : .monitoring
        } catch {
            state = state(for: error)
        }
    }

    public func resetStats() {
        detectedCount = 0
        lastDetection = nil
        userDefaults.set(detectedCount, forKey: Keys.detectedCount)
    }

    public func copyLastCode() {
        guard let lastDetection else {
            return
        }
        clipboard.copy(lastDetection.code, restorePreviousAfter: restoreClipboardEnabled ? 45 : nil)
    }

    public func requestAccessibilityPermission() {
        autoPaste.requestAccessibilityPermission()
    }

    public var isAccessibilityTrustedForAutoPaste: Bool {
        autoPaste.isAccessibilityTrusted
    }

    private func process(_ message: MessagesStore.Message) {
        guard let code = parser.extract(from: message.text) else {
            logger.debug("Ignored incoming message rowID \(message.rowID, privacy: .public): no OTP detected")
            return
        }

        let detection = DetectedOTP(code: code, sender: message.sender, rowID: message.rowID)

        lastDetection = detection
        detectedCount += 1
        userDefaults.set(detectedCount, forKey: Keys.detectedCount)

        clipboard.copy(code, restorePreviousAfter: restoreClipboardEnabled ? 45 : nil)
        logger.info("Detected OTP rowID \(message.rowID, privacy: .public); autoPaste=\(self.autoPasteEnabled, privacy: .public); accessibilityTrusted=\(self.autoPaste.isAccessibilityTrusted, privacy: .public)")

        let pasteResult: AutoPasteService.PasteResult = autoPasteEnabled ? autoPaste.pasteIntoFocusedField(code) : .failed
        if pasteResult.shouldShowCopiedNotification {
            notifications.showCopiedCode(detection)
        }
    }

    private func state(for error: Error) -> MonitorState {
        if let storeError = error as? MessagesStore.StoreError {
            switch storeError {
            case .databaseMissing:
                return .missingMessagesDatabase
            case .openFailed(let detail):
                if detail.localizedCaseInsensitiveContains("authorization")
                    || detail.localizedCaseInsensitiveContains("unable to open database file") {
                    return .fullDiskAccessRequired
                }
                return .databaseError(detail)
            case .prepareFailed(let detail):
                return .databaseError(detail)
            }
        }

        return .databaseError(error.localizedDescription)
    }

    private func stopTimerOnly() {
        timer?.invalidate()
        timer = nil
    }

    private func saveLastRowID() {
        userDefaults.set(Int(lastRowID), forKey: Keys.lastRowID)
    }
}
