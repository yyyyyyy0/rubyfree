import CoreGraphics
import Foundation
import RubyfreeCore
import RubyfreeSystem

/// Composition root and single source of truth. Runs entirely on the main actor.
///
/// Pipeline: mouse move → HoverReducer (settle detection) → hoverSettled → capture
/// (async, AX-or-fake) → analyze → compose → build attributed → overlay show.
///
/// `generation` is the shared staleness primitive: it is bumped on every settle, and a
/// capture result or a settle-timer that doesn't match the current generation is dropped,
/// so a late async result can never resurrect stale UI.
@MainActor
final class AppCoordinator {
    private let monitor: any GlobalMouseMonitoring
    private let capture: any TextCapturing
    private let secureDetector: any SecureFieldDetecting
    private let analyzer: any JapaneseAnalyzing
    private let composer: RubyComposer
    private let builder: RubyAttributedBuilder
    private let overlay: any OverlayPresenting
    private let permissions: any PermissionChecking
    private let settings: any SettingsStoring

    private let hover: HoverReducer
    private let stateReducer: AppStateReducer
    private var settleDelay: TimeInterval
    private let permissionPollInterval: TimeInterval

    private var hoverState = HoverState()
    private var appState: AppState = .disabled
    private var generation = 0

    /// The active colour palette and the ``RubyStyle`` derived from it. Loaded from settings
    /// on `start()`; changed via `setTheme(id:)`.
    private var theme: RubyTheme = .default
    private var style: RubyStyle = RubyTheme.default.makeStyle()
    private var settleTimer: Timer?
    private var permissionTimer: Timer?
    private var captureTask: Task<Void, Never>?

    /// Invoked on the main actor after any state change that the UI cares about (enable
    /// toggle, permission gain/loss) so the menu / status item can refresh.
    var onStateChange: (@MainActor () -> Void)?

    init(
        monitor: any GlobalMouseMonitoring,
        capture: any TextCapturing,
        secureDetector: any SecureFieldDetecting,
        analyzer: any JapaneseAnalyzing,
        composer: RubyComposer = RubyComposer(),
        builder: RubyAttributedBuilder = RubyAttributedBuilder(),
        overlay: any OverlayPresenting,
        permissions: any PermissionChecking,
        settings: any SettingsStoring,
        settleDelay: TimeInterval = 0.35,
        minMovement: CGFloat = 4,
        permissionPollInterval: TimeInterval = 2.0
    ) {
        self.monitor = monitor
        self.capture = capture
        self.secureDetector = secureDetector
        self.analyzer = analyzer
        self.composer = composer
        self.builder = builder
        self.overlay = overlay
        self.permissions = permissions
        self.settings = settings
        self.hover = HoverReducer(minMovement: minMovement)
        self.stateReducer = AppStateReducer()
        self.settleDelay = settleDelay
        self.permissionPollInterval = permissionPollInterval
    }

    // MARK: - Lifecycle / enablement

    /// True unless the user has explicitly turned rubyfree off.
    var isEnabled: Bool {
        if case .disabled = appState { return false }
        return true
    }

    /// Current permission snapshot (for the menu).
    func currentPermissions() -> PermissionStatus { permissions.current() }

    func start() {
        monitor.onMove = { [weak self] point in self?.handleMoved(point) }
        // Restore persisted display/behaviour settings before any overlay is shown, then the
        // on/off preference. Finally start watching for permission changes (grants/revocations)
        // even while disabled so the menu stays accurate.
        settleDelay = settings.settleDelay
        applyTheme(resolveTheme(id: settings.themeID), persist: false)
        setEnabled(settings.isEnabled)
        startPermissionPolling()
    }

    // MARK: - Theme / display settings

    /// Identifier of the active theme (for the menu's radio selection).
    var currentThemeID: String { theme.id }
    /// Current display/behaviour settings (for the menu's radio selection).
    var currentFontSize: Int { settings.fontSize }
    var currentMaxReadings: Int { settings.maxReadings }
    var currentSettleDelay: Double { settings.settleDelay }
    /// The persisted custom theme, if any. Used by the editor to seed initial values.
    var currentCustomTheme: RubyTheme? { settings.customTheme }

    /// Switch to the theme with `id`. For `id == "custom"` the persisted custom theme is
    /// applied (falling back to default when none exists yet). Unknown ids fall back to default.
    func setTheme(id: String) {
        applyTheme(resolveTheme(id: id), persist: true)
    }

    /// Save a new custom theme, activate it immediately, and persist `themeID = "custom"`.
    func setCustomTheme(_ custom: RubyTheme) {
        settings.customTheme = custom
        // Build the canonical custom instance with id="custom" so currentThemeID returns the
        // right string and the menu radio ticks correctly.
        let resolved = RubyTheme(
            id: "custom", name: "カスタム",
            foregroundColor: custom.foregroundColor,
            rubyColor: custom.rubyColor,
            uncertainColor: custom.uncertainColor,
            chipBackgroundColor: custom.chipBackgroundColor,
            chipStrokeColor: custom.chipStrokeColor
        )
        applyTheme(resolved, persist: true)
        onStateChange?()  // rebuild menu (カスタム item may appear for first time)
    }

    /// Resolve a theme id to a concrete ``RubyTheme``. `"custom"` resolves to the persisted
    /// custom theme (or default when none exists). All other ids go through `preset(id:)`.
    private func resolveTheme(id: String) -> RubyTheme {
        if id == "custom" {
            return settings.customTheme ?? .default
        }
        return RubyTheme.preset(id: id)
    }

    /// Persist a new base font size and rebuild the style so the next hover uses it.
    func setFontSize(_ points: Int) {
        settings.fontSize = points
        rebuildStyle()
        overlay.hide()
        onStateChange?()
    }

    /// Persist a new max-readings cap and rebuild the style.
    func setMaxReadings(_ count: Int) {
        settings.maxReadings = count
        rebuildStyle()
        overlay.hide()
        onStateChange?()
    }

    /// Persist a new hover-settle delay. Picked up on the next `armSettleTimer` (live).
    func setSettleDelay(_ seconds: Double) {
        settings.settleDelay = seconds
        settleDelay = settings.settleDelay
        onStateChange?()
    }

    /// Set the active theme: derive the body ``RubyStyle``, push chip colours to the overlay,
    /// optionally persist the choice, and notify the UI so the menu refreshes its selection.
    private func applyTheme(_ newTheme: RubyTheme, persist: Bool) {
        theme = newTheme
        rebuildStyle()
        if persist { settings.themeID = newTheme.id }
        overlay.applyTheme(newTheme)
        // Clear any chip currently on screen so we never show a half-themed overlay: chip
        // colours apply immediately but the body text colours are baked into the attributed
        // string and only update on the next capture. Hiding keeps the appearance consistent
        // — the next hover re-renders fully in the new theme. (No-op when nothing is shown.)
        overlay.hide()
        onStateChange?()
    }

    /// Rebuild ``style`` from the active theme and the persisted font/readings settings.
    /// Pushes the new style to the overlay so it can update the ruby headroom (`vPadTop`)
    /// before the next chip is shown. Callers hide the overlay and notify as appropriate.
    private func rebuildStyle() {
        style = theme.makeStyle(fontSize: CGFloat(settings.fontSize), maxReadings: settings.maxReadings)
        overlay.updateStyle(style)
    }

    /// Turn hovering on/off. Persists the preference, drives the state machine, and
    /// releases or re-acquires the mouse monitor accordingly.
    func setEnabled(_ enabled: Bool) {
        settings.isEnabled = enabled
        appState = stateReducer.reduce(appState, .setEnabled(enabled))
        if enabled {
            // Re-evaluate permissions on enable so we land in idle vs needsPermission.
            appState = stateReducer.reduce(appState, .permissionsChanged(permissions.current()))
        }
        syncMonitoring()
        onStateChange?()
    }

    /// Bring the running monitor / overlay in line with `appState`: active states keep the
    /// monitor running; `.disabled` / `.needsPermission` release it (CPU quiet) and clear
    /// any visible chip.
    private func syncMonitoring() {
        switch appState {
        case .idle, .capturing, .showing:
            monitor.start()  // no-op if already running
        case .disabled, .needsPermission:
            monitor.stop()
            cancelSettleTimer()
            captureTask?.cancel()
            captureTask = nil
            generation += 1  // drop any in-flight capture's late present
            overlay.hide()
        }
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: permissionPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollPermissions() }
        }
    }

    /// Detect a permission gained/lost while running. A manual OFF (`.disabled`) is left
    /// untouched — recovering AX must not silently re-enable what the user turned off.
    private func pollPermissions() {
        guard isEnabled else { return }
        let before = appState
        appState = stateReducer.reduce(appState, .permissionsChanged(permissions.current()))
        guard appState != before else { return }
        DebugLog.log("permission change: \(before) → \(appState)")
        syncMonitoring()
        onStateChange?()
    }

    // MARK: - Hover

    private func handleMoved(_ point: CGPoint) {
        let (newState, effects) = hover.reduce(hoverState, .moved(point))
        hoverState = newState
        // A no-op (sub-minMovement jitter) keeps the current overlay; only real movement
        // dismisses it and re-arms the settle timer.
        guard !effects.isEmpty else { return }

        // Real movement invalidates anything tied to the previous cursor position:
        //   • bump `generation` so a still-running capture's late `present` is dropped,
        //   • cancel that capture task so it never even reaches `present`,
        //   • hide unconditionally so a visible chip clears even if state isn't `.showing`.
        // Without this, a capture that started over a word could finish *after* the cursor
        // left onto empty space and stopped — re-showing a chip with nothing to dismiss it
        // (the "chip won't disappear" bug).
        generation += 1
        captureTask?.cancel()
        captureTask = nil
        if case .showing = appState {
            appState = stateReducer.reduce(appState, .cursorMoved)
        }
        overlay.hide()
        apply(effects)
    }

    private func apply(_ effects: [HoverEffect]) {
        for effect in effects {
            switch effect {
            case .armTimer(let gen): armSettleTimer(generation: gen)
            case .cancelTimer: cancelSettleTimer()
            case .fire(let point): onHoverSettled(at: point)
            }
        }
    }

    private func armSettleTimer(generation gen: Int) {
        settleTimer?.invalidate()
        settleTimer = Timer.scheduledTimer(withTimeInterval: settleDelay, repeats: false) { [weak self] _ in
            // Timer fires on the main run loop; AppCoordinator is @MainActor.
            MainActor.assumeIsolated {
                guard let self else { return }
                let (s, fx) = self.hover.reduce(self.hoverState, .timerFired(generation: gen))
                self.hoverState = s
                self.apply(fx)
            }
        }
    }

    private func cancelSettleTimer() {
        settleTimer?.invalidate()
        settleTimer = nil
    }

    // MARK: - Capture → present

    private func onHoverSettled(at point: CGPoint) {
        generation += 1
        let gen = generation
        appState = stateReducer.reduce(appState, .hoverSettled(generation: gen))
        DebugLog.log("settle: gen=\(gen) at=(\(Int(point.x)),\(Int(point.y))) state=\(appState)")
        guard case .capturing = appState else {
            DebugLog.log("settle: not capturing (state=\(appState)) → skip")
            return
        }

        // Hard privacy rule: never read secure (password) fields.
        if secureDetector.isSecureField(at: point) {
            DebugLog.log("settle: secure field → suppress")
            failCapture(gen)
            return
        }

        captureTask?.cancel()
        captureTask = Task { [weak self] in
            guard let self else { return }
            let captured = await self.capture.captureText(at: point)
            if Task.isCancelled { return }
            self.present(captured, generation: gen)
        }
    }

    private func present(_ captured: CapturedText?, generation gen: Int) {
        // Drop stale results (a newer settle has happened since this capture started).
        guard gen == generation else { return }

        guard let captured else { return failCapture(gen) }
        let runs = composer.compose(analyzer.analyze(captured.text))
        guard !runs.isEmpty else { return failCapture(gen) }

        let attributed = builder.build(runs, style: style)
        appState = stateReducer.reduce(appState, .captureSucceeded(generation: gen))
        overlay.show(attributed, at: captured.screenRect)
    }

    private func failCapture(_ gen: Int) {
        appState = stateReducer.reduce(appState, .captureFailed(generation: gen))
        // A settle that finds no glossable text (empty/non-kanji/secure) must leave the
        // screen clean — hide any chip still up from a previous word.
        overlay.hide()
    }
}
