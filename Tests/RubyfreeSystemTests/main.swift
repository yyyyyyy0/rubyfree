import TinyTest

// Entry point: register all RubyfreeSystem test functions, then exit with the result.
let t = TinyTest()
testSystemSmoke(t)
t.finish()
