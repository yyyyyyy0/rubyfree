import Vision
import CoreGraphics
import Foundation
import RubyfreeCore

/// A single recognized word and its location in the captured image.
struct OCRWord: Sendable {
    let text: String
    /// Pixel rect in the image, **upper-left** origin (y-down).
    let boxInImage: CGRect
    let confidence: Double
}

/// Vision-based text recognition over a small captured image.
///
/// Uses `.accurate` (the `.fast` level crashes the macOS text detector on small images —
/// verified empirically). The request is bounded to a clipped region by the caller, so
/// per-call latency is ~160ms warm. `prewarm()` pays the one-time model load up front.
///
/// Stateless `struct`: methods are `nonisolated async`, so Vision's non-Sendable types
/// stay within the async call tree and the work runs off the main actor.
struct VisionTextRecognizer {

    /// Run a throwaway recognition so the first real hover doesn't eat the cold-start cost.
    func prewarm() async {
        let w = 64, h = 64
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return }
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        guard let img = ctx.makeImage() else { return }
        _ = try? await makeRequest().perform(on: img)
    }

    /// Recognize text and return the word whose box best matches `cursorImagePoint`
    /// (pixel coords, upper-left origin): a word containing the point wins (smallest such
    /// box), otherwise the nearest word by center distance.
    func wordNear(_ cursorImagePoint: CGPoint, in image: CGImage) async -> OCRWord? {
        guard let observations = try? await makeRequest().perform(on: image) else { return nil }
        let imageSize = CGSize(width: image.width, height: image.height)

        var containing: OCRWord?
        var nearest: (word: OCRWord, dist: CGFloat)?

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let line = candidate.string
            let confidence = Double(candidate.confidence)

            for range in wordRanges(in: line) {
                guard let rectObs = candidate.boundingBox(for: range) else { continue }
                let box = rectObs.boundingBox.toImageCoordinates(imageSize, origin: .upperLeft)
                guard box.width > 0, box.height > 0 else { continue }
                let word = OCRWord(text: String(line[range]), boxInImage: box, confidence: confidence)

                if box.contains(cursorImagePoint) {
                    if containing == nil || box.width * box.height < containing!.boxInImage.width * containing!.boxInImage.height {
                        containing = word
                    }
                }
                let d = hypot(box.midX - cursorImagePoint.x, box.midY - cursorImagePoint.y)
                if nearest == nil || d < nearest!.dist {
                    nearest = (word, d)
                }
            }
        }
        return containing ?? nearest?.word
    }

    // MARK: - Private

    private func makeRequest() -> RecognizeTextRequest {
        var req = RecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.recognitionLanguages = [Locale.Language(identifier: "ja"), Locale.Language(identifier: "en")]
        req.usesLanguageCorrection = false
        return req
    }

    /// Enumerate word ranges in `line` using the shared ja_JP word-boundary tokenizer.
    private func wordRanges(in line: String) -> [Range<String.Index>] {
        let cf = line as CFString
        let length = CFStringGetLength(cf)
        guard length > 0,
              let tokenizer = CFStringTokenizerCreate(
                kCFAllocatorDefault, cf, CFRangeMake(0, length),
                kCFStringTokenizerUnitWordBoundary, Locale(identifier: "ja_JP") as CFLocale
              ) else { return [] }

        var ranges: [Range<String.Index>] = []
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let r = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            if let swiftRange = Range(NSRange(location: r.location, length: r.length), in: line) {
                ranges.append(swiftRange)
            }
        }
        return ranges
    }
}
