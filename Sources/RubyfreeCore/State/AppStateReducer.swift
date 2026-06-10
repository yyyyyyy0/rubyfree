/// Events that drive `AppState` transitions.
/// All values are pure data; no side effects.
public enum AppEvent: Equatable, Sendable {
    /// User toggled rubyfree on (`true`) or off (`false`) via the menu.
    case setEnabled(Bool)
    /// System permission snapshot changed (polled or callback).
    case permissionsChanged(PermissionStatus)
    /// Cursor settled over a word; begin capture for the given generation.
    case hoverSettled(generation: Int)
    /// Capture completed successfully; show overlay for the given generation.
    case captureSucceeded(generation: Int)
    /// Capture failed (network/AX error, no kanji found); return to idle.
    case captureFailed(generation: Int)
    /// Cursor moved; dismiss the overlay if one is showing.
    case cursorMoved
}

/// Pure reducer: maps `(AppState, AppEvent) → AppState`.
/// No mutation, no stored state, no concurrency concerns — safe to call from any context.
public struct AppStateReducer: Sendable {
    public init() {}

    /// Returns the next state given the current state and an event.
    ///
    /// **Generation-based staleness**: `captureSucceeded` / `captureFailed` events whose
    /// `generation` does not match the current `capturing(generation:)` value are silently
    /// dropped. This prevents a late async result from a superseded capture from overwriting
    /// fresher UI state.
    public func reduce(_ state: AppState, _ event: AppEvent) -> AppState {
        switch event {

        // ── Enable / Disable ──────────────────────────────────────────────────────
        case .setEnabled(false):
            return .disabled

        case .setEnabled(true):
            // We have no cached permission snapshot here; assume idle (the coordinator
            // will fire permissionsChanged immediately after enabling if needed).
            switch state {
            case .disabled, .needsPermission:
                return .idle
            default:
                // Already enabled — no-op.
                return state
            }

        // ── Permissions ───────────────────────────────────────────────────────────
        case .permissionsChanged(let p):
            if !p.canRunAXOnly {
                // AX revoked → must show permission prompt regardless of current state.
                return .needsPermission(p)
            }
            // AX is present.
            switch state {
            case .disabled:
                // Stay disabled; enablement is a separate user gesture.
                return .disabled
            case .needsPermission:
                // Permission restored → recover to idle.
                return .idle
            default:
                // Already active (idle / capturing / showing) and permissions are met → keep.
                return state
            }

        // ── Hover / Capture lifecycle ─────────────────────────────────────────────
        case .hoverSettled(let gen):
            switch state {
            case .idle, .showing:
                // Start a new capture (showing → cursor didn't move yet but new hover settled).
                return .capturing(generation: gen)
            case .capturing:
                // Replace the in-flight capture with the newer generation.
                return .capturing(generation: gen)
            case .disabled, .needsPermission:
                // Not enabled — ignore.
                return state
            }

        case .captureSucceeded(let gen):
            guard state == .capturing(generation: gen) else {
                // Stale result — drop.
                return state
            }
            return .showing(generation: gen)

        case .captureFailed(let gen):
            guard state == .capturing(generation: gen) else {
                // Stale result — drop.
                return state
            }
            return .idle

        // ── Cursor movement ───────────────────────────────────────────────────────
        case .cursorMoved:
            switch state {
            case .showing:
                return .idle
            default:
                return state
            }
        }
    }
}
