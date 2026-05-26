import AppKit
import Foundation

@MainActor
public final class ClipboardService: ObservableObject {
    private let pasteboard = NSPasteboard.general
    private var restoreTask: Task<Void, Never>?

    public init() {}

    public func copy(_ text: String, restorePreviousAfter seconds: TimeInterval?) {
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        restoreTask?.cancel()

        guard let seconds, let previousString, !previousString.isEmpty else {
            return
        }

        restoreTask = Task { [weak self] in
            let nanoseconds = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, self.pasteboard.string(forType: .string) == text else {
                    return
                }

                self.pasteboard.clearContents()
                self.pasteboard.setString(previousString, forType: .string)
            }
        }
    }
}
