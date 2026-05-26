import Foundation

public enum MonitorState: Equatable, Sendable {
    case idle
    case monitoring
    case missingMessagesDatabase
    case fullDiskAccessRequired
    case databaseError(String)

    public var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .monitoring:
            return "Monitoring"
        case .missingMessagesDatabase:
            return "Messages database not found"
        case .fullDiskAccessRequired:
            return "Full Disk Access required"
        case .databaseError(let message):
            return message
        }
    }
}
