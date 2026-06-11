import Foundation

/// Lightweight stderr logger, gated by the `RUBYFREE_DEBUG` environment variable.
///
/// Diagnostics only — emits nothing unless `RUBYFREE_DEBUG` is set, so it is safe
/// to leave the call sites in place. Never logs captured user text content; only
/// pipeline events, lengths, and geometry are reported (privacy requirement).
public enum DebugLog {
    public static let enabled = ProcessInfo.processInfo.environment["RUBYFREE_DEBUG"] != nil

    public static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        FileHandle.standardError.write(Data("[rubyfree] \(message())\n".utf8))
    }
}
