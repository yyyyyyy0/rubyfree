import RubyfreeCore
import TinyTest

func testCoreSmoke(_ t: TinyTest) {
    t.expectEqual(RubyfreeCore.version, "0.0.1")
}
