import Combine
import Foundation
import os

@MainActor
public final class MessageMonitor: ObservableObject {
    @Published public private(set) var state: MonitorState = .idle
    @Published public private(set) var isMonitoring = false
    @Published public private(set) var lastDetection: DetectedOTP?
    @Published public private(set) var recentDetections: [DetectedOTP] = []
    @Published public private(set) var detectedCount: Int
    @Published public var autoPasteEnabled: Bool {
        didSet { userDefaults.set(autoPasteEnabled, forKey: Keys.autoPasteEnabled) }
    }
    @Published public var pressEnterAfterPasteEnabled: Bool {
        didSet { userDefaults.set(pressEnterAfterPasteEnabled, forKey: Keys.pressEnterAfterPasteEnabled) }
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
        static let pressEnterAfterPasteEnabled = "pressEnterAfterPasteEnabled"
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
    private static let pollInterval: TimeInterval = 1.2
    private static let backlogPollInterval: TimeInterval = 0.05
    private static let maximumRetryInterval: TimeInterval = 30
    private static let messageBatchLimit = 50
    private static let maximumMessageAge: TimeInterval = 5 * 60
    private var timer: Timer?
    private var lastRowID: Int64
    private var consecutivePollFailures = 0

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
        self.pressEnterAfterPasteEnabled = userDefaults.object(forKey: Keys.pressEnterAfterPasteEnabled) as? Bool ?? false
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
        guard !isMonitoring else {
            return
        }

        guard store.exists else {
            state = .missingMessagesDatabase
            return
        }

        isMonitoring = true
        state = .monitoring
        logger.info("Monitoring started; cursor rowID \(self.lastRowID, privacy: .public)")
        notifications.requestPermission()
        poll()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        consecutivePollFailures = 0
        state = .idle
        logger.info("Monitoring stopped")
    }

    public func poll() {
        guard isMonitoring else {
            return
        }

        do {
            if lastRowID == 0 {
                lastRowID = try store.latestRowID()
                saveLastRowID()
                logger.info("Initialized cursor at rowID \(self.lastRowID, privacy: .public)")
            }

            let messages = try store.incomingMessages(
                after: lastRowID,
                limit: Self.messageBatchLimit
            )
            for message in messages {
                process(message)
                lastRowID = max(lastRowID, message.rowID)
            }
            saveLastRowID()

            if consecutivePollFailures > 0 {
                logger.info("Message polling recovered after \(self.consecutivePollFailures, privacy: .public) failures")
            }
            consecutivePollFailures = 0
            state = .monitoring

            let nextInterval = messages.count == Self.messageBatchLimit
                ? Self.backlogPollInterval
                : Self.pollInterval
            scheduleNextPoll(after: nextInterval)
        } catch {
            consecutivePollFailures += 1
            state = state(for: error)
            let retryInterval = min(
                Self.maximumRetryInterval,
                Self.pollInterval * pow(2, Double(min(consecutivePollFailures, 5)))
            )
            logger.error(
                "Message polling failed; retrying in \(retryInterval, privacy: .public) seconds: \(error.localizedDescription, privacy: .public)"
            )
            scheduleNextPoll(after: retryInterval)
        }
    }

    public func resetCursorToNow() {
        do {
            lastRowID = try store.latestRowID()
            saveLastRowID()
            consecutivePollFailures = 0
            state = isMonitoring ? .monitoring : .idle
        } catch {
            state = state(for: error)
        }
    }

    public func resetStats() {
        detectedCount = 0
        lastDetection = nil
        recentDetections = []
        userDefaults.set(detectedCount, forKey: Keys.detectedCount)
    }

    public func copyLastCode() {
        guard let lastDetection else {
            return
        }
        copy(detection: lastDetection)
    }

    public func copy(detection: DetectedOTP) {
        clipboard.copy(detection.code, restorePreviousAfter: restoreClipboardEnabled ? 45 : nil)
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

        let messageAge = Date().timeIntervalSince(message.receivedAt)
        guard Self.isMessageRecent(message) else {
            logger.info(
                "Ignored stale OTP candidate rowID \(message.rowID, privacy: .public); ageSeconds=\(Int(messageAge), privacy: .public)"
            )
            return
        }

        let detection = DetectedOTP(code: code, sender: message.sender, rowID: message.rowID)

        lastDetection = detection
        recentDetections.insert(detection, at: 0)
        recentDetections = Array(recentDetections.prefix(6))
        detectedCount += 1
        userDefaults.set(detectedCount, forKey: Keys.detectedCount)

        clipboard.copy(code, restorePreviousAfter: restoreClipboardEnabled ? 45 : nil)
        logger.info("Detected OTP rowID \(message.rowID, privacy: .public); autoPaste=\(self.autoPasteEnabled, privacy: .public); accessibilityTrusted=\(self.autoPaste.isAccessibilityTrusted, privacy: .public)")

        let pasteResult: AutoPasteService.PasteResult = autoPasteEnabled
            ? autoPaste.pasteIntoFocusedField(code, pressEnterAfterPaste: pressEnterAfterPasteEnabled)
            : .failed
        if pasteResult.shouldShowCopiedNotification {
            notifications.showCopiedCode(detection)
        }
    }

    static func isMessageRecent(_ message: MessagesStore.Message, now: Date = Date()) -> Bool {
        now.timeIntervalSince(message.receivedAt) <= maximumMessageAge
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

    private func scheduleNextPoll(after interval: TimeInterval) {
        guard isMonitoring else {
            return
        }

        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func saveLastRowID() {
        userDefaults.set(Int(lastRowID), forKey: Keys.lastRowID)
    }
}
