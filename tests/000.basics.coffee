#!/usr/bin/env coffee

require.paths.unshift __dirname + '/../lib/node'

require 'should'
require 'jse'

test = (name, fn) ->
	try
		fn()
	catch err
		console.log '    \x1b[31m%s', name
		console.log '    %s\x1b[0m', err.stack
		return
	console.log '  √ \x1b[32m%s\x1b[0m', name

Suite = (context, tests) ->
	steps = _.map tests, (fn, name) -> [name, fn]
	console.log steps
	next = (err, result) ->
		unless steps.length
			[name, fn] = steps.shift()
		if fn
			try
				fn.call context, err, result, next
				console.log '  √ \x1b[32m%s\x1b[0m', name
			catch err
				console.log '    \x1b[31m%s', name
				console.log '    %s\x1b[0m', err.stack
				next err
		else
			throw err if err
		return
	next()

#Suite assert,
#	(err, result, next) ->
#	'wanna in her': (err, result, done) ->
#		assert.ok true
#		assert.notOk true
#		done()

#
#
#

module.exports =

	'wanna in her': (err, result, done) ->
		a0 = 0
		a1 = 1
		a1.should.be.ok
		a0.should.not.be.ok
		done()

	'wanna in her again': (err, result, done) ->
		a0 = 0
		a1 = 1
		a0.should.not.be.ok
		a1.should.be.ok
		done()

Suite {}, module.exports
