#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

#global.
settings = require('./config').development
#
#
simple = require 'jse'

# define the application
app = Compose.create require('events').EventEmitter, {
	User:
		get: () -> {}
		getLevel: (user) -> 'root'
}

handlers = require 'jse/handler'

#
# security
#
roots = settings.security.roots or {}
getUser = (uid, next) ->
	return next null,
		context:
			Region:
				all: (query, next) ->
					throw SyntaxError 'Catch me!'
					next null, [1,true,new Date()]
	if not uid or roots[uid]
		next null, U.clone roots[uid] or {}
	else
		# TODO: here put db getter
		next()

'''
				#
				# mixin capabilities
				#
				
				level = app.User.getLevel user
				level = [level] unless Array.isArray level
				context = Compose.create.apply null, [{}].concat(level.map (x) -> facets[x])
				#console.log 'EFFECTIVE FACET', level, context
				# mixin the user
				Object.defineProperty context, 'user', value: user
				# mixin the request. FIXME: security?
				#Object.defineProperty context, 'req', value: req
'''

handler = require('stack')(
	handlers.static
		dir: settings.server.static.dir
		ttl: settings.server.static.ttl #('/', __dirname + '/public', 'index.html')
	handlers.mount 'GET', '/foo', (req, res, next) -> res.send 'FOO'
	handlers.mount '/foo1',
		get: (req, res, next) -> res.send 'GETFOO1'
		post: (req, res, next) -> res.send 'POSTFOO1'
	handlers.body()
	handlers.authCookie
		cookie: 'uid'
		secret: settings.security.secret
		getUser: getUser
	handlers.logRequest()
	handlers.jsonrpc()
	#handlers.result()
	#require('creationix/mount')('GET', '/users', function (req, res, next){
	#})
	#require('creationix/auth')({creationix: "hashedpasswordhere"})
)

# run the application
simple.run handler, settings.server
