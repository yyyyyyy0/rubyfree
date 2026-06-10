import TinyTest

// Entry point: register all RubyfreeCore test functions, then exit with the result.
let t = TinyTest()
testCoreSmoke(t)
t.finish()
