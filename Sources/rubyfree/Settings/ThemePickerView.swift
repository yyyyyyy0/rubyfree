import SwiftUI
import RubyfreeCore

// MARK: - ThemePickerView

/// A Settings-window section to pick a theme preset (the same set as the menu's テーマ
/// submenu), placed above the custom-theme editor so the user can both switch presets and
/// use one as the base for a custom theme from one place. Drives `AppCoordinator.setTheme`.
struct ThemePickerView: View {

    let coordinator: AppCoordinator

    @State private var themeID: String = RubyTheme.default.id

    var body: some View {
        Section("テーマ") {
            Picker("プリセット", selection: $themeID) {
                ForEach(RubyTheme.allPresets, id: \.id) { preset in
                    Text(preset.name).tag(preset.id)
                }
                // Offer the saved custom theme as a selectable entry once one exists.
                if coordinator.currentCustomTheme != nil {
                    Text("カスタム").tag("custom")
                }
            }
            .onChange(of: themeID) { _, newID in
                coordinator.setTheme(id: newID)
            }
        }
        .onAppear { themeID = coordinator.currentThemeID }
    }
}
