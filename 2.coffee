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
			workers: 0 #os.cpus().length
			#uid: 65534
			#gid: 65534
			#pwd: './secured-root'
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
					secret: '321'
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
for own k, v of roots
	v.salt = nonce()
	v.password = encryptPassword v.password, v.salt

#
# load application
#
# FIXME: should it expose schema and model?!
#
{schema, model, facets} = require('./app') settings



PermissiveFacet = (x) -> x
RestrictiveFacet = (x) -> x


######################################
################### FACETS
######################################

FacetForGuest = Compose.create {}, {
	login123: (data, next) ->
		self = @
		Step(
			() ->
				data ?= {}
				id = data.user
				return null unless id
				if roots[id]
					return _.clone roots[id]
				else if model.User
					model.User.get id, @
				else
					null
			(err, user) ->
				#console.log 'GOTUSER!', user
				if not user
					if data.user
						# invalid user
						#console.log 'BAD'
						false
					else
						# log out
						#console.log 'LOGOUT'
						true
				else
					if not user.password or not user.active
						# not been activated
						#console.log 'INACTIVE'
						false
					else if user.password is encryptPassword data.pass, user.salt
						# log in
						#console.log 'LOGIN'
						session =
							uid: user.id
						session.expires = new Date(15*24*60*60*1000 + Date.now()) if data.remember
						session
					else
						#console.log 'WRONG'
						false
			(err, session) ->
				# save session
				session = false if err
				#if session and session isnt true
				# TODO: log attempts?
				self.remember session, next
		)
	getRoot: (query, next) ->
		s = {}
		#console.log 'ROOT', @
		for own k, v of @
			if typeof v is 'function'
				s[k] = true
			else if v.schema
				#console.log k, v
				s[k] =
					schema: v.schema
					methods: _.functions v
		next null,
			user: _.veto @user, ['password', 'salt']
			schema: s
}

# user -- authenticated authority
FacetForUser = Compose.create FacetForGuest, {
}

# root -- hardcoded DB owner
FacetForRoot = Compose.create FacetForUser, {
	#Course: PermissiveFacet model.Course, 'fetch'
	Affiliate: PermissiveFacet model.Affiliate
	Merchant: PermissiveFacet model.Merchant
	Admin: PermissiveFacet model.Admin
	Role: PermissiveFacet model.Role
	Group: PermissiveFacet model.Group
	Language: PermissiveFacet model.Language
	Region: PermissiveFacet model.Region
	Country: PermissiveFacet model.Country
	Currency: PermissiveFacet model.Currency
}

FacetForAffiliate = Compose.create FacetForUser, {
	#Affiliate: FacetForRoot.Affiliate
}

FacetForMerchant = Compose.create FacetForUser, {
}

# admin -- powerful user
FacetForAdmin = Compose.create FacetForUser, {
	Affiliate: FacetForRoot.Affiliate
	Merchant: FacetForRoot.Merchant
	Admin: FacetForRoot.Admin
	Role: FacetForRoot.Role
	Group: FacetForRoot.Group
	Course: FacetForRoot.Course
	Language: FacetForRoot.Language
	Region: FacetForRoot.Region
	Country: FacetForRoot.Country
	Currency: FacetForRoot.Currency
}

facets.public = FacetForGuest
facets.user = FacetForUser
facets.root = FacetForRoot

facets.affiliate = FacetForAffiliate
facets.merchant = FacetForMerchant
facets.admin = FacetForAdmin

# TODO: remove from global
global.model = model
global.facets = facets


console.log 'FACET', facets

#onevent 'update', () ->
#	console.log 'EVENTUPDATE', arguments

#
# return capability object given user id
#
getContext = (uid, next) ->
	Step(
		() ->
			if not uid or roots[uid]
				return _.clone roots[uid]
			else if model.User
				model.User.get id, @
			else
				null
		(err, user) ->
			user ?= {}
			# settings.server.disabled disables guest or vanilla user interface
			# TODO: watchFile ./down to control settings.server.disabled
			if settings.server.disabled and not roots[user.id]
				level = 'none'
			else if settings.security.bypass or roots[user.id]
				level = 'root'
			else if user.id and user.type
				level = user.type # N.B. can be an array of levels
			else if user.id
				level = 'user'
			else
				level = 'public'
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
	simple.handlers.mount '/foo1',
		get: (req, res, next) -> res.send 'GETFOO1'
		post: (req, res, next) -> res.send 'POSTFOO1'
	#simple.handlers.body
	#	uploadDir: settings.upload.dir
	simple.handlers.authCookie
		cookie: 'uid'
		secret: settings.security.secret
		getContext: getContext
	#simple.handlers.mount 'GET', '/home', (req, res, next) ->
	#	res.send 'FOO'
	#simple.handlers.jsonBody
	#	maxLength: 0 # set to >0 to limit the number of bytes
	simple.handlers.logRequest()
	simple.handlers.jsonrpc
		maxBodyLength: 0 # set to >0 to limit the number of bytes
)

# run the application
simple.run handler, settings.server

#
# tests
#

###
model.User.query.call({user:{id:'root'}},'',console.log)
model.User.update.call({user:{id:'root'}},'id=a1',{password:123},console.log)
###

#
# tests if doc created by user, or user creator
#
ownedBy = (doc, user, next) ->
	who = doc?._meta?.history[0].who
	console.log 'OWNED?', doc, user?.id
	if who is user?.id
		return next null, user
	model.User._get who, (err, parent) ->
		#console.log 'PARENT', arguments
		return next err, parent unless parent
		ownedBy parent, user, next


assert = require 'assert'
'''
Step(
	() ->
		console.log 'Fetching AAC'
		model.Region._get 'AAC', @
		return
	(err, result) ->
		console.log arguments
		assert.equal result.id, 'AAC'
		console.log 'Checking if AAC owned by root'
		ownedBy result, roots.root, @
		return
	(err, result) ->
		console.log 'OWNED', arguments
)
'''
'''
Step(
	() ->
		console.log 'Resetting collection'
		model.Language.delete '__nonexistent!=true', @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, null, 'remove ok'
		console.log 'Adding an empty document'
		model.Language.add {}, @
		return
	(err, result) ->
		console.log arguments
		assert.notEqual err, null, 'add empty nak'
		assert.equal result, null, 'add empty nak'
		console.log 'Adding a document'
		model.Language.add {id: 'RUS', name: 'Russian', localName: 'Русский', foo: 'bar'}, @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, null, 'add ok'
		assert.equal result.id, 'RUS', 'id is set'
		assert.equal result.foo, null, 'no additional props'
		console.log 'Querying all documents'
		model.Language.query '', @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.length, 1
		console.log 'Adding duplicate ID'
		model.Language.add {id: 'RUS', name: 'Russian', localName: 'Русский', foo: 'bar'}, @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, 'Duplicated'
		assert.equal result, null
		console.log 'Adding another document'
		model.Language.add {id: 'ENG', name: 'English', localName: 'English', _meta: {history: 'tainted'}}, @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.id, 'ENG', 'id is set'
		assert.equal result._meta, null, 'no additional props'
		console.log 'Updating localName'
		model.Language.update _.rql().eq('id', 'RUS'), {name: 'Russkiy', localName: 'Рашн'}, @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result, null
		console.log 'Getting RUS'
		model.Language.get 'RUS', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.deepEqual result, {id: 'RUS', name: 'Russkiy', localName: 'Рашн'}
		console.log 'Removing RUS'
		model.Language.remove 'id=RUS', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result, null
		console.log 'Counting 1'
		model.Language.query '', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.length, 1
		console.log 'Undeleting'
		model.Language.undelete '', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result, null
		console.log 'Counting 2'
		model.Language.query '', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.length, 2
		console.log 'Deleting'
		model.Language.delete 'i!=1', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result, null
		console.log 'Counting 3'
		model.Language.query '', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.length, 0
		console.log 'Finishing'
	(err, result) ->
		console.log arguments
		#process.exit 0
)
'''
