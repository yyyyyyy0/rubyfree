import AppKit
import SwiftUI
import RubyfreeSystem

// MARK: - SettingsWindowController

/// Hosts a SwiftUI Form in a standard NSWindow for editing fontSize, maxReadings, and
/// settleDelay. Lives entirely in the `rubyfree` app target — no Core/System imports
/// at the call-site level (AppCoordinator is app-layer already).
///
/// The window is lazily created on first `showWindow()` call and re-used for subsequent
/// calls (single-instance, not singleton — the coordinator holds the reference).
///
/// Activation:  accessory (LSUIElement) apps aren't active by default, so the window
/// would open behind other windows without the explicit activate call. Uses the same
/// `NSApp.activate(ignoringOtherApps: true)` pattern as the About handler.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {

    // MARK: Stored properties

    private let coordinator: AppCoordinator
    private var window: NSWindow?

    // MARK: Init

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    // MARK: Public interface

    /// Show the settings window, creating it lazily on first call.
    func showWindow() {
        if window == nil {
            window = makeWindow()
        }
        // Bring the accessory app to the front before ordering the window front so
        // it does not open behind the currently active application.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Private helpers

    private func makeWindow() -> NSWindow {
        let view = SettingsFormView(coordinator: coordinator)
        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "rubyfree 設定"
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.contentView = hosting
        win.center()
        return win
    }

    // MARK: NSWindowDelegate

    /// When the window closes, nil it out so the next open re-creates a fresh one
    /// (and reads the current coordinator values again).
    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

// MARK: - SettingsFormView

/// SwiftUI Form for the three numeric settings. Uses `@State` seeded from the coordinator's
/// `current*` properties on appear; commits changes immediately via the coordinator setters
/// so the overlay updates live while the window is open.
///
/// All types are `Double` in the form layer (Slider/Stepper prefer it) and are converted at
/// the call boundary.
private struct SettingsFormView: View {

    let coordinator: AppCoordinator

    // Local state; initialised from coordinator in onAppear.
    @State private var fontSize: Double = Double(SettingsBounds.fontSizeDefault)
    @State private var maxReadings: Double = Double(SettingsBounds.maxReadingsDefault)
    @State private var settleDelay: Double = SettingsBounds.settleDelayDefault

    // Pre-computed ranges to avoid multi-line range literals in function calls.
    private static let fontSizeRange: ClosedRange<Double> =
        Double(SettingsBounds.fontSize.lowerBound)...Double(SettingsBounds.fontSize.upperBound)
    private static let maxReadingsRange: ClosedRange<Double> =
        Double(SettingsBounds.maxReadings.lowerBound)...Double(SettingsBounds.maxReadings.upperBound)
    private static let settleRange: ClosedRange<Double> =
        SettingsBounds.settleDelay.lowerBound...SettingsBounds.settleDelay.upperBound

    var body: some View {
        Form {
            fontSizeSection
            maxReadingsSection
            settleDelaySection
            CustomThemeEditorView(coordinator: coordinator)
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            fontSize     = Double(coordinator.currentFontSize)
            maxReadings  = Double(coordinator.currentMaxReadings)
            settleDelay  = coordinator.currentSettleDelay
        }
    }

    // MARK: Section views (extracted to help the type-checker)

    @ViewBuilder
    private var fontSizeSection: some View {
        Section {
            HStack {
                Text("文字サイズ")
                Spacer()
                Stepper(value: $fontSize, in: Self.fontSizeRange, step: 1) {
                    Text("\(Int(fontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
                .onChange(of: fontSize) { commitFontSize() }
            }
            Slider(value: $fontSize, in: Self.fontSizeRange, step: 1)
                .onChange(of: fontSize) { commitFontSize() }
        }
    }

    @ViewBuilder
    private var maxReadingsSection: some View {
        Section {
            HStack {
                Text("ルビ候補数")
                Spacer()
                Stepper(value: $maxReadings, in: Self.maxReadingsRange, step: 1) {
                    Text("\(Int(maxReadings))")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
                .onChange(of: maxReadings) { commitMaxReadings() }
            }
        }
    }

    @ViewBuilder
    private var settleDelaySection: some View {
        Section {
            HStack {
                Text("反応の速さ")
                Spacer()
                Text(settleDelayLabel)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settleDelay, in: Self.settleRange)
                .onChange(of: settleDelay) { commitSettleDelay() }
        }
    }

    // MARK: Commit helpers (drive coordinator on every change)

    private func commitFontSize() {
        coordinator.setFontSize(Int(fontSize))
    }

    private func commitMaxReadings() {
        coordinator.setMaxReadings(Int(maxReadings))
    }

    private func commitSettleDelay() {
        coordinator.setSettleDelay(settleDelay)
    }

    // MARK: Settle-delay label

    private var settleDelayLabel: String {
        switch settleDelay {
        case ..<0.25: return "速い"
        case 0.25..<0.50: return "標準"
        default: return "ゆっくり"
        }
    }
}
