#!/usr/bin/env coffee
'use strict'

process.argv.shift() # still report 'node' as argv[0]
require.paths.unshift '../node_modules' # coffee counts from coffee-script binary so far

config = require './config'
simple = require 'simple'

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
		# define capability object for given user uid
		#
		getContext = (uid, next) ->
			context = _.extend.apply null, [{}, facet]
			# FIXME: _.freeze is very consuming!
			next? null, _.freeze context

		#
		# define middleware stack
		#
		getHandler = (server) -> simple.stack(

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
				getContext: getContext

			#simple.handlers.mount 'GET', '/home', (req, res, next) ->
			#	res.send 'FOO'

			#simple.handlers.logRequest()

			# RPC+REST
			simple.handlers.jsonrpc
				maxBodyLength: 0 # set to >0 to limit the number of bytes

			#simple.handlers.mount 'POST', '/foo', (req, res, next) ->
			#	res.send 'FOO'

			simple.handlers.mount 'GET', '/geo', (req, res, next) ->
				res.send require('fs').readFileSync('geoip/geo.json')

			simple.handlers.mount 'GET', '/course', (req, res, next) ->
				require('./currency').fetchExchangeRates 'rub', (err, data) ->
					res.send err or data

			simple.handlers.dynamic
				map:
					'/': 'test/index.html'

			simple.handlers.mount 'GET', '/foo2', (req, res, next) ->
				res.send 'GOT FROM HOME'

			simple.handlers.static
				root: config.server.pub.dir
				default: 'index.html'
				#cacheMaxFileSizeToCache: 1024 # set to limit the size of cacheable file
				cacheTTL: 1000
				process: simple.handlers.helpers.template()

		)

		#
		# compose application
		#
		app = Object.freeze
			getHandler: getHandler
			messageHandler: (broadcaster, message) -> # @ === worker
				if message.channel is 'bcast'
					console.error 'BCAST!', message
					broadcaster? message.data

		#
		# run the application
		#
		if process.argv[1] is 'test'
			console.log '!!!TESTING MODE!!!'
			require('../test/000.basics') app

		#
		simple.run app, config.server

	#
	# define fallback
	#
	(err, result, next) ->

		console.log "OOPS, shouldn't have been here!", err
