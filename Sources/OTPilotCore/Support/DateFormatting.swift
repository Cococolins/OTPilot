import Foundation

public enum OTPilotDateFormatting {
    public static let detectionTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}
