#!/usr/local/bin/coffee
'use strict'

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 20

simple = require './node_modules/simple'
fetch = require('./src/currency').fetchExchangeRates

fetch 'usd', (err, data) ->
	console.log _.map data, (x) ->
		if _.isEmpty x.value
			x.value = undefined
		else
			x.value = _.reduce(x.value, ((s, y) -> s += y), 0) / _.size(x.value)
		x

#process.exit 0
