import Foundation

public enum OTPilotLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case simplifiedChinese

    public static let defaultsKey = "appLanguage"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return OTPilotLocalization.string(.languageSystem)
        case .english:
            return "English"
        case .simplifiedChinese:
            return "中文"
        }
    }

    public var resolved: OTPilotLanguage {
        switch self {
        case .system:
            if Locale.preferredLanguages.first?.hasPrefix("zh") == true {
                return .simplifiedChinese
            }
            return .english
        case .english, .simplifiedChinese:
            return self
        }
    }
}

public enum OTPilotLocalizationKey: Sendable {
    case about
    case accessibility
    case accessibilityEnabledHelp
    case accessibilityMissingHelp
    case appBundleNotFound
    case autoPaste
    case autoPasteAfterCopy
    case copy
    case detectedCodes
    case detection
    case disabled
    case enabled
    case fullDiskAccess
    case fullDiskAccessRequired
    case idle
    case language
    case languageSystem
    case messagesDatabaseNotFound
    case monitoring
    case noCodeYet
    case noCodeSubtitle
    case notificationCopiedBody
    case notificationCopiedTitle
    case openAccessibility
    case openAtLogin
    case openFullDiskAccess
    case permissions
    case quit
    case reset
    case restoreClipboard
    case restoreClipboardAfterDelay
    case settings
    case settingsWindowTitle
    case start
    case startMonitoringOnLaunch
    case startup
    case stop
    case timePrefix
    case unknown
    case waitingForApproval
}

public enum OTPilotLocalization {
    public static func preferredLanguage(userDefaults: UserDefaults = .standard) -> OTPilotLanguage {
        guard let rawValue = userDefaults.string(forKey: OTPilotLanguage.defaultsKey),
              let language = OTPilotLanguage(rawValue: rawValue)
        else {
            return .system
        }

        return language
    }

    public static func currentString(_ key: OTPilotLocalizationKey, userDefaults: UserDefaults = .standard) -> String {
        string(key, language: preferredLanguage(userDefaults: userDefaults))
    }

    public static func string(_ key: OTPilotLocalizationKey, language: OTPilotLanguage = .system) -> String {
        switch language.resolved {
        case .system:
            return englishString(for: key)
        case .english:
            return englishString(for: key)
        case .simplifiedChinese:
            return simplifiedChineseString(for: key)
        }
    }

    private static func englishString(for key: OTPilotLocalizationKey) -> String {
        switch key {
        case .about:
            return "About"
        case .accessibility:
            return "Accessibility"
        case .accessibilityEnabledHelp:
            return "Accessibility is enabled"
        case .accessibilityMissingHelp:
            return "Accessibility permission is missing"
        case .appBundleNotFound:
            return "App bundle not found"
        case .autoPaste:
            return "Auto paste"
        case .autoPasteAfterCopy:
            return "Auto paste after copy"
        case .copy:
            return "Copy"
        case .detectedCodes:
            return "Detected codes"
        case .detection:
            return "Detection"
        case .disabled:
            return "Disabled"
        case .enabled:
            return "Enabled"
        case .fullDiskAccess:
            return "Full Disk Access"
        case .fullDiskAccessRequired:
            return "Full Disk Access required"
        case .idle:
            return "Idle"
        case .language:
            return "Language"
        case .languageSystem:
            return "System"
        case .messagesDatabaseNotFound:
            return "Messages database not found"
        case .monitoring:
            return "Monitoring"
        case .noCodeYet:
            return "No code yet"
        case .noCodeSubtitle:
            return "New SMS codes will appear here."
        case .notificationCopiedBody:
            return "A verification code is ready to paste."
        case .notificationCopiedTitle:
            return "OTP copied"
        case .openAccessibility:
            return "Open Accessibility"
        case .openAtLogin:
            return "Open OTPilot at login"
        case .openFullDiskAccess:
            return "Open Full Disk Access"
        case .permissions:
            return "Permissions"
        case .quit:
            return "Quit"
        case .reset:
            return "Reset"
        case .restoreClipboard:
            return "Restore clipboard"
        case .restoreClipboardAfterDelay:
            return "Restore previous clipboard after 45 seconds"
        case .settings:
            return "Settings"
        case .settingsWindowTitle:
            return "OTPilot Settings"
        case .start:
            return "Start"
        case .startMonitoringOnLaunch:
            return "Start monitoring when OTPilot opens"
        case .startup:
            return "Startup"
        case .stop:
            return "Stop"
        case .timePrefix:
            return "at"
        case .unknown:
            return "Unknown"
        case .waitingForApproval:
            return "Waiting for approval"
        }
    }

    private static func simplifiedChineseString(for key: OTPilotLocalizationKey) -> String {
        switch key {
        case .about:
            return "关于"
        case .accessibility:
            return "辅助功能"
        case .accessibilityEnabledHelp:
            return "辅助功能权限已开启"
        case .accessibilityMissingHelp:
            return "缺少辅助功能权限"
        case .appBundleNotFound:
            return "找不到应用包"
        case .autoPaste:
            return "自动粘贴"
        case .autoPasteAfterCopy:
            return "复制后自动粘贴"
        case .copy:
            return "复制"
        case .detectedCodes:
            return "已识别的验证码"
        case .detection:
            return "识别"
        case .disabled:
            return "已关闭"
        case .enabled:
            return "已开启"
        case .fullDiskAccess:
            return "完全磁盘访问权限"
        case .fullDiskAccessRequired:
            return "需要完全磁盘访问权限"
        case .idle:
            return "已暂停"
        case .language:
            return "语言"
        case .languageSystem:
            return "跟随系统"
        case .messagesDatabaseNotFound:
            return "找不到信息数据库"
        case .monitoring:
            return "正在监听"
        case .noCodeYet:
            return "还没有验证码"
        case .noCodeSubtitle:
            return "新的短信验证码会显示在这里。"
        case .notificationCopiedBody:
            return "验证码已准备好，可以粘贴。"
        case .notificationCopiedTitle:
            return "验证码已复制"
        case .openAccessibility:
            return "打开辅助功能"
        case .openAtLogin:
            return "登录时打开 OTPilot"
        case .openFullDiskAccess:
            return "打开完全磁盘访问权限"
        case .permissions:
            return "权限"
        case .quit:
            return "退出"
        case .reset:
            return "重置"
        case .restoreClipboard:
            return "恢复剪贴板"
        case .restoreClipboardAfterDelay:
            return "45 秒后恢复原剪贴板"
        case .settings:
            return "设置"
        case .settingsWindowTitle:
            return "OTPilot 设置"
        case .start:
            return "开始"
        case .startMonitoringOnLaunch:
            return "打开 OTPilot 时开始监听"
        case .startup:
            return "启动"
        case .stop:
            return "停止"
        case .timePrefix:
            return "于"
        case .unknown:
            return "未知"
        case .waitingForApproval:
            return "等待批准"
        }
    }
}
