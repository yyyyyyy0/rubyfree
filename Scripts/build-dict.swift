#!/usr/bin/env swift
import Foundation

// build-dict.swift — generate rubyfree's bundled reading dictionary.
//
// Input  (downloaded once, offline — see Scripts/fetch-dict-sources.sh):
//   - JMdict_e   (XML) : word-level entries, kanji surface (keb) → kana readings (reb)
//   - kanjidic2  (XML) : per-character on/kun readings (single-kanji fallback)
// Output (committed, bundled as RubyfreeCore resources):
//   - words.tsv  : "surface\tread1,read2,..."  (hiragana; word-level, treated as certain)
//   - kanji.tsv  : "字\tread1,read2,..."        (hiragana; per-char fallback, uncertain)
//
// Everything here runs locally on already-downloaded files; the generator itself does
// no networking. Readings are normalised to hiragana and de-duplicated, primary first.
//
// Usage: swift Scripts/build-dict.swift <JMdict_e.xml> <kanjidic2.xml> <out-dir>

// MARK: - Helpers

/// Katakana → hiragana, and trim kanjidic kun markers (`.` okurigana split, `-` affix).
func toHiragana(_ s: String) -> String {
    let kana = s.applyingTransform(StringTransform("Katakana-Hiragana"), reverse: false) ?? s
    // kanjidic kun readings look like "おく.る" / "-づけ"; keep the stem before the dot,
    // drop leading/trailing affix hyphens.
    let stem = kana.split(separator: ".").first.map(String.init) ?? kana
    return stem.replacingOccurrences(of: "-", with: "")
}

/// True if the string contains at least one CJK ideograph.
func containsKanji(_ s: String) -> Bool {
    s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }
}

/// Pure hiragana check (so we never emit katakana/latin noise as a "reading").
func isHiragana(_ s: String) -> Bool {
    !s.isEmpty && s.unicodeScalars.allSatisfy { (0x3041...0x3096).contains($0.value) || $0.value == 0x30FC /* ー */ }
}

func appendUnique(_ value: String, to list: inout [String], seen: inout Set<String>) {
    guard !value.isEmpty, !seen.contains(value) else { return }
    seen.insert(value)
    list.append(value)
}

// MARK: - JMdict parser (keb → [reb])

/// Collects, per <entry>, the kanji surfaces and their readings, honouring <re_restr>
/// (a reading that lists restrictions applies only to those kanji surfaces).
final class JMDictParser: NSObject, XMLParserDelegate {
    private(set) var surfaceToReadings: [String: [String]] = [:]
    private var seenPerSurface: [String: Set<String>] = [:]

    // Current <entry> accumulation.
    private var kebs: [String] = []
    private var rebs: [(kana: String, restr: [String])] = []
    private var currentReb: String = ""
    private var currentRestr: [String] = []
    private var text = ""
    private var inReb = false

    func parser(_ p: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName q: String?, attributes: [String: String]) {
        text = ""
        switch el {
        case "entry": kebs = []; rebs = []
        case "r_ele": currentReb = ""; currentRestr = []; inReb = true
        default: break
        }
    }

    func parser(_ p: XMLParser, foundCharacters s: String) { text += s }

    func parser(_ p: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName q: String?) {
        switch el {
        case "keb":
            let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { kebs.append(v) }
        case "reb" where inReb:
            currentReb = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case "re_restr" where inReb:
            let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { currentRestr.append(v) }
        case "r_ele":
            rebs.append((currentReb, currentRestr)); inReb = false
        case "entry":
            flushEntry()
        default: break
        }
        text = ""
    }

    private func flushEntry() {
        // Only kanji-bearing surfaces need furigana.
        for keb in kebs where containsKanji(keb) {
            for reb in rebs {
                // Respect re_restr: a restricted reading attaches only to listed surfaces.
                if !reb.restr.isEmpty && !reb.restr.contains(keb) { continue }
                let hira = toHiragana(reb.kana)
                guard isHiragana(hira) else { continue }
                var list = surfaceToReadings[keb] ?? []
                var seen = seenPerSurface[keb] ?? []
                appendUnique(hira, to: &list, seen: &seen)
                surfaceToReadings[keb] = list
                seenPerSurface[keb] = seen
            }
        }
    }
}

// MARK: - kanjidic2 parser (字 → [on/kun])

final class KanjiDicParser: NSObject, XMLParserDelegate {
    private(set) var charToReadings: [String: [String]] = [:]
    private var seenPerChar: [String: Set<String>] = [:]

    private var literal = ""
    private var readings: [String] = []
    private var seen: Set<String> = []
    private var text = ""
    private var rType: String?

    func parser(_ p: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName q: String?, attributes: [String: String]) {
        text = ""
        switch el {
        case "character": literal = ""; readings = []; seen = []
        case "reading": rType = attributes["r_type"]
        default: break
        }
    }

    func parser(_ p: XMLParser, foundCharacters s: String) { text += s }

    func parser(_ p: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName q: String?) {
        switch el {
        case "literal":
            literal = text.trimmingCharacters(in: .whitespacesAndNewlines)
        case "reading":
            // ja_on (katakana) and ja_kun (hiragana with okurigana markers) only.
            if rType == "ja_on" || rType == "ja_kun" {
                let hira = toHiragana(text.trimmingCharacters(in: .whitespacesAndNewlines))
                if isHiragana(hira) { appendUnique(hira, to: &readings, seen: &seen) }
            }
            rType = nil
        case "character":
            if !literal.isEmpty, containsKanji(literal), !readings.isEmpty {
                charToReadings[literal] = readings
            }
        default: break
        }
        text = ""
    }
}

// MARK: - Driver

let args = CommandLine.arguments
guard args.count == 4 else {
    FileHandle.standardError.write(Data("usage: swift build-dict.swift <JMdict_e.xml> <kanjidic2.xml> <out-dir>\n".utf8))
    exit(2)
}
let jmdictURL = URL(fileURLWithPath: args[1])
let kanjidicURL = URL(fileURLWithPath: args[2])
let outDir = URL(fileURLWithPath: args[3], isDirectory: true)

func parse<T: XMLParserDelegate>(_ url: URL, with delegate: T) throws {
    guard let parser = XMLParser(contentsOf: url) else {
        throw NSError(domain: "build-dict", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot open \(url.path)"])
    }
    parser.delegate = delegate
    parser.shouldResolveExternalEntities = false
    guard parser.parse() else {
        throw parser.parserError ?? NSError(domain: "build-dict", code: 2)
    }
}

let cap = 6  // max readings per entry — keeps the ruby gloss legible and the file small.

func writeTSV(_ map: [String: [String]], to url: URL) throws {
    // The TSV uses '\t' as the field separator and ',' as the reading separator with no
    // escaping. JMdict/kanjidic surfaces never contain these, but guard the contract
    // explicitly so a malformed source row can't corrupt the runtime parser's framing.
    func clean(_ s: String) -> Bool { !s.contains("\t") && !s.contains(",") && !s.contains("\n") }

    var lines: [String] = []
    lines.reserveCapacity(map.count)
    for key in map.keys.sorted() {
        guard clean(key) else { continue }
        let readings = map[key]!.filter(clean).prefix(cap)
        guard !readings.isEmpty else { continue }
        lines.append("\(key)\t\(readings.joined(separator: ","))")
    }
    try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    FileHandle.standardError.write(Data("wrote \(map.count) entries → \(url.lastPathComponent)\n".utf8))
}

do {
    let jm = JMDictParser()
    try parse(jmdictURL, with: jm)
    let kd = KanjiDicParser()
    try parse(kanjidicURL, with: kd)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    try writeTSV(jm.surfaceToReadings, to: outDir.appendingPathComponent("words.tsv"))
    try writeTSV(kd.charToReadings, to: outDir.appendingPathComponent("kanji.tsv"))
} catch {
    FileHandle.standardError.write(Data("ERROR: \(error.localizedDescription)\n".utf8))
    exit(1)
}
