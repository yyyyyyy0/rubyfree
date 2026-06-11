import TinyTest

// Entry point: register all RubyfreeCore test functions, then exit with the result.
let t = TinyTest()
testCoreSmoke(t)
testCapturedTextSanitize(t)
testStandardAnalyzer(t)
testDictionaryAnalyzer(t)
testAppStateReducer(t)
testHoverReducer(t)
testCoordinateConverter(t)
testRubyComposer(t)
testRubyAttributedBuilder(t)
testWordBoundary(t)
t.finish()
