'use strict'

require.paths.unshift __dirname + '/lib/node'

# TODO: make 'development' come from environment
global.settings = require('./config').development
#Object.defineProperty global, 'settings',
#	get: () -> settings

fs = require 'fs'

run = require('simple').run
store = require 'simple/store'
Store = store.Store
Model = store.Model
Facet = store.Facet
RestrictiveFacet = store.RestrictiveFacet
PermissiveFacet = store.PermissiveFacet

schema = {}
model = {}
facets = {}

######################################
################### User
######################################

encryptPassword = (password, salt) ->
	sha1(salt + password + settings.security.secret)

# given the user, return his capabilities
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

# secure admin accounts
for k, v of settings.security.roots
	v.salt = nonce()
	v.password = encryptPassword v.password, v.salt

schema.User = schema.Affiliate = schema.Reseller = schema.Merchant = schema.Admin =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '[a-zA-Z0-9_]+'
		name:
			type: 'string'
		password:
			type: 'string'
			readonly: true
		salt:
			type: 'string'
			readonly: true
		secret:
			type: 'string'
			readonly: true
			optional: true
		email:
			type: 'string'
			pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
		regDate:
			type: 'date'
			readonly:
				update: true
			optional:
				add: true
		type:
			type: 'string'
			readonly:
				# FIXME: shouldn't be a role?
				update: true
			optional:
				add: true
		active:
			type: 'boolean'
		timezone:
			type: 'string'
			enum: ['UTC-11', 'UTC-10', 'UTC-09', 'UTC-08', 'UTC-07', 'UTC-06', 'UTC-05', 'UTC-04', 'UTC-03', 'UTC-02', 'UTC-01', 'UTC+00', 'UTC+01', 'UTC+02', 'UTC+03', 'UTC+04', 'UTC+05', 'UTC+06', 'UTC+07', 'UTC+08', 'UTC+09', 'UTC+10', 'UTC+11', 'UTC+12']
			default: 'UTC+04'
		lang:
			type: 'string'
			enum: () -> model.Language.find()
			default: 'en'

schema.Language =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '[a-zA-Z0-9_]+'
		name:
			type: 'string'
		localName:
			type: 'string'

schema.Course =
	type: 'object'
	properties:
		cur:
			type: 'string'
			pattern: '[A-Z]{3}'
		value:
			type: 'number'
		date:
			type: 'date'

schema.Currency =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '[A-Z]{3}'
		value:
			type: 'number'

schema.Region =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '[A-Z_]+'
		name:
			type: 'string'

schema.Country =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '[A-Z]+'
		name:
			type: 'string'
		region:
			type: 'string'
			enum: () -> model.Region.find()
		#currency: {$ref: 'Currency.properties.id'}
		#iso2: {type: 'string', minLength: 2, maxLength: 2}
		#code: {type: 'number'}

schema.Role =
	type: 'object'
	properties:
		name:
			type: 'string'
		description:
			type: 'string'
		rights:
			type: 'array'
			items:
				type: 'object'
				properties:
					entity:
						type: 'string'
						enum: () -> U.keys model
					access:
						type: 'integer'
						enum: [0, 1, 2, 3]
schema.Group =
	type: 'object'
	properties:
		name:
			type: 'string'
		description:
			type: 'string'
		roles:
			type: 'array'
			items:
				type: 'string'
				enum: () -> model.Role.find

model.User = Model 'User', Store('User'),
	get: (id) ->
		return null unless id
		settings.security.roots[id] and U.clone(settings.security.roots[id]) or @__proto__.get id
	add: (data) ->
		data ?= {}
		console.log 'SIGNUP', data
		Step @, [
			() ->
				@get data.id
			(user) ->
				#console.log 'USER', user
				return user if user instanceof Error
				return SyntaxError 'Cannot create such user' if user
				# TODO: password set, notify the user
				# TODO: notify only if added OK!
				# create salt, hash salty password
				salt = nonce()
				# generate random pass unless one is specified
				data.password = nonce().substring(0, 7) unless data.password
				console.log 'PASSWORD SET TO', data.password
				password = encryptPassword data.password, salt
				@__proto__.add
					id: data.id
					password: password
					salt: salt
					name: data.name
					email: data.email
					regDate: Date.now() # FIXME: default in schema?
					type: data.type
					# TODO: activation!
					active: data.active
					#creator: session?.user?.id or U.keys(settings.security.roots)[0]
			(user) ->
				#console.log 'USER', user
				user
		]
	update: (query, changes) ->
		return URIError 'Please be more specific' unless query
		id = parseQuery(query).normalize().pk
		#return URIError 'Use signup to create new user' unless user.id
		changes = U.veto changes, ['password', 'salt']
		# TODO!!!: limit access rights in changes not higher than of current user
		@__proto__.update query, changes
	login: (data, context) ->
		#console.log 'LOGIN', arguments
		data ?= {}
		wait @get(data.user), (user) =>
			#console.log 'GOT?', user
			if not user
				if data.user
					# invalid user
					#console.log 'BAD'
					context.save null
					false
				else
					# log out
					#console.log 'LOGOUT'
					context.save null
					true
			else
				if not user.password or not user.active
					# not been activated
					#console.log 'INACTIVE'
					context.save null
					false
				else if user.password is encryptPassword data.pass, user.salt
					# log in
					#console.log 'LOGIN'
					session =
						id: nonce()
						uid: user.id
					session.expires = new Date(15*24*60*60*1000 + (new Date()).valueOf()) if data.remember
					context.save session
					session
				else
					context.save null
					false
	profile: (changes, session, method) ->
		if method is 'GET'
			return U.veto session.user, ['password', 'salt']
		data ?= {}
		console.log 'PROFILECHANGE', changes
		# N.B. have to manually validate here
		# FIXME: BADBADBAD to double schema here
		validation = validatePart changes or {},
			properties:
				id: schema.User.properties.id
				name: schema.User.properties.name
				email: schema.User.properties.email
		if not validation.valid
			return SyntaxError JSON.stringify validation.errors
		@update "id=#{session.user.id}", changes
	passwd: (data, session, method) ->
		return TypeError 'Refuse to change the password' unless data.newPassword and data.newPassword is data.confirmPassword and session.user.password is encryptPassword data.oldPassword, session.user.salt
		# TODO: password changed, notify the user
		# TODO: notify only if changed OK!
		# create salt, hash salty password
		changes = {}
		changes.salt = nonce()
		console.log 'PASSWORD SET TO', data.newPassword
		changes.password = encryptPassword data.newPassword, changes.salt
		@__proto__.update "id=#{session.user.id}", changes

model.Affiliate = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'affiliate'
		@__proto__.add data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'affiliate').ne('_deleted', true)
	update: (query, changes) ->
		changes.type = undefined
		@__proto__.update Query(query).eq('type', 'affiliate'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@update q.eq('type', 'affiliate'), active: false, _deleted: true
}

model.Reseller = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'affiliate'
		@__proto__.add data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'affiliate').ne('_deleted', true)
	update: (query, changes) ->
		changes.type = undefined
		@__proto__.update Query(query).eq('type', 'affiliate'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@update q.eq('type', 'affiliate'), active: false, _deleted: true
	addSub: (data, session) ->
		data ?= {}
		data.type = 'affiliate'
		data.parent = session.user.id
		@__proto__.add data
	findSub: (data, session, method, query) ->
		@__proto__.find Query(query).eq('type', 'affiliate').ne('_deleted', true).eq('parent', session.user.id)
	updateSub: (data, session, method, query) ->
		data.type = undefined
		@__proto__.update Query(query).eq('type', 'affiliate').eq('parent', session.user.id), data
	removeSub: (data, session, method, query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@update q.eq('type', 'affiliate').eq('parent', session.user.id), active: false, _deleted: true
}

model.Merchant = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'merchant'
		@__proto__.add data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'merchant').ne('_deleted', true)
	update: (query, changes) ->
		# veto some changes
		changes.type = undefined
		@__proto__.update Query(query).eq('type', 'merchant'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@update q.eq('type', 'merchant'), active: false, _deleted: true
}

model.Admin = Compose.create model.User, {
	add: (data) ->
		data ?= {}
		data.type = 'admin'
		@__proto__.add data
	find: (query) ->
		@__proto__.find Query(query).eq('type', 'admin').ne('_deleted', true)
	update: (query, changes) ->
		# veto some changes
		changes.type = undefined
		@__proto__.update Query(query).eq('type', 'admin'), changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		@update q.eq('type', 'admin'), active: false, _deleted: true
}

model.Role = Model 'Role', Store('Role'), {
}

model.Group = Model 'Group', Store('Group'), {
}

model.Session = Model 'Session', Store('Session'), {
	# look for a saved session, attach .save() helper
	lookup: (req, res) ->
		sid = req.getSecureCookie 'sid'
		Step {}, [
			() ->
				#console.log "GET FOR SID #{sid}"
				model.Session.get sid
			(session) ->
				#console.log "GOT FOR SID #{sid}", session
				@session = session or {}
				model.User.get @session.uid
			(user) ->
				#console.log "GOT USER", user
				@session.user = user or {}
				#console.log "SESSIN!#{sid}", @session
				@session.save = (value) ->
					#console.log 'SESSOUT' + sid, value
					options = path: '/', httpOnly: true
					if value
						# store new session and set the cookie
						sid = value.id
						options.expires = value.expires if value.expires
						#console.log 'MAKESESS', value
						# N.B. we don't wait here, so value will be spoiled id -> _id
						model.Session.add U.clone value
						res.setSecureCookie 'sid', sid, options
					else
						# remove the session and the cookie
						#console.log 'REMOVESESS', @
						model.Session.remove id: sid
						res.clearCookie 'sid', options
				level = getUserLevel @session.user
				#context = facets[level] or {}
				level = [level] unless level instanceof Array
				context = Compose.create.apply null, [{}].concat(level.map (x) -> facets[x])
				#console.log 'EFFECTIVE FACET', level, context
				Object.freeze Compose.call @session, context: context
		]
}

######################################
################### Misc
######################################

parseXmlFeed = require('simple/remote').parseXmlFeed
model.Course = Model 'Course', Store('Course'),
	fetch: () ->
		console.log 'FETCHING'
		deferred = defer()
		wait parseXmlFeed("http://xurrency.com/#{settings.defaults.currency}/feed"), (data) =>
			now = Date.now()
			@add cur: settings.defaults.currency.toUpperCase(), value: 1.0, date: now
			data.item?.forEach (x) =>
				@add cur: x['dc:targetCurrency'], value: parseFloat(x['dc:value']['#']), date: now
			deferred.resolve true
			console.log 'FETCHED'
			#delay 3000, model.Course.fetch.bind(model.Course)
		deferred.promise
	add: (props) ->
		props ?= {}
		props.date = Date.now()
		@__proto__.add props
	update: (query, changes) ->
		changes ?= {}
		changes.date = Date.now()
		@__proto__.update query, changes
	find: (query) ->
		wait @__proto__.find(), (result) ->
			#console.log 'R', result
			latest = U(result).chain().reduce((memo, item) ->
				id = item.cur
				memo[id] = item if not memo[id] or item.date > memo[id].date
				memo
			, {}).toArray().value()
			found = U.query latest, query
			found = found[0] or null if Query(query).normalize().pk
			found

# languages available in system
model.Language = Model 'Language', Store('Language'), {
}

# custom regions
model.Region = Model 'Region', Store('Region'), {
}

# currencies available in system
model.Currency = Model 'Currency', Store('Currency'), {
}

# geo info
model.Country = Model 'Country', Store('Country'), {
}

######################################
################### Tests
######################################

model.Bar = Model 'Bar', Store('Bar'), {
}
model.Bar = PermissiveFacet model.Bar, {
	schema:
		type: 'object'
		properties:
			v:
				type: 'string'
				readonly:
					add: true
					get: true
			test:
				type: 'string'
				readonly:
					update: true
}

######################################
################### FACETS
######################################

FacetForGuest = Compose.create {}, {
	home: (data, session) ->
		s = {}
		for k, v of session.context
			if typeof v is 'function'
				s[k] = true
			else
				s[k] =
					schema: v.schema
					# TODO: don't define unless method exposed
					methods:
						add: not not v.add
						update: not not v.update
						remove: not not v.remove
		user: U.veto(session.user, ['password', 'salt']), schema: s
	login: model.User.login.bind model.User
}

FacetForUser = Compose.create FacetForGuest, {
	profile: model.User.profile.bind model.User
	passwd: model.User.passwd.bind model.User
	Course: RestrictiveFacet model.Course,
		schema: schema.Course
}

# root -- hardcoded DB owner
FacetForRoot = Compose.create FacetForUser, {
	Course: PermissiveFacet model.Course,
		schema: schema.Course
	, 'fetch'
	Affiliate: PermissiveFacet model.Affiliate,
		schema: schema.Affiliate
		veto:
			get: ['password', 'salt']
	Merchant: PermissiveFacet model.Merchant,
		schema: schema.Merchant
		veto:
			get: ['password', 'salt']
	Admin: PermissiveFacet model.Admin,
		schema: schema.Admin
		veto:
			get: ['password', 'salt']
	Role: PermissiveFacet model.Role,
		schema: schema.Role
	Group: PermissiveFacet model.Group,
		schema: schema.Group
	Language: PermissiveFacet model.Language,
		schema: schema.Language
	Region: PermissiveFacet model.Region,
		schema: schema.Region
	Country: PermissiveFacet model.Country,
		schema: schema.Country
	Currency: PermissiveFacet model.Currency,
		schema: schema.Currency
}

FacetForAffiliate = Compose.create FacetForUser, {
	Affiliate: PermissiveFacet model.Affiliate,
		schema: schema.Affiliate
	Affiliate1: Facet model.Affiliate,
		schema: schema.Affiliate
	, [['addSub', 'add'], ['findSub', 'find'], ['updateSub', 'update'], ['removeSub', 'remove']]
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

############################

wait waitAllKeys(model), () ->

	# define the application
	app = Compose.create require('events').EventEmitter, {
		getSession: (req, res) -> model.Session.lookup(req, res)
		#handler: handler
	}

	# run the application
	run app

# fetch the freshest Courses
#timeout 1000, facets.admin.Course.fetch
