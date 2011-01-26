#!/usr/local/bin/coffee
'use strict'

# FIXME: coffee workaround
process.argv[0] = process.argv[1]
process.argv[1] = __filename

require.paths.unshift __dirname + '/lib/node'

#
# settings
#
os = require 'os'
config =
	development:
		server:
			port: 3000
			workers: os.cpus().length
			uid: 65534
			#sslKey: 'key.pem'
			#sslCert: 'cert.pem'
			repl: true
			static:
				dir: 'public'
				ttl: 3600
			stackTrace: true
		security:
			#bypass: true
			secret: 'change-me-on-production-server'
			roots:
				root:
					id: 'root'
					email: 'place-admin@here.com'
					password: '123'
					type: 'root'
					active: true
		database:
			url: 'mongodb://127.0.0.1/simple'
			filterBy: 'active'
			hardLimit: 100
		upload:
			dir: 'upload'
		defaults:
			nls: 'en'
			currency: 'usd'

#
#
#
settings = config.development

#
#
#
simple = require 'jse'

#############################
#
# security
#
#############################

#
# hash of power users -- owners of db
#
roots = settings.security.roots or {}

#
# password hash function
#
encryptPassword = (password, salt) ->
	sha1(salt + password + settings.security.secret)

#
# secure admin accounts
#
for k, v of roots
	v.salt = nonce()
	v.password = encryptPassword v.password, v.salt

#
# return capability object given user id
#
#{schema, model, facets} = require './app'

{Store, applySchema, onevent} = require('jse/store') settings.database
global.Store = Store
global.applySchema = applySchema

#
#
#
# TODO: extract schemas
# TODO: extract vanilla models
# TODO: extract User and all its flavors
# TODO: User should be _manually_ coded, given https://docs2.google.com/document/d/1g5t-eQbbis_cYeddp4PcTJ7CUGNpzudJ8b1Q1EWLkms/edit?hl=ru# considerations
#
#
#

schema = require './schema'
model = {}
facets =
	root: {}

# vanilla entities
for id, def of schema
	store = Store(id)
	model[id] = applySchema store, def
	facets.root[id] = model[id]

onevent 'update', () ->
	console.log 'EVENTUPDATE', arguments

#model.User = applySchema Store('User'), schema.User

# TODO: remove from global
global.model = model
global.facets = facets

getContext = (uid, next) ->
	# FIXME: remove
	uid = 'root'
	Step(
		() ->
			if not uid or roots[uid]
				return U.clone roots[uid]
			else
				# TODO: here put db getter
				this()
		(err, user) ->
			user ?= {}
			#level = app.User.getLevel user
			level = 'root'
			level = [level] unless Array.isArray level
			# collect capabilities
			context = Compose.create.apply null, [{foo: 'bar'}].concat(level.map (x) -> facets[x])
			# mixin the user
			Object.defineProperty context, 'user', value: user
			#console.log 'EFFECTIVE FACET', level, context
			next null, context
	)

#############################
#
# middleware stack
#
#############################

handler = require('stack')(
	simple.handlers.static
		dir: settings.server.static.dir
		ttl: settings.server.static.ttl
	simple.handlers.mount 'GET', '/foo', (req, res, next) -> res.send 'FOO'
	simple.handlers.mount '/foo1',
		get: (req, res, next) -> res.send 'GETFOO1'
		post: (req, res, next) -> res.send 'POSTFOO1'
	#simple.handlers.body
	#	uploadDir: settings.upload.dir
	simple.handlers.authCookie
		cookie: 'uid'
		secret: settings.security.secret
		getContext: getContext
	#simple.handlers.jsonBody
	#	maxLength: 0 # set to >0 to limit the number of bytes
	simple.handlers.logRequest()
	simple.handlers.jsonrpc
		maxBodyLength: 0 # set to >0 to limit the number of bytes
)

# run the application
simple.run handler, settings.server
