import CoreGraphics

/// Observes global cursor position and delivers points on the main actor. The concrete
/// implementation polls `NSEvent.mouseLocation` (S0-2: a global `.mouseMoved` monitor
/// needs Accessibility and silently fails without it, so polling is the primary source).
public protocol GlobalMouseMonitoring: AnyObject {
    /// Called on the main actor for each observed cursor position.
    var onMove: (@MainActor (CGPoint) -> Void)? { get set }
    func start()
    func stop()
}
