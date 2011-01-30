#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

global._ = require 'underscore'
rql = require('jse/rql').rql

inspect = require('eyes.js').inspector stream: null
consoleLog = console.log
console.log = () -> consoleLog inspect arg for arg in arguments

q1 = rql().nin('id',[456])
q2 = rql(q1)
console.log q1, q2 #.toMongo()
