'use strict'

sys = require 'util'
spawn = require('child_process').spawn
net = require 'net'
netBinding = process.binding 'net'
fs = require 'fs'
http = require 'http'
crypto = require 'crypto'
events = require 'events'

# merge helpers
require './h'

# improve http.IncomingMessage
require './request'
# improve http.ServerResponse
require './response'

# merge storage
store = require './store'
global.Store = store.Store
global.Model = store.Model
global.Facet = store.Facet
global.RestrictiveFacet = store.RestrictiveFacet
global.PermissiveFacet = store.PermissiveFacet

# mixin JSON-RPC
#jsonrpc = require './json-rpc'

# connect to frontend db
redis = require 'redis'
db = redis.createClient()

#
# farm factory, takes configuration and the request handler
#
createFarm = (options, handler) ->

	# options
	options ?= {}
	options.port ?= 80

	#
	node = new process.EventEmitter()

	# setup server
	server = http.createServer()

	# SSL?
	if options.sslKey
		credentials = crypto.createCredentials
			key: fs.readFileSync options.sslKey, 'utf8'
			cert: fs.readFileSync options.sslCert, 'utf8'
			#ca: options.sslCACerts.map (fname) -> fs.readFileSync fname, 'utf8'
		server.setSecure credentials
	server.on 'request', handler

	# websocket?
	if options.websocket
		#ws = require('ws-server').createServer debug: true, server: server
		ws = require('socket.io').listen server, flashPolicyServer: false
		ws.on 'connection', (client) ->
			client.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: 'IAMIN'
			client.on 'disconnect', () ->
				ws.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: 'IAMOUT'
			client.on 'message', (message) ->
				#console.log 'MESSAGE', message
				client.broadcast JSON.stringify channel: 'bcast', client: client.sessionId, message: message
		# broadcast to clients what is published to 'bcast' channel
		dbPubSub = redis.createClient()
		dbPubSub.on 'message', (channel, message) ->
			ws.broadcast JSON.stringify channel: channel, message: message.toString('utf8')
		dbPubSub.subscribe 'bcast'

	# worker branch
	if process.env._WID_

		Object.defineProperty node, 'id', value: process.env._WID_

		# obtain the master socket from the master and listen to it
		comm = new net.Stream 0, 'unix'
		data = {}
		comm.on 'data', (message) ->
			# get config from master
			data = JSON.parse message
			Object.defineProperty data, 'wid', value: node.id, enumerable: true
		comm.on 'fd', (fd) ->
			server.listenFD fd, 'tcp4'
			console.log "WORKER #{node.id} started"
		comm.resume()

	# master branch
	else

		Object.defineProperty node, 'id', value: 'master'
		Object.defineProperty node, 'isMaster', value: true

		# bind master socket
		socket = netBinding.socket 'tcp4'
		netBinding.bind socket, options.port
		netBinding.listen socket, options.connections or 128
		# attach the server if no workers needed
		server.listenFD socket, 'tcp4' unless options.workers

		# drop privileges
		try
			process.setuid options.uid if options.uid
			process.setgid options.gid if options.gid
		catch err
			console.log 'Sorry, failed to drop privileges'

		# allow to override workers arguments
		args = options.argv or process.argv
		# copy environment
		env = U.extend {}, process.env, options.env or {}

		# array of listening processes
		workers = []

		# create workers
		createWorker = (id) ->
			env._WID_ = id
			[outfd, infd] = netBinding.socketpair()
			# spawn worker process
			worker = spawn args[0], args.slice(1), env, [infd, 1, 2]
			# establish communication channel to the worker
			worker.comm = new net.Stream outfd, 'unix'
			# init respawning
			worker.on 'exit', () ->
				workers[id] = undefined
				createWorker id
			# we can pass some config to worker
			conf = {}
			# pass worker master socket
			worker.comm.write JSON.stringify(conf), 'ascii', socket
			# put worker to the slot
			workers[id] = worker

		createWorker id for id in [0...options.workers]

		# handle signals
		'SIGINT|SIGTERM|SIGKILL|SIGQUIT|SIGHUP|exit'.split('|').forEach (signal) ->
			process.on signal, () ->
				workers.forEach (worker) ->
					try
						worker.kill()
					catch e
						worker.emit 'exit'
				# we use SIGHUP to restart the workers
				process.exit() unless signal is 'exit' or signal is 'SIGHUP'

		# report usage
		unless options.quiet
			console.log "#{options.workers} worker(s) running at http" +
				(if options.sslKey then 's' else '') + "://*:#{options.port}/. Use CTRL+C to stop."

		# start REPL
		if options.repl
			stdin = process.openStdin()
			stdin.on 'close', process.exit
			repl = require('repl').start 'node>', stdin

	process.errorHandler = (err) ->
		# err could be: number, string, instanceof Error, simple object
		# TODO: store exception state under filesystem and emit issue ticket
		#text = '' #err.message or err
		logText = err.stack if err.stack
		sys.debug logText
		text = err.stack if err.stack and settings.debug
		text or 500

	process.on 'uncaughtException', (err) ->
		# http://www.debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb
		console.log 'Caught exception: ' + err.stack
		# respawn workers
		process.kill process.pid, 'SIGHUP'

	# return
	node

#
# JSON-RPC
#
jsonrpc = (context, data) ->
	# N.B. all requests are dispatched using the same object, meaning 'logoff' call doesn't affect later calls
	if data[0]?
		for i, v of data
			unless v and typeof v is 'object'
				return rpcResponseError rpcError(-32600), null
		response = []
		for i, v of data
			resp = dispatch context, v
			# N.B. here we miss legal falsy responses!
			if resp
				response.push resp
		console.log 'COLLECTED', response
		waitAll response
	else if data and typeof data is 'object'
		dispatch context, data

dispatch = (context, request) ->
	# validate request
	if request.jsonrpc isnt '2.0' or
			typeof request.method isnt 'string' or
			request.method.substring(0, 4) is 'rpc.' or
			U.isNaN request.id or
			typeof request.id isnt 'string' and typeof request.id is 'boolean'
		err = -32600
	unless typeof context[request.method] is 'function'
		err = -32601
	# validate and convert params
	if request.params is undefined
		args = []
	else if Array.isArray request.params
		args = request.params
	else if request and typeof request.params is 'object'
		args = [request.params]
	else
		err = -32600

	# bail out if request is invalid
	if err
		return null if request.id is undefined
		error =
			code: err
			message: message or JSONRPC_ERROR_STRINGS[code] or ''
		if data isnt undefined
			error.data = data
		return {
			jsonrpc: '2.0'
			error: error
			id: id
		}

	try
		# invoke the method
		wait context[request.method].apply(context, args), (result) ->
			# if not a notification return the response
			return null if request.id is undefined
			return {
				jsonrpc: '2.0'
				result: result
				id: id
			}
	catch e
		return rpcResponseError rpcError(-32603, null, String(e)), request.id


#
# request handler factory, takes application definition and optional
#   preprocess and postprocess decorators
#
handlerFactory = (app, before, after) ->

	# setup static file server, if any
	if settings.server.static
		staticFileServer = new (require('static/node-static').Server)( settings.server.static.dir, cache: settings.server.static.ttl )

	# setup bare authentication
	User = Store 'User'
	# given the user, return his access level
	getUserLevel = (user) ->
		# settings.server.disabled disables guest or vanilla user interface
		# TODO: watchFile ./down to control settings.server.disabled
		if settings.server.disabled and not settings.security.roots[user.id]
			level = 'none'
		else if settings.security.bypass or settings.security.roots[user.id]
			level = 'root'
		else if user.id and user.type
			level = user.type
		else if user.id
			level = 'user'
		else
			level = 'public'
		level

	# compose faceted handler
	faceted = (req, res) ->

		wid = process.env._WID_

		# process request
		console.log "REQUEST: #{req.method} #{req.url}", req.location, req.params
		Step {test: 'tobedeleted'}, [
			() ->
				# get the user
				uid = req.getSecureCookie 'uid'
				#console.log "GET FOR UID #{uid}"
				return null unless uid
				settings.security.roots[uid] and U.clone(settings.security.roots[uid]) or User.get uid
			(user) ->
				#
				# mixin capabilities
				#
				#console.log "GOT USER", user
				user ?= {}
				level = (app.getUserLevel or getUserLevel)(user)
				level = [level] unless level instanceof Array
				context = Compose.create.apply @, [{}].concat(level.map (x) -> facets[x])
				#console.log 'EFFECTIVE FACET', level, context
				# mixin the user
				Object.defineProperty context, 'user', value: user
				# mixin the request. FIXME: security?
				#Object.defineProperty context, 'req', value: req
				# define session persistence method
				Object.defineProperty context, 'remember', value: (value) ->
					options = path: '/', httpOnly: true
					if value
						#console.log 'SESSSET', value
						# set the cookie
						options.expires = value.expires if value.expires
						res.setSecureCookie 'uid', value.uid, options
					else
						context.user = {}
						#console.log 'SESSKILL'
						res.clearCookie 'uid', options
				#
				# parse the query
				#
				search = req.location.search or ''
				query = parseQuery search
				#console.log 'QUERY', query
				return URIError query.error if query.error
				#
				# find the method which will handle the request
				#
				method = req.method
				path = req.location.pathname
				parts = path.substring(1).split '/'
				data = req.params
				#
				# RPC handler:
				#
				# GET /Foo?query --> getFooList(query)
				# GET /Foo/ID?query --> getFoo(ID, query)
				# POST / {method: M, params: P,...} --> context[M].apply context, P
				# POST /Foo {method: [M, N], params: P,...} --> context.Foo[M][N].apply context, P
				#
				if method is 'GET'
					# GET /Foo?query --> getFooList(query)
					# GET /Foo/ID?query --> getFoo(ID, query)
					# FIXME: parts should be decodeURIComponent'ed
					data =
						jsonrpc: '2.0'
						id: 1
						method: parts.concat 'find'
						params: [query]
					method = 'POST'
				if method is 'POST'
					data.method = parts.concat data.method unless parts[0] is ''
					#'content-type': 'application/json-rpc'
					#r = jsonrpc.handle context, data
					if data.jsonrpc and data.id and data.method
						if data.params is undefined
							args = []
						else if data.params not instanceof Array
							args = [data.params]
						# FIXME: ignore if data.id was already seen?
						# descend into context own properties
						console.log 'DRILL', data
						U.drill(context, data.method).apply context, args
					else
						400
				else
					405
			(response) ->
				console.log "RESPONSE for #{req.url}", response #if response instanceof Error
				# wrap the response in RPC answer
				# if not a notification return the response
				#return {
				#	jsonrpc: '2.0'
				#	result: response
				#	id: id
				#}
				# send the response
				res.send response
				# handle post-process
				app.after response if app.after
				# full stop here
				undefined
			(err) ->
				# here we get if an exception is thrown in previous step
				# FIXME: we should res.send() something
				console.log 'SHOULD NOT HAVE BEEN HERE!', err
				res.send err
		]

	# setup request handler
	handler = (req, res) ->

		# parse the request, leave body alone
		req.parse()

		# allow application to hook some high-load routes
		# the function should return a truthy value to indicate no further processing is needed
		return if app.before and app.before req, res, db

		# serve static files
		# no static file? -> invoke dynamic handler
		if staticFileServer and req.method is 'GET'
			staticFileServer.serve req, res, (err, data) ->
				#console.log "STATIC: #{req.url} == ", err
				faceted req, res if err?.status is 404
		else
			# N.B. damn! if we put this after nextTick() is fired (say, in a callback), we loose data events and thus data
			wait req.parseBody(),
				(parsed) ->
					faceted parsed, res
				(err) ->
					res.send err

	# return the resulting handler
	handler

#
# spawn the farm
#
module.exports.run = (app) ->
	#console.log 'APP', app, facets
	app ?= {}
	createFarm settings.server, handlerFactory app
