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
        content.title = "OTP copied"
        content.body = "A verification code is ready to paste."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "otp-\(detection.rowID)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}
