import Foundation
import UserNotifications

@MainActor
public final class NotificationService: ObservableObject {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func showDetectedCode(_ detection: DetectedOTP, autoPasted: Bool) {
        let content = UNMutableNotificationContent()
        content.title = autoPasted ? "OTP pasted" : "OTP copied"
        content.body = "A verification code is ready."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "otp-\(detection.rowID)",
            content: content,
            trigger: nil
        )

        center.add(request)
    }
}
