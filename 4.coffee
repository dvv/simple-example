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

###
instance =
	a: 12
	b: 12

schema =
	type: 'object'
	properties:
		a:
			type: 'any'
			enum: () -> [1,2,123]
			enum1: (value, fn) ->
				setTimeout () ->
					values = [1,12,3]
					fn not _.include values, value
				, 1000
		b:
			type: 'any'
			enum: [1,2,12]
			enum2: (value, fn) ->
				setTimeout () ->
					values = [1,2,3,4]
					fn not _.include values, value
				, 100

console.log validate instance, schema, {}

#console.log validate instance, schema, {}, (err, result) ->
#	console.log 'DONE', arguments
###

config = require './config'
simple = require 'jse'
#
# app should provide for .getContext(uid, next) -- the method to retrieve
#   capability object for user uid
#
app = require './app'

require('repl').start 'test>'
