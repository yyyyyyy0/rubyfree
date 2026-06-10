import Foundation

/// Minimal, dependency-free test harness for Command Line Tools environments, which
/// ship no XCTest / swift-testing. Tests are plain executables: build a `TinyTest`,
/// register expectations, then call `finish()` to exit with a status code
/// (0 = all passed, 1 = at least one failure).
///
/// Coverage is measured out-of-band via `swift build --enable-code-coverage` +
/// `xcrun llvm-cov` (see Scripts/coverage.sh), not through `swift test`.
public final class TinyTest {
    private var passed = 0
    private var failures: [String] = []

    public init() {}

    public func expectTrue(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String = "expected true",
        file: StaticString = #fileID, line: UInt = #line
    ) {
        if condition() {
            passed += 1
        } else {
            failures.append("\(file):\(line): \(message())")
        }
    }

    public func expectEqual<T: Equatable>(
        _ actual: T, _ expected: T,
        file: StaticString = #fileID, line: UInt = #line
    ) {
        if actual == expected {
            passed += 1
        } else {
            failures.append("\(file):\(line): expected \(expected), got \(actual)")
        }
    }

    /// Print a summary to stdout, failures to stderr, and exit.
    public func finish() -> Never {
        for failure in failures {
            FileHandle.standardError.write(Data("FAIL \(failure)\n".utf8))
        }
        print("TinyTest: \(passed) passed, \(failures.count) failed")
        exit(failures.isEmpty ? 0 : 1)
    }
}
