module.exports.test1 = (test) ->
	test.expect 1
	test.ok not not U.each, "this assertion should pass"
	test.done()
