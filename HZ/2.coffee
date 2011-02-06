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

		model = _.freeze exposed
		console.log 'MODEL', model 
		###
					# register permissive facet -- set of entity accessors
					expose = ['schema', 'id', 'query', 'get', 'add', 'update', 'remove']
					expose = expose.concat ['delete', 'undelete', 'purge'] if @attrInactive
					self.facet[name] = _.proxy store, expose
		###

		#
		# app should provide for .getContext(uid, next) -- the method to retrieve
		#   capability object for user uid
		#
		app = require('./app') model

		next null, app

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
