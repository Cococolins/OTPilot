import Foundation
import UserNotifications

@MainActor
public final class NotificationService: ObservableObject {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func showCopiedCode(_ detection: DetectedOTP) {
        let content = UNMutableNotificationContent()
        content.title = OTPilotLocalization.currentString(.notificationCopiedTitle)
        content.body = OTPilotLocalization.currentString(.notificationCopiedBody)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "otp-\(detection.rowID)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}
