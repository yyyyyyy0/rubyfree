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

    private let hover: HoverReducer
    private let stateReducer: AppStateReducer
    private let settleDelay: TimeInterval

    private var hoverState = HoverState()
    private var appState: AppState = .idle
    private var generation = 0
    private var settleTimer: Timer?
    private var captureTask: Task<Void, Never>?

    init(
        monitor: any GlobalMouseMonitoring,
        capture: any TextCapturing,
        secureDetector: any SecureFieldDetecting,
        analyzer: any JapaneseAnalyzing,
        composer: RubyComposer = RubyComposer(),
        builder: RubyAttributedBuilder = RubyAttributedBuilder(),
        overlay: any OverlayPresenting,
        permissions: any PermissionChecking,
        settleDelay: TimeInterval = 0.35,
        minMovement: CGFloat = 4
    ) {
        self.monitor = monitor
        self.capture = capture
        self.secureDetector = secureDetector
        self.analyzer = analyzer
        self.composer = composer
        self.builder = builder
        self.overlay = overlay
        self.permissions = permissions
        self.hover = HoverReducer(minMovement: minMovement)
        self.stateReducer = AppStateReducer()
        self.settleDelay = settleDelay
    }

    func start() {
        appState = stateReducer.reduce(appState, .permissionsChanged(permissions.current()))
        monitor.onMove = { [weak self] point in self?.handleMoved(point) }
        monitor.start()
    }

    // MARK: - Hover

    private func handleMoved(_ point: CGPoint) {
        let (newState, effects) = hover.reduce(hoverState, .moved(point))
        hoverState = newState
        // A no-op (sub-minMovement jitter) keeps the current overlay; only real movement
        // dismisses it and re-arms the settle timer.
        guard !effects.isEmpty else { return }
        if case .showing = appState {
            appState = stateReducer.reduce(appState, .cursorMoved)
            overlay.hide()
        }
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
        guard case .capturing = appState else { return }

        // Hard privacy rule: never read secure (password) fields.
        if secureDetector.isSecureField(at: point) {
            appState = stateReducer.reduce(appState, .captureFailed(generation: gen))
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

        let attributed = builder.build(runs)
        appState = stateReducer.reduce(appState, .captureSucceeded(generation: gen))
        overlay.show(attributed, at: captured.screenRect)
    }

    private func failCapture(_ gen: Int) {
        appState = stateReducer.reduce(appState, .captureFailed(generation: gen))
    }
}
