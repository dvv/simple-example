#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

sys = require 'util'
console.log = () -> sys.debug sys.inspect arg for arg in arguments

console.log module, process, require
