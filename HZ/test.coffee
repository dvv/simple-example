#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

# TODO: make 'development' come from environment
global.settings = require('./config').development

run = require('simple').run
Model = require('simple/store').Model

schema = {}
model = {}
facets = {}

schema.Region =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[A-Z_]+$'
			readonly:
				update: true
		name:
			type: 'string'

model.Region = Model 'Region', {schema: schema.Region}, {
}

global.assert   = require 'assert'
tester = require 'mongo/test/runner'
tester.dir __dirname + '/test'
tester.load 'region'
tester.next()
