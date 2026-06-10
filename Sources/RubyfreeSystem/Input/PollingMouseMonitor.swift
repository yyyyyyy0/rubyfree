import AppKit
import CoreGraphics

/// Polls `NSEvent.mouseLocation` on a repeating timer and fires `onMove` whenever the
/// cursor position changes. S0-2 confirmed that `addGlobalMonitorForEvents(.mouseMoved)`
/// silently drops events without Accessibility, so polling is the primary strategy.
///
/// - Polling interval: 0.12 s (~8 Hz), a good balance between responsiveness and CPU.
/// - Coordinate system: AppKit global (bottom-left origin), matching `CGPoint` use site.
@MainActor
public final class PollingMouseMonitor: @MainActor GlobalMouseMonitoring {

    // MARK: - GlobalMouseMonitoring

    /// Called on the main actor whenever the cursor position changes.
    public var onMove: (@MainActor (CGPoint) -> Void)?

    // MARK: - Private state (all MainActor-isolated, no locks needed)

    private var timer: Timer?
    private var lastPoint: CGPoint = .zero

    // MARK: - Init

    public init() {}

    // MARK: - GlobalMouseMonitoring conformance

    /// Starts the polling timer. Calling `start()` while already running is a no-op.
    public func start() {
        guard timer == nil else { return }
        // Capture `self` weakly so that Timer does not keep the monitor alive if the
        // caller drops the reference while the timer is still scheduled.
        timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            // Timer callbacks run on the thread the timer was scheduled on.  We always
            // schedule on the main RunLoop (called from @MainActor start()), so this
            // re-entry into MainActor isolation is safe.
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        // Seed the initial position so the first tick doesn't always fire.
        lastPoint = NSEvent.mouseLocation
    }

    /// Stops and invalidates the polling timer. Safe to call when already stopped.
    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Tick

    private func tick() {
        let current = NSEvent.mouseLocation
        guard current.x != lastPoint.x || current.y != lastPoint.y else { return }
        lastPoint = current
        onMove?(current)
    }
}
