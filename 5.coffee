#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'
global._ = require 'underscore'

inspect = require('eyes.js').inspector stream: null
consoleLog = console.log
console.log = () -> consoleLog inspect arg for arg in arguments

Next = (context, steps...) ->
	next = (err, result) ->
		throw err if not steps.length and err
		fn = steps.shift()
		try
			fn.call context, err, result, next
		catch err
			next err
		return context
	next()

a = () -> Next {foo: 'bar'},
	(err, result, next) ->
		console.log 'first', arguments
		return next err if err
		#throw 'Catch me1!'
		next 'err1', 'res1'
	(err, result, next) ->
		console.log 'second', arguments
		return next err if err
		next 'err2', 'res2'
	(err, result, next) ->
		console.log 'third', arguments
		return next err if err
		next 'err3', 'res3'

try
	console.log 'A', a()
catch err
	console.log 'CAUGHT', err
