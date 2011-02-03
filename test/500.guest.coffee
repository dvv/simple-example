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
		app.getContext 'nemo', (err, result) ->
			context = result
			callback()

	tearDown: (callback) ->
		callback()

	testEntities: (test) ->
		authority = []
		for own entity, facet of context
			continue if entity.match /^(get|set|login)/
			authority.push entity
		test.ok authority.length is 1 and authority[0] is 'Hit', 'Right to register a hit'
		test.done()

	testHit: (test) ->
		for i in [999..0]
			nonce = String(Math.random()).substring(2)
			context.Hit.add.call context, {id: nonce, name: nonce}, (err, result) ->
				#console.log arguments
				test.ok not err and result.name
				test.done() unless i
