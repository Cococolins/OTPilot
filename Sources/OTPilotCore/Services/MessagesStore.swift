import Foundation
import SQLite3

public final class MessagesStore: @unchecked Sendable {
    public enum StoreError: LocalizedError, Equatable {
        case databaseMissing
        case openFailed(String)
        case prepareFailed(String)

        public var errorDescription: String? {
            switch self {
            case .databaseMissing:
                return "Messages database not found."
            case .openFailed(let detail):
                return "Could not open Messages database: \(detail)"
            case .prepareFailed(let detail):
                return "Could not query Messages database: \(detail)"
            }
        }
    }

    public struct Message: Equatable, Sendable {
        public let rowID: Int64
        public let text: String
        public let sender: String
    }

    private let databaseURL: URL

    public init(databaseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Messages/chat.db")) {
        self.databaseURL = databaseURL
    }

    public var exists: Bool {
        FileManager.default.fileExists(atPath: databaseURL.path)
    }

    public func latestRowID() throws -> Int64 {
        guard exists else {
            throw StoreError.databaseMissing
        }

        return try withDatabase { db in
            var statement: OpaquePointer?
            let query = "SELECT COALESCE(MAX(ROWID), 0) FROM message"

            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.prepareFailed(lastError(from: db))
            }

            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return sqlite3_column_int64(statement, 0)
        }
    }

    public func incomingMessages(after rowID: Int64, limit: Int = 50) throws -> [Message] {
        guard exists else {
            throw StoreError.databaseMissing
        }

        return try withDatabase { db in
            let query = """
                SELECT
                    message.ROWID,
                    message.text,
                    COALESCE(handle.uncanonicalized_id, handle.id, 'Unknown') AS sender
                FROM message
                LEFT JOIN handle ON message.handle_id = handle.ROWID
                WHERE message.ROWID > ?
                    AND message.is_from_me = 0
                    AND message.text IS NOT NULL
                    AND message.text != ''
                    AND (message.associated_message_type IS NULL OR message.associated_message_type = 0)
                ORDER BY message.ROWID ASC
                LIMIT ?
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.prepareFailed(lastError(from: db))
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int64(statement, 1, rowID)
            sqlite3_bind_int(statement, 2, Int32(limit))

            var messages: [Message] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                let rowID = sqlite3_column_int64(statement, 0)
                let text = sqlite3_column_text(statement, 1).map { String(cString: $0) } ?? ""
                let sender = sqlite3_column_text(statement, 2).map { String(cString: $0) } ?? "Unknown"
                messages.append(Message(rowID: rowID, text: text, sender: sender))
            }

            return messages
        }
    }

    private func withDatabase<T>(_ body: (OpaquePointer?) throws -> T) throws -> T {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(databaseURL.path, &db, flags, nil) == SQLITE_OK else {
            let detail = db.map(lastError(from:)) ?? "unknown SQLite error"
            if let db {
                sqlite3_close(db)
            }
            throw StoreError.openFailed(detail)
        }

        defer { sqlite3_close(db) }
        return try body(db)
    }

    private func lastError(from db: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(db) else {
            return "unknown SQLite error"
        }
        return String(cString: message)
    }
}
