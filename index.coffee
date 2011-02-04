#!/usr/local/bin/coffee
'use strict'

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

			simple.handlers.static
				dir: config.server.static.dir
				ttl: config.server.static.ttl

			#simple.handlers.mount '/foo1',
			#	get: (req, res, next) -> res.send 'GETFOO1'
			#	post: (req, res, next) -> res.send 'POSTFOO1'

			simple.handlers.jsonBody
				maxLength: 0 # set to >0 to limit the number of bytes

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

		)

		#
		# run the application
		#
		simple.run handler, config.server
