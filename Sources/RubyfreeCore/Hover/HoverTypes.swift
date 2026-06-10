import CoreGraphics

/// Pure-logic state for the hover debouncer. "Settled" = no further movement for a
/// delay, which is the absence of events — so the reducer models it as an armed timer
/// keyed by `armedGeneration`, and a `timerFired` input that only fires if it matches.
public struct HoverState: Equatable, Sendable {
    /// Last cursor point seen (target of a future fire).
    public var lastPoint: CGPoint?
    /// Generation of the currently-armed timer; a `timerFired` with a different
    /// generation is stale and ignored.
    public var armedGeneration: Int

    public init(lastPoint: CGPoint? = nil, armedGeneration: Int = 0) {
        self.lastPoint = lastPoint
        self.armedGeneration = armedGeneration
    }
}

/// Inputs to the hover reducer.
public enum HoverInput: Equatable, Sendable {
    /// The cursor moved to a point (from a global monitor or polling).
    case moved(CGPoint)
    /// A previously-armed timer fired.
    case timerFired(generation: Int)
}

/// Side effects the reducer asks the host (App layer) to perform. The host owns the
/// actual timer; the reducer stays pure.
public enum HoverEffect: Equatable, Sendable {
    case armTimer(generation: Int)
    case cancelTimer
    case fire(at: CGPoint)
}
