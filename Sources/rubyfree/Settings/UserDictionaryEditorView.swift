import SwiftUI
import RubyfreeSystem

// MARK: - UserDictionaryEditorView

/// A Settings-window section for editing the user dictionary (registered readings for proper
/// nouns / corrections). All persistence and the live analyzer re-merge are routed through
/// `AppCoordinator`, so this view only needs the coordinator — keeping it decoupled from the
/// store and parallel to the other settings sections.
///
/// Privacy: entries are created **only** by the user's explicit add action here; captured
/// text is never auto-registered (see README / PRIVACY).
struct UserDictionaryEditorView: View {

    let coordinator: AppCoordinator

    @State private var entries: [Entry] = []
    @State private var newSurface = ""
    @State private var newReadings = ""
    @State private var errorMessage: String?

    /// Identifiable wrapper so `ForEach` can key on the surface.
    private struct Entry: Identifiable {
        let surface: String
        let readings: [String]
        var id: String { surface }
    }

    var body: some View {
        Section("ユーザー辞書") {
            if entries.isEmpty {
                Text("登録された読みはありません")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                HStack {
                    Text(entry.surface)
                    Spacer()
                    Text(entry.readings.joined(separator: "／"))
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        coordinator.removeUserReading(surface: entry.surface)
                        reload()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            // Add row.
            HStack {
                TextField("語", text: $newSurface)
                    .frame(width: 90)
                TextField("読み（／や , で区切り）", text: $newReadings)
                Button("追加", action: add)
                    .disabled(newSurface.trimmingCharacters(in: .whitespaces).isEmpty
                              || newReadings.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onAppear(perform: reload)
    }

    // MARK: - Actions

    private func reload() {
        entries = coordinator.userDictionaryEntries().map { Entry(surface: $0.surface, readings: $0.readings) }
    }

    private func add() {
        let readings = newReadings
            .split(whereSeparator: { $0 == "／" || $0 == "/" || $0 == "," || $0 == "、" || $0 == " " })
            .map(String.init)
        do {
            try coordinator.addUserReading(surface: newSurface, readings: readings)
            newSurface = ""
            newReadings = ""
            errorMessage = nil
            reload()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        guard let e = error as? UserDictionaryError else { return "登録できませんでした" }
        switch e {
        case .emptySurface: return "語を入力してください"
        case .surfaceTooLong(let max): return "語は \(max) 文字以内にしてください"
        case .surfaceHasControlChars: return "語にタブ・改行は使えません"
        case .noValidReadings: return "読みを入力してください（ひらがな/カタカナ）"
        case .readingTooLong(let max): return "読みは \(max) 文字以内にしてください"
        case .capacityExceeded(let max): return "登録できる上限（\(max) 件）に達しています"
        }
    }
}
