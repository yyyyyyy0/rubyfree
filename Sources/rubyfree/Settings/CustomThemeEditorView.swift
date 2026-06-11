import AppKit
import SwiftUI
import RubyfreeCore

// MARK: - CustomThemeEditorView

/// SwiftUI section view for editing the five overlay colours and the chip background
/// opacity. Designed to be embedded as one `Section` inside `SettingsFormView`; all
/// coordinator interaction is done through the shared `AppCoordinator` reference.
///
/// Edit flow:
///  1. On appear the buffers are seeded from the coordinator's `currentCustomTheme`
///     (or the active preset when no custom theme exists yet) so the user always
///     starts from something sensible.
///  2. "保存" writes the custom theme and sets `themeID = "custom"`; changes take effect on
///     save (not as a live preview) — the next hover renders in the saved colours.
///  3. "リセット" discards buffer state (does not delete the saved custom theme;
///     closing without saving also leaves the persisted value untouched).
///
/// Opacity handling: The RGB of `chipBackground` is held separately from its alpha;
/// the alpha component is driven by the `opacity` slider. They are merged into one
/// CGColor only when composing the ``RubyTheme`` for preview / save — matching the
/// spec ("Opacity slider value composited into chipBackgroundColor alpha").
@MainActor
struct CustomThemeEditorView: View {

    let coordinator: AppCoordinator

    // Colour edit buffers — all in sRGB via Color(cgColor:).
    @State private var foreground:   Color = .white
    @State private var ruby:         Color = Color(red: 1.0, green: 0.82, blue: 0.30)
    @State private var uncertain:    Color = Color(red: 0.70, green: 0.62, blue: 0.40)
    @State private var chipBgRGB:    Color = .black   // RGB only; alpha controlled by slider
    @State private var chipStroke:   Color = Color(white: 1.0).opacity(0.18)
    @State private var opacity:      Double = 0.92    // chip background alpha (0…1)
    /// Transient "保存しました" confirmation, shown briefly after a save.
    @State private var justSaved = false

    var body: some View {
        Section("カスタムテーマ") {
            ColorPicker("本文カラー",        selection: $foreground, supportsOpacity: false)
            ColorPicker("ルビカラー",         selection: $ruby,       supportsOpacity: false)
            ColorPicker("不確実ルビカラー",   selection: $uncertain,  supportsOpacity: false)
            ColorPicker("チップ背景カラー",   selection: $chipBgRGB,  supportsOpacity: false)
            ColorPicker("チップ枠カラー",     selection: $chipStroke, supportsOpacity: true)

            HStack {
                Text("背景の不透明度")
                Spacer()
                Text("\(Int(opacity * 100)) %")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            Slider(value: $opacity, in: 0.05...1.0, step: 0.01)

            HStack {
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                Button("リセット") { seedFromCoordinator() }
                Spacer()
                if justSaved {
                    Label("保存しました", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                        .transition(.opacity)
                }
            }
            Text("保存するとメニューの「テーマ」が「カスタム」に切り替わり、次のホバーから反映されます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { seedFromCoordinator() }
    }

    // MARK: - Helpers

    /// Seed all buffers from the coordinator: use the saved custom theme if one exists,
    /// otherwise fall back to the currently active preset so the starting point looks familiar.
    private func seedFromCoordinator() {
        let base: RubyTheme
        if let custom = coordinator.currentCustomTheme {
            base = custom
        } else {
            // Derive from the active preset (use the dark defaults if resolution gives default).
            base = RubyTheme.preset(id: coordinator.currentThemeID)
        }
        foreground = color(from: base.foregroundColor)
        ruby       = color(from: base.rubyColor)
        uncertain  = color(from: base.uncertainColor)

        // Chip background: split RGB and alpha so the slider is independent.
        let bgNS   = NSColor(cgColor: base.chipBackgroundColor)?.usingColorSpace(.sRGB)
        chipBgRGB  = color(from: base.chipBackgroundColor, forceOpaqueRGB: true)
        opacity    = Double(bgNS?.alphaComponent ?? 0.92)

        chipStroke = color(from: base.chipStrokeColor)
    }

    /// Compose the current buffer state into a ``RubyTheme`` and save it via the coordinator,
    /// then flash a confirmation so the user knows it took (there is no live preview).
    private func save() {
        coordinator.setCustomTheme(buildTheme())
        withAnimation { justSaved = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation { justSaved = false }
        }
    }

    /// Build a ``RubyTheme`` from the current buffers. Chip background merges the RGB colour
    /// with the opacity slider value into a single CGColor (the stored RGBA hex).
    private func buildTheme() -> RubyTheme {
        RubyTheme(
            id: "custom",
            name: "カスタム",
            foregroundColor: cgColor(from: foreground),
            rubyColor:       cgColor(from: ruby),
            uncertainColor:  cgColor(from: uncertain),
            chipBackgroundColor: cgColorWithAlpha(from: chipBgRGB, alpha: opacity),
            chipStrokeColor: cgColor(from: chipStroke)
        )
    }

    // MARK: - Color conversion

    /// `SwiftUI.Color` → `CGColor` in sRGB. Falls back to opaque black on conversion failure.
    private func cgColor(from swiftColor: Color) -> CGColor {
        let ns = NSColor(swiftColor).usingColorSpace(.sRGB) ?? NSColor.black
        return CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [ns.redComponent, ns.greenComponent, ns.blueComponent, ns.alphaComponent]
        ) ?? CGColor(gray: 0, alpha: 1)
    }

    /// Build a CGColor using the RGB of `swiftColor` but substituting `alpha`.
    private func cgColorWithAlpha(from swiftColor: Color, alpha: Double) -> CGColor {
        let ns = NSColor(swiftColor).usingColorSpace(.sRGB) ?? NSColor.black
        let a  = min(max(alpha, 0), 1)
        return CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [ns.redComponent, ns.greenComponent, ns.blueComponent, a]
        ) ?? CGColor(gray: 0, alpha: CGFloat(a))
    }

    /// `CGColor` → `SwiftUI.Color`. When `forceOpaqueRGB` is true the alpha is set to 1 so
    /// the colour picker shows the RGB without the existing alpha (opacity is in the slider).
    private func color(from cgColor: CGColor, forceOpaqueRGB: Bool = false) -> Color {
        guard
            let ns   = NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB)
        else { return .black }
        let alpha = forceOpaqueRGB ? 1.0 : Double(ns.alphaComponent)
        return Color(
            red:     Double(ns.redComponent),
            green:   Double(ns.greenComponent),
            blue:    Double(ns.blueComponent),
            opacity: alpha
        )
    }
}
