'use strict'

require.paths.unshift __dirname + '/../lib/node'

config = require '../config'
simple = require 'jse'
app = require '../app'

testCase = require('nodeunit').testCase

# TODO: for tests delete/undelete/purge should be in facets
context = {}

module.exports = testCase

	setUp: (callback) ->
		app.getContext 'g', (err, result) ->
			context = result
			callback()

	tearDown: (callback) ->
		callback()

	testEntities: (test) ->
		authority = []
		for own entity, facet of context
			continue if entity.match /^(get|set|login)/
			authority.push entity
		test.ok authority.length is 1 and authority[0] is 'Affiliate', 'Right to manage sub-affiliates'
		test.done()

	# TODO: test sub-affiliating
