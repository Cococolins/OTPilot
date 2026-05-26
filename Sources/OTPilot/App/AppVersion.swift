import Foundation

enum AppVersion {
    private static let fallbackVersion = "1.4"

    static var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallbackVersion
    }

    static var buildNumber: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }

    static var displayVersion: String {
        "v\(shortVersion)"
    }

    static var fullDisplayVersion: String {
        if let buildNumber {
            return "Version \(shortVersion) (\(buildNumber))"
        }

        return "Version \(shortVersion)"
    }
}
