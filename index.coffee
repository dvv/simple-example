#!/usr/local/bin/coffee
'use strict'

process.argv.shift()
require.paths.unshift __dirname + '/lib/node'

config = require './config'
simple = require 'jse'

All {},

	#
	# define DB model
	#
	(err, result, next) ->

		new simple.Database config.database.url, require('./schema'), next

	#
	# define application
	#
	(err, exposed, next) ->

		model = exposed

		#
		# app should provide for .getContext(uid, next) -- the method to retrieve
		#   capability object for given user uid
		#
		require('./app') config, model, next

	#
	# define server
	#
	(err, app, next) ->

		#
		# define middleware stack
		#
		handler = require('stack')(

			simple.handlers.jsonBody
				maxLength: 0 # set to >0 to limit the number of bytes

			#simple.handlers.mount '/foo1',
			#	get: (req, res, next) -> res.send 'GETFOO1'
			#	post: (req, res, next) -> res.send 'POSTFOO1'

			#simple.handlers.body
			#	uploadDir: config.upload.dir

			simple.handlers.authCookie
				cookie: 'uid'
				secret: config.security.secret
				getContext: app.getContext

			#simple.handlers.mount 'GET', '/home', (req, res, next) ->
			#	res.send 'FOO'

			simple.handlers.logRequest()

			simple.handlers.jsonrpc
				maxBodyLength: 0 # set to >0 to limit the number of bytes

			#simple.handlers.mount 'POST', '/foo', (req, res, next) ->
			#	res.send 'FOO'

			simple.handlers.static
				dir: config.server.static.dir
				ttl: config.server.static.ttl

		)

		#
		# run the application
		#
		unless process.argv[2] is 'test'
			simple.run handler, config.server
		else
			console.log '!!!TESTING MODE!!!'
			#T = require('./test') app
			#testing = require 'async_testing'
			#testing.runSuite T, {}, (err, result) ->
			#	console.log 'DONE', arguments
			#	process.exit not err

			T = require('./test/000.basics') app
			#console.log T
			#T.run()

			#qunit = require 'node-qunit'
			#qunit.options.coverage = false
			#qunit.run
			#	tests: ['./test/000.basics.coffee']

	#
	# define fallback
	#
	(err, result, next) ->

		console.log "OOPS, shouldn't have been here!", err
