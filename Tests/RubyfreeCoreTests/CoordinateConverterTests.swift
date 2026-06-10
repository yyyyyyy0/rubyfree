import CoreGraphics
import RubyfreeCore
import TinyTest

func testCoordinateConverter(_ t: TinyTest) {
    let conv = CoordinateConverter()

    // --- axToAppKit ---

    // y-flip: globalHeight=1000, AX y=200 → AppKit y=800
    let pt = conv.axToAppKit(CGPoint(x: 50, y: 200), globalHeight: 1000)
    t.expectEqual(pt.x, 50)
    t.expectEqual(pt.y, 800)

    // x is unchanged
    let pt2 = conv.axToAppKit(CGPoint(x: 300, y: 0), globalHeight: 1000)
    t.expectEqual(pt2.x, 300)
    t.expectEqual(pt2.y, 1000)

    // --- axRectToAppKit ---

    // AX rect: origin=(100, 200), size=(400, 100) in a 1000-point-tall desktop
    // AppKit bottom-left y = 1000 - (200 + 100) = 700
    let axRect = CGRect(x: 100, y: 200, width: 400, height: 100)
    let appKitRect = conv.axRectToAppKit(axRect, globalHeight: 1000)
    t.expectEqual(appKitRect.origin.x, 100)
    t.expectEqual(appKitRect.origin.y, 700)
    t.expectEqual(appKitRect.width, 400)
    t.expectEqual(appKitRect.height, 100)

    // AX rect touching the very top of the screen (origin.y == 0)
    let topRect = CGRect(x: 0, y: 0, width: 200, height: 50)
    let topAppKit = conv.axRectToAppKit(topRect, globalHeight: 1000)
    t.expectEqual(topAppKit.origin.y, 950)   // 1000 - (0 + 50)

    // --- pixelToPoint ---

    // Retina scale=2: pixel rect (0,0,200,100) → point rect (0,0,100,50)
    let pixelRect = CGRect(x: 0, y: 0, width: 200, height: 100)
    let pointRect = conv.pixelToPoint(pixelRect, scale: 2)
    t.expectEqual(pointRect.origin.x, 0)
    t.expectEqual(pointRect.origin.y, 0)
    t.expectEqual(pointRect.width, 100)
    t.expectEqual(pointRect.height, 50)

    // Non-Retina scale=1: no change
    let same = conv.pixelToPoint(pixelRect, scale: 1)
    t.expectEqual(same, pixelRect)

    // Origin is also scaled
    let offsetPixel = CGRect(x: 40, y: 60, width: 80, height: 40)
    let offsetPoint = conv.pixelToPoint(offsetPixel, scale: 2)
    t.expectEqual(offsetPoint.origin.x, 20)
    t.expectEqual(offsetPoint.origin.y, 30)
    t.expectEqual(offsetPoint.width, 40)
    t.expectEqual(offsetPoint.height, 20)
}
