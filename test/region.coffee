#require.paths.unshift __dirname + '/../lib/node'

#require 'server'
#Storage = require 'server/store'
#console.log Storage

#module.exports.test1 = (test) ->
#	test.expect 1
#	test.ok Storage.Store?, "this assertion should pass"
#	test.done()

runner.settle ->
	@next()

runner.mettle ->
	@Region = Storage.Model 'Region', {}, {}
	@Region.all '', () =>
		@next()

