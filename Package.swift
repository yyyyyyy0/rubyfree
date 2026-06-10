// swift-tools-version: 6.2
import PackageDescription

// rubyfree — hover-to-furigana macOS utility.
// 3-target separation enforces the layer boundary at compile time:
//   RubyfreeCore   : pure domain logic (no AppKit / OS deps) — 80% coverage target
//   RubyfreeSystem : OS-boundary wrappers (AX / ScreenCaptureKit / Vision / input)
//   rubyfree       : AppKit menu-bar agent executable (composition root)
//
// Command Line Tools ships no XCTest / swift-testing, so tests are plain executables
// built on the dependency-free TinyTest harness; run via `swift run <Name>Tests`.
let package = Package(
    name: "rubyfree",
    platforms: [.macOS("26.0")],
    targets: [
        .target(name: "RubyfreeCore"),
        .target(
            name: "RubyfreeSystem",
            dependencies: ["RubyfreeCore"]
        ),
        .executableTarget(
            name: "rubyfree",
            dependencies: ["RubyfreeCore", "RubyfreeSystem"]
        ),

        // --- Test harness + test executables ---
        .target(name: "TinyTest"),
        .executableTarget(
            name: "RubyfreeCoreTests",
            dependencies: ["RubyfreeCore", "TinyTest"],
            path: "Tests/RubyfreeCoreTests"
        ),
        .executableTarget(
            name: "RubyfreeSystemTests",
            dependencies: ["RubyfreeSystem", "TinyTest"],
            path: "Tests/RubyfreeSystemTests"
        ),
    ]
)
