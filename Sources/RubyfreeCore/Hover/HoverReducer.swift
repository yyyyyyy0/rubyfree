import CoreGraphics

/// Pure reducer for hover-settle detection.
///
/// The host owns the actual timer; the reducer stays completely free of
/// OS dependencies.  Call ``reduce(_:_:)`` on every cursor event and on
/// every timer callback.  Apply the returned effects in order.
public struct HoverReducer: Sendable {

    /// Minimum cursor displacement (in points) that counts as real movement.
    /// Micro-jitter below this threshold is ignored so that the armed timer
    /// is not reset while the cursor is essentially stationary.
    public let minMovement: CGFloat

    public init(minMovement: CGFloat = 4) {
        self.minMovement = minMovement
    }

    /// Pure transition function — no mutations, no I/O.
    ///
    /// - Parameters:
    ///   - state: Current hover state.
    ///   - input: The event that just occurred.
    /// - Returns: Updated state and the list of side-effects to perform.
    public func reduce(
        _ state: HoverState,
        _ input: HoverInput
    ) -> (HoverState, [HoverEffect]) {
        switch input {

        case .moved(let point):
            // If the cursor hasn't moved far enough from its last recorded
            // position, treat it as noise and do nothing — in particular, do
            // NOT re-arm the timer, which would delay the eventual fire.
            if let last = state.lastPoint,
               distance(last, point) < minMovement {
                return (state, [])
            }

            // Real movement: record the new position and arm a fresh timer.
            let newGen = state.armedGeneration + 1
            var newState = state
            newState.lastPoint = point
            newState.armedGeneration = newGen
            return (newState, [.armTimer(generation: newGen)])

        case .timerFired(let gen):
            // Only act if the fired generation matches the currently-armed one
            // and there is a recorded point to fire at.
            if gen == state.armedGeneration, let point = state.lastPoint {
                return (state, [.fire(at: point)])
            }
            // Stale or spurious timer — ignore.
            return (state, [])
        }
    }

    // MARK: - Private helpers

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
