import AppKit
import ScreenCaptureKit
import CoreGraphics
import RubyfreeCore

/// A screenshot of a small region around the cursor, plus the geometry needed to map
/// recognized-word boxes back to AppKit global coordinates.
struct RegionShot {
    /// Captured pixels.
    let image: CGImage
    /// The AppKit-global rect (points, bottom-left origin) the image covers.
    let regionAppKit: CGRect
    /// Pixels per point for the captured display.
    let scale: CGFloat
}

/// Captures a bounded region of the screen around a point via ScreenCaptureKit.
///
/// Only a small window around the cursor is grabbed (not the whole display) to keep the
/// per-hover cost low. Requires Screen Recording permission; when absent,
/// `SCShareableContent.current` throws and `capture` returns nil so capture degrades to
/// AX-only.
///
/// A stateless `struct`: `capture` is a `nonisolated async` method, so it runs on the
/// global executor (off the main actor) even when called from `@MainActor`, and the
/// non-Sendable ScreenCaptureKit handles never cross an isolation boundary.
struct ScreenRegionCapture {

    /// Capture a region of `size` (logical points) centered on `center` (AppKit global,
    /// bottom-left origin). Returns nil if off-screen or Screen Recording is denied.
    func capture(around center: CGPoint, size: CGSize) async -> RegionShot? {
        // Screen geometry must be read on the main actor.
        let info = await MainActor.run { () -> (frame: CGRect, scale: CGFloat, id: CGDirectDisplayID)? in
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) })
                    ?? NSScreen.main else { return nil }
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
                .uint32Value ?? CGMainDisplayID()
            return (screen.frame, screen.backingScaleFactor, id)
        }
        guard let info else { return nil }

        // Region in AppKit global, clamped to the containing screen.
        let raw = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                         width: size.width, height: size.height)
        let region = raw.intersection(info.frame)
        guard !region.isNull, region.width >= 16, region.height >= 16 else { return nil }

        // SCStreamConfiguration.sourceRect is display-local, top-left origin, points.
        let sourceRect = CGRect(
            x: region.minX - info.frame.minX,
            y: info.frame.maxY - region.maxY,
            width: region.width,
            height: region.height
        )

        guard let content = try? await SCShareableContent.current,
              let display = content.displays.first(where: { $0.displayID == info.id })
                ?? content.displays.first else {
            DebugLog.log("ocr: SCShareableContent unavailable (screen recording denied?)")
            return nil
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cfg = SCStreamConfiguration()
        cfg.sourceRect = sourceRect
        cfg.width = Int(region.width * info.scale)
        cfg.height = Int(region.height * info.scale)
        cfg.showsCursor = false

        guard let image = try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: cfg
        ) else {
            DebugLog.log("ocr: captureImage failed")
            return nil
        }
        return RegionShot(image: image, regionAppKit: region, scale: info.scale)
    }
}
