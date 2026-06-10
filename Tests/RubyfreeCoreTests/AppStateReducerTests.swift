import RubyfreeCore
import TinyTest

func testAppStateReducer(_ t: TinyTest) {
    let r = AppStateReducer()

    // ── Happy path: idle → capture → show → cursorMoved → idle ───────────────
    let s0: AppState = .idle
    let s1 = r.reduce(s0, .hoverSettled(generation: 1))
    t.expectEqual(s1, .capturing(generation: 1))

    let s2 = r.reduce(s1, .captureSucceeded(generation: 1))
    t.expectEqual(s2, .showing(generation: 1))

    let s3 = r.reduce(s2, .cursorMoved)
    t.expectEqual(s3, .idle)

    // ── captureFailed returns to idle ─────────────────────────────────────────
    let sf = r.reduce(.capturing(generation: 3), .captureFailed(generation: 3))
    t.expectEqual(sf, .idle)

    // ── Stale captureSucceeded is ignored (capturing gen 2, event gen 1) ─────
    let stale1 = r.reduce(.capturing(generation: 2), .captureSucceeded(generation: 1))
    t.expectEqual(stale1, .capturing(generation: 2))

    // ── Stale captureSucceeded while showing different gen ────────────────────
    let stale2 = r.reduce(.showing(generation: 2), .captureSucceeded(generation: 1))
    t.expectEqual(stale2, .showing(generation: 2))

    // ── Stale captureFailed is ignored ────────────────────────────────────────
    let stale3 = r.reduce(.capturing(generation: 5), .captureFailed(generation: 4))
    t.expectEqual(stale3, .capturing(generation: 5))

    // ── Permission loss from any active state → needsPermission ──────────────
    let lostP = PermissionStatus(accessibility: false, screenRecording: false)
    t.expectEqual(r.reduce(.idle, .permissionsChanged(lostP)), .needsPermission(lostP))
    t.expectEqual(r.reduce(.capturing(generation: 1), .permissionsChanged(lostP)), .needsPermission(lostP))
    t.expectEqual(r.reduce(.showing(generation: 1), .permissionsChanged(lostP)), .needsPermission(lostP))

    // ── setEnabled(false) from any state → disabled ───────────────────────────
    t.expectEqual(r.reduce(.idle, .setEnabled(false)), .disabled)
    t.expectEqual(r.reduce(.capturing(generation: 7), .setEnabled(false)), .disabled)
    t.expectEqual(r.reduce(.showing(generation: 7), .setEnabled(false)), .disabled)
    let np = PermissionStatus(accessibility: true, screenRecording: false)
    t.expectEqual(r.reduce(.needsPermission(np), .setEnabled(false)), .disabled)

    // ── Disabled ignores hover / capture events ───────────────────────────────
    t.expectEqual(r.reduce(.disabled, .hoverSettled(generation: 1)), .disabled)
    t.expectEqual(r.reduce(.disabled, .captureSucceeded(generation: 1)), .disabled)
    t.expectEqual(r.reduce(.disabled, .captureFailed(generation: 1)), .disabled)
    t.expectEqual(r.reduce(.disabled, .cursorMoved), .disabled)

    // ── setEnabled(true) from disabled → idle ─────────────────────────────────
    t.expectEqual(r.reduce(.disabled, .setEnabled(true)), .idle)

    // ── Recovery: needsPermission → permissionsChanged(AX ok) → idle ─────────
    let hasAX = PermissionStatus(accessibility: true, screenRecording: false)
    let npState: AppState = .needsPermission(PermissionStatus(accessibility: false, screenRecording: false))
    t.expectEqual(r.reduce(npState, .permissionsChanged(hasAX)), .idle)

    // ── permissionsChanged(AX ok) while active keeps state ───────────────────
    t.expectEqual(r.reduce(.idle, .permissionsChanged(hasAX)), .idle)
    t.expectEqual(r.reduce(.capturing(generation: 9), .permissionsChanged(hasAX)), .capturing(generation: 9))
    t.expectEqual(r.reduce(.showing(generation: 9), .permissionsChanged(hasAX)), .showing(generation: 9))

    // ── permissionsChanged while disabled keeps disabled ──────────────────────
    t.expectEqual(r.reduce(.disabled, .permissionsChanged(hasAX)), .disabled)

    // ── cursorMoved on non-showing states is a no-op ──────────────────────────
    t.expectEqual(r.reduce(.idle, .cursorMoved), .idle)
    t.expectEqual(r.reduce(.capturing(generation: 2), .cursorMoved), .capturing(generation: 2))
    t.expectEqual(r.reduce(.disabled, .cursorMoved), .disabled)

    // ── hoverSettled replaces in-flight capture with newer generation ─────────
    let replaced = r.reduce(.capturing(generation: 4), .hoverSettled(generation: 5))
    t.expectEqual(replaced, .capturing(generation: 5))

    // ── hoverSettled from showing starts a new capture ────────────────────────
    let fromShowing = r.reduce(.showing(generation: 3), .hoverSettled(generation: 4))
    t.expectEqual(fromShowing, .capturing(generation: 4))
}
