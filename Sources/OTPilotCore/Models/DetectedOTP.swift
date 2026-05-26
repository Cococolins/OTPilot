import Foundation

public struct DetectedOTP: Equatable, Sendable {
    public let code: String
    public let sender: String
    public let rowID: Int64
    public let detectedAt: Date

    public init(code: String, sender: String, rowID: Int64, detectedAt: Date = Date()) {
        self.code = code
        self.sender = sender
        self.rowID = rowID
        self.detectedAt = detectedAt
    }
}
