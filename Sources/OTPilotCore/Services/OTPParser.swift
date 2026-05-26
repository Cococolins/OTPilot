import Foundation

public struct OTPParser {
    private let keywordPattern: NSRegularExpression
    private let candidatePatterns: [NSRegularExpression]
    private let blockedWords: Set<String>
    private let keywordDistanceThreshold = 30

    public init() {
        keywordPattern = try! NSRegularExpression(
            pattern: #"(?i)(?:\b(code|verification|verify|passcode|otp|pin|security|login|sign[\s-]?in|auth|authentication|confirm|2fa|mfa|one[-\s]?time)\b|验证码|驗證碼|校验码|校驗碼|动态码|動態碼|安全码|安全碼|驗證|验证|校验|校驗|短信登录|短信登入|登录|登入|登錄|登陆|免密|一次性|動態密碼|动态密码)"#,
            options: [.caseInsensitive]
        )
        candidatePatterns = [
            #"(?<![A-Za-z0-9])[0-9]{3}[- ][0-9]{3}(?![A-Za-z0-9])"#,
            #"(?<![A-Za-z0-9])[0-9]{4,8}(?![A-Za-z0-9])"#,
            #"(?<![A-Za-z0-9])[A-Za-z0-9]{4,8}(?![A-Za-z0-9])"#
        ].compactMap {
            try? NSRegularExpression(pattern: $0, options: [.caseInsensitive])
        }
        blockedWords = [
            "code", "login", "signin", "verify", "otp", "pin", "auth", "security",
            "apple", "google", "amazon", "microsoft", "wechat", "alipay"
        ]
    }

    public func extract(from message: String) -> String? {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywordRanges = keywordMatches(in: cleanMessage)
        guard !cleanMessage.isEmpty, !keywordRanges.isEmpty else {
            return nil
        }

        return rankedCandidates(in: cleanMessage, near: keywordRanges).first?.code
    }

    private func keywordMatches(in text: String) -> [NSRange] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return keywordPattern.matches(in: text, range: nsRange).map(\.range)
    }

    private func normalize(_ candidate: String) -> String {
        candidate
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
            .uppercased()
    }

    private struct Candidate {
        let code: String
        let rank: Int
        let distance: Int
    }

    private func rankedCandidates(in message: String, near keywordRanges: [NSRange]) -> [Candidate] {
        let nsRange = NSRange(message.startIndex..<message.endIndex, in: message)
        var seenCodes = Set<String>()
        var candidates: [Candidate] = []

        for pattern in candidatePatterns {
            let matches = pattern.matches(in: message, range: nsRange)
            for match in matches {
                guard let range = Range(match.range, in: message) else {
                    continue
                }

                let rawCode = String(message[range])
                let code = normalize(rawCode)
                guard !seenCodes.contains(code), isLikelyCode(code, rawCode: rawCode, range: match.range, in: message) else {
                    continue
                }

                let distance = distanceToNearestKeyword(match.range, keywordRanges: keywordRanges)
                guard distance <= keywordDistanceThreshold else {
                    continue
                }

                seenCodes.insert(code)
                candidates.append(Candidate(code: code, rank: matchRank(for: code), distance: distance))
            }
        }

        return candidates.sorted {
            if $0.rank != $1.rank {
                return $0.rank > $1.rank
            }
            return $0.distance < $1.distance
        }
    }

    private func isLikelyCode(_ candidate: String, in message: String) -> Bool {
        isLikelyCode(candidate, rawCode: candidate, range: nil, in: message)
    }

    private func isLikelyCode(_ code: String, rawCode: String, range: NSRange?, in message: String) -> Bool {
        let code = normalize(code)

        guard (4...8).contains(code.count) else {
            return false
        }

        guard code.range(of: #"^[A-Z0-9]+$"#, options: .regularExpression) != nil else {
            return false
        }

        guard code.contains(where: \.isNumber) else {
            return false
        }

        if blockedWords.contains(code.lowercased()) {
            return false
        }

        if Set(code).count == 1 {
            return false
        }

        if ["0000", "1111", "2222", "3333", "4444", "5555", "6666", "7777", "8888", "9999"].contains(code) {
            return false
        }

        if let range, isLikelyDateTimeToken(range: range, in: message) {
            return false
        }

        if let range, isLikelyURLToken(range: range, in: message) {
            return false
        }

        if looksLikePhoneFragment(code, in: message) {
            return false
        }

        return true
    }

    private func looksLikePhoneFragment(_ code: String, in message: String) -> Bool {
        guard code.allSatisfy(\.isNumber), code.count <= 4 else {
            return false
        }

        return message.contains("***-\(code)") || message.contains("****\(code)")
    }

    private func matchRank(for code: String) -> Int {
        if code.range(of: #"^[0-9]{6}$"#, options: .regularExpression) != nil {
            return 4
        }

        if code.range(of: #"^[0-9]{4}$"#, options: .regularExpression) != nil {
            return 3
        }

        if code.allSatisfy(\.isNumber) {
            return 2
        }

        return 1
    }

    private func distanceToNearestKeyword(_ range: NSRange, keywordRanges: [NSRange]) -> Int {
        keywordRanges.map { keywordRange in
            if NSIntersectionRange(range, keywordRange).length > 0 {
                return 0
            }

            if range.location < keywordRange.location {
                return keywordRange.location - NSMaxRange(range)
            }

            return range.location - NSMaxRange(keywordRange)
        }
        .min() ?? Int.max
    }

    private func isLikelyDateTimeToken(range: NSRange, in message: String) -> Bool {
        guard let swiftRange = Range(range, in: message) else {
            return false
        }

        let token = String(message[swiftRange])
        guard token.allSatisfy(\.isNumber) else {
            return false
        }

        let previous = swiftRange.lowerBound > message.startIndex ? message[message.index(before: swiftRange.lowerBound)] : nil
        let next = swiftRange.upperBound < message.endIndex ? message[swiftRange.upperBound] : nil
        let dateUnits: Set<Character> = ["年", "月", "日", "号", "號", "时", "時", "点", "點", "分", "秒"]
        return previous.map { dateUnits.contains($0) } == true || next.map { dateUnits.contains($0) } == true
    }

    private func isLikelyURLToken(range: NSRange, in message: String) -> Bool {
        guard let swiftRange = Range(range, in: message) else {
            return false
        }

        let previous = swiftRange.lowerBound > message.startIndex ? message[message.index(before: swiftRange.lowerBound)] : nil
        let next = swiftRange.upperBound < message.endIndex ? message[swiftRange.upperBound] : nil
        let urlCharacters: Set<Character> = ["/", ":", "?", "&", "=", "#", "%"]
        if previous.map({ urlCharacters.contains($0) }) == true || next.map({ urlCharacters.contains($0) }) == true {
            return true
        }

        let contextStart = message.index(swiftRange.lowerBound, offsetBy: -8, limitedBy: message.startIndex) ?? message.startIndex
        let contextEnd = message.index(swiftRange.upperBound, offsetBy: 8, limitedBy: message.endIndex) ?? message.endIndex
        let context = message[contextStart..<contextEnd].lowercased()
        return context.contains("http://") || context.contains("https://") || context.contains("www.")
    }
}
