import Foundation
import OTPilotCore

@MainActor
final class AppLanguageStore: ObservableObject {
    @Published var selectedLanguage: OTPilotLanguage {
        didSet {
            userDefaults.set(selectedLanguage.rawValue, forKey: OTPilotLanguage.defaultsKey)
        }
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.selectedLanguage = OTPilotLocalization.preferredLanguage(userDefaults: userDefaults)
    }

    func string(_ key: OTPilotLocalizationKey) -> String {
        OTPilotLocalization.string(key, language: selectedLanguage)
    }
}
