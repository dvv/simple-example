'use strict'

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

			#simple.handlers.body
			#	uploadDir: config.upload.dir

			# setup request context
			simple.handlers.authCookie
				cookie: 'uid'
				secret: config.security.secret
				getContext: getContext

			# RPC+REST
			simple.handlers.jsonrpc
				maxBodyLength: 0 # set to >0 to limit the number of bytes

			simple.handlers.mount 'GET', '/geo', (req, res, next) ->
				res.send require('fs').readFileSync('../node_modules/simple-geoip/geo.json')

			simple.handlers.mount 'GET', '/course', (req, res, next) ->
				require('./currency').fetchExchangeRates config.defaults.currency, (err, data) ->
					res.send err or data

			# serve chrome page
			simple.handlers.dynamic
				map:
					'/': 'public/index.html'

			# serve remaining static resourses
			simple.handlers.static
				root: config.server.pub.dir
				default: 'index.html'
				#cacheMaxFileSizeToCache: 1024 # set to limit the size of cacheable file
				cacheTTL: 1000

		)

		#
		# compose application
		#
		app = Object.freeze
			#getContext: app.getContext
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
