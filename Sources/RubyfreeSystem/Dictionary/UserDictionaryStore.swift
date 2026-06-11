import Foundation
import RubyfreeCore

/// Errors from validating user-dictionary input.
public enum UserDictionaryError: Error, Equatable {
    case emptySurface
    case surfaceTooLong(max: Int)
    case surfaceHasControlChars
    case noValidReadings
    case readingTooLong(max: Int)
    case capacityExceeded(max: Int)
}

/// Persists a *user-authored* reading dictionary: surface → readings that the user
/// explicitly entered/saved to override or supplement the bundled dictionary.
///
/// Privacy boundary: this stores **only** what the user deliberately registers via the
/// settings UI. Captured text (AX/OCR results) is NEVER auto-registered or accumulated as
/// history — that would violate the project's non-persistence rule. A registered surface→
/// reading pair is a *preference value* (like the theme id), not captured content.
public protocol UserDictionaryStoring: AnyObject {
    /// Load the (sanitized) surface → readings map. Missing/unreadable file → empty.
    func load() -> [String: [String]]
    /// Add or overwrite an entry. Input is validated + sanitized (kana-normalised). Throws on
    /// invalid input or when the entry cap would be exceeded by a new surface.
    func add(surface: String, readings: [String]) throws
    /// Remove an entry; no-op when absent.
    func remove(surface: String)
    /// Number of stored entries.
    var count: Int { get }
}

/// File-backed `UserDictionaryStoring` writing a TSV (`surface\tread1,read2`) — the same
/// format as the bundled dictionary, so `ReadingDictionary.parseTSV` parses it directly.
public final class UserDictionaryStore: UserDictionaryStoring {

    /// Surface length cap, matched to `DictionaryAnalyzer.scanCap` (longer words are
    /// unreachable by the longest-match scan, so registering them is pointless).
    public static let maxSurfaceLength = 16
    public static let maxReadingLength = 32
    public static let maxEntries = 1000

    private let fileURL: URL

    /// - Parameter fileURL: storage location; defaults to
    ///   `~/Library/Application Support/rubyfree/user-dict.tsv`. Injectable for tests.
    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            self.fileURL = base
                .appendingPathComponent("rubyfree", isDirectory: true)
                .appendingPathComponent("user-dict.tsv")
        }
    }

    public func load() -> [String: [String]] {
        guard let body = try? String(contentsOf: fileURL, encoding: .utf8) else { return [:] }
        // Reuse the bundled-dictionary parser (skips malformed lines defensively).
        return ReadingDictionary.parseTSV(body)
    }

    public var count: Int { load().count }

    public func add(surface: String, readings: [String]) throws {
        let key = try Self.sanitizeSurface(surface)
        let values = try Self.sanitizeReadings(readings)
        var map = load()
        if map[key] == nil, map.count >= Self.maxEntries {
            throw UserDictionaryError.capacityExceeded(max: Self.maxEntries)
        }
        map[key] = values
        try persist(map)
    }

    public func remove(surface: String) {
        var map = load()
        guard map.removeValue(forKey: surface) != nil else { return }
        try? persist(map)
    }

    // MARK: - Validation / sanitization

    static func sanitizeSurface(_ raw: String) throws -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { throw UserDictionaryError.emptySurface }
        guard !s.contains("\t"), !s.contains(where: { $0.isNewline }) else {
            throw UserDictionaryError.surfaceHasControlChars
        }
        guard s.count <= maxSurfaceLength else {
            throw UserDictionaryError.surfaceTooLong(max: maxSurfaceLength)
        }
        return s
    }

    /// Trim, kana-normalise (katakana → hiragana), drop empties/duplicates, reject TSV
    /// delimiters; require at least one valid reading.
    static func sanitizeReadings(_ raw: [String]) throws -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for candidate in raw {
            let r = katakanaToHiragana(candidate.trimmingCharacters(in: .whitespacesAndNewlines))
            guard !r.isEmpty,
                  !r.contains("\t"), !r.contains(","), !r.contains(where: { $0.isNewline })
            else { continue }
            guard r.count <= maxReadingLength else {
                throw UserDictionaryError.readingTooLong(max: maxReadingLength)
            }
            if seen.insert(r).inserted { out.append(r) }
        }
        guard !out.isEmpty else { throw UserDictionaryError.noValidReadings }
        return out
    }

    /// Map full-width katakana (U+30A1…U+30F6) to the corresponding hiragana (offset −0x60).
    static func katakanaToHiragana(_ s: String) -> String {
        let scalars = s.unicodeScalars.map { scalar -> Unicode.Scalar in
            guard (0x30A1...0x30F6).contains(scalar.value),
                  let hira = Unicode.Scalar(scalar.value - 0x60) else { return scalar }
            return hira
        }
        return String(String.UnicodeScalarView(scalars))
    }

    // MARK: - Persistence

    private func persist(_ map: [String: [String]]) throws {
        // Deterministic order (sorted) so the file is stable/diff-friendly.
        let body = map.sorted { $0.key < $1.key }
            .map { "\($0.key)\t\($0.value.joined(separator: ","))" }
            .joined(separator: "\n") + "\n"
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(body.utf8).write(to: fileURL, options: .atomic)
    }
}
