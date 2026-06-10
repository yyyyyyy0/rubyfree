/// The single source of truth for the app, owned by the (App-layer) coordinator.
/// Overlay lifecycle is folded into this enum, and `generation` is the shared staleness
/// primitive: hover/capture/overlay all compare against the current generation so a
/// late async result or a disabled toggle can never resurrect stale UI.
public enum AppState: Equatable, Sendable {
    /// User turned rubyfree off; no monitoring.
    case disabled
    /// Missing one or more permissions; cannot capture.
    case needsPermission(PermissionStatus)
    /// Enabled and waiting for the cursor to settle.
    case idle
    /// A capture is in flight for this generation.
    case capturing(generation: Int)
    /// An overlay is shown for this generation.
    case showing(generation: Int)
}
