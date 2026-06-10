import RubyfreeSystem
import TinyTest

func testSystemSmoke(_ t: TinyTest) {
    t.expectEqual(RubyfreeSystem.version, "0.0.1")
}
