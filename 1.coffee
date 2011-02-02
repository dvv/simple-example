#!/usr/bin/env coffee
'use strict'

console.log process.argv
process.exit 0

require.paths.unshift __dirname + '/lib/node'

sys = require 'util'
console.log = () ->
	for arg in arguments
		sys.debug sys.inspect arg

require('nodeunit').reporters.default.run ['test']
