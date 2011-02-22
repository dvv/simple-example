#!/usr/local/bin/coffee
'use strict'

process.argv.shift() # still reports 'node' as argv[0]
require.paths.unshift __dirname + '/lib/node'

config = require './config'
simple = require './node_modules/simple'

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
		handler = simple.stack(

			# parse JSON payload
			simple.handlers.jsonBody
				maxLength: 0 # set to >0 to limit the number of bytes

			#simple.handlers.mount '/foo1',
			#	get: (req, res, next) -> res.send 'GETFOO1'
			#	post: (req, res, next) -> res.send 'POSTFOO1'

			#simple.handlers.body
			#	uploadDir: config.upload.dir

			# setup request context
			simple.handlers.authCookie
				cookie: 'uid'
				secret: config.security.secret
				getContext: app.getContext

			#simple.handlers.mount 'GET', '/home', (req, res, next) ->
			#	res.send 'FOO'

			#simple.handlers.logRequest()

			# RPC+REST
			simple.handlers.jsonrpc
				maxBodyLength: 0 # set to >0 to limit the number of bytes

			#simple.handlers.mount 'POST', '/foo', (req, res, next) ->
			#	res.send 'FOO'

			simple.handlers.mount 'GET', '/geo', (req, res, next) ->
				res.send require('fs').readFileSync('./geo/Geo.json')

			# serve chrome page
			simple.handlers.chrome()

			# serve remaining static resourses
			simple.handlers.static_
				dir: config.server.pub.dir
				honorType: true
				ttl: config.server.pub.ttl

		)

		#
		# run the application
		#
		if process.argv[1] is 'test'
			console.log '!!!TESTING MODE!!!'
			require('./test/000.basics') app

		#
		simple.run handler, config.server

	#
	# define fallback
	#
	(err, result, next) ->

		console.log "OOPS, shouldn't have been here!", err
