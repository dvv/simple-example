#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'
global._ = require 'underscore'
validate = require 'jse/validate'
#Schema = require 'json-schema/lib/validate'
#validate = (instance, schema, options) ->
#	Schema._validate instance, schema, options

inspect = require('eyes.js').inspector stream: null
consoleLog = console.log
console.log = () -> consoleLog inspect arg for arg in arguments

#process.nextTick () ->
#	console.log 'nextTick callback'

instance =
	a: 12

schema =
	type: 'object'
	properties:
		a:
			type: 'any'
			enum1: [1,2,12]
			enum2: (fn) ->
				setTimeout () ->
					fn null, [1,2,3]
				, 300

console.log validate instance, schema, {}, (err, result) ->
	console.log 'DONE', arguments

