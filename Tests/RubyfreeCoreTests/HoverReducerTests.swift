import CoreGraphics
import RubyfreeCore
import TinyTest

func testHoverReducer(_ t: TinyTest) {
    let reducer = HoverReducer(minMovement: 4)
    let initial = HoverState()

    // 1. First real move → armTimer(generation: 1)
    let p1 = CGPoint(x: 100, y: 200)
    let (s1, e1) = reducer.reduce(initial, .moved(p1))
    t.expectEqual(e1, [.armTimer(generation: 1)])
    t.expectEqual(s1.armedGeneration, 1)
    t.expectEqual(s1.lastPoint, p1)

    // 2. Micro-jitter (distance < minMovement) → ignored, no effects, state unchanged
    let pNoise = CGPoint(x: 100 + 2, y: 200 + 1)  // distance ≈ 2.24 < 4
    let (s2, e2) = reducer.reduce(s1, .moved(pNoise))
    t.expectEqual(e2, [])
    t.expectEqual(s2, s1)  // state must be identical

    // 3. Large movement (distance > minMovement) → armTimer(generation: 2)
    let p2 = CGPoint(x: 200, y: 300)
    let (s3, e3) = reducer.reduce(s1, .moved(p2))
    t.expectEqual(e3, [.armTimer(generation: 2)])
    t.expectEqual(s3.armedGeneration, 2)
    t.expectEqual(s3.lastPoint, p2)

    // 4. timerFired with current generation → fire(at: latest point)
    let (s4, e4) = reducer.reduce(s3, .timerFired(generation: 2))
    t.expectEqual(e4, [.fire(at: p2)])
    t.expectEqual(s4, s3)  // state is unchanged by fire

    // 5. timerFired with stale generation (gen 1 after gen 2 armed) → ignored
    let (s5, e5) = reducer.reduce(s3, .timerFired(generation: 1))
    t.expectEqual(e5, [])
    t.expectEqual(s5, s3)
}
