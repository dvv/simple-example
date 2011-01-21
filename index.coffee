'use strict'

require.paths.unshift __dirname + '/lib/node'

# TODO: make 'development' come from environment
global.settings = require('./config').development

fs = require 'fs'

run = require('simple').run

schema = {}
model = {}
facets = {}

######################################
################### User
######################################

encryptPassword = (password, salt) ->
	sha1(salt + password + settings.security.secret)

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
		creator:
			type: 'string'
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
			#enum: model.Language.find.bind model.Language
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
				#enum: model.Role.find.bind model.Role

model.User = Model 'User', null, {
	get: Compose.around (base) -> (id) ->
		return null unless id
		settings.security.roots[id] and U.clone(settings.security.roots[id]) or base id
	add: (data) ->
		data ?= {}
		#console.log 'SIGNUP BY', data, @user
		Step @, [
			() ->
				model.User.get data.id
			(user) ->
				#console.log 'USER', user, data
				return user if user instanceof Error
				return SyntaxError 'Cannot create such user' if user
				# create salt, hash salty password
				salt = nonce()
				# generate random pass unless one is specified
				data.password = nonce().substring(0, 7) unless data.password
				console.log 'PASSWORD SET TO', data.password
				password = encryptPassword data.password, salt
				model.User.__proto__.add
					id: data.id
					password: password
					salt: salt
					name: data.name
					email: data.email
					regDate: Date.now() # FIXME: default in schema?
					type: data.type
					# TODO: activation!
					active: data.active
					creator: @user.id
			(user) ->
				return user if user instanceof Error
				#console.log 'NEWUSER', user
				# TODO: password set, notify the user, if email is set
				#if user.email
				#	mail user.email, 'Password set', data.password
				user
		]
	update: Compose.around (base) -> (query, changes) ->
		return URIError 'Please be more specific' unless query
		id = parseQuery(query).normalize().pk
		#return URIError 'Use signup to create new user' unless user.id
		changes = U.veto changes, ['password', 'salt']
		# TODO!!!: limit access rights in changes not higher than of current user
		base query, changes
	login: (data) ->
		#console.log 'LOGIN', arguments, this
		data ?= {}
		wait model.User.get(data.user), (user) =>
			#console.log 'GOT?', user
			if not user
				if data.user
					# invalid user
					console.log 'BAD'
					@remember null
					false
				else
					# log out
					console.log 'LOGOUT'
					@remember null
					true
			else
				if not user.password or not user.active
					# not been activated
					console.log 'INACTIVE'
					@remember null
					false
				else if user.password is encryptPassword data.pass, user.salt
					# log in
					console.log 'LOGIN'
					session =
						uid: user.id
					session.expires = new Date(15*24*60*60*1000 + (new Date()).valueOf()) if data.remember
					@remember session
					session
				else
					console.log 'WRONG'
					@remember null
					false
	getProfile: () ->
		return U.veto @user, ['password', 'salt']
	setProfile: (changes) ->
		changes ?= {}
		console.log 'PROFILECHANGE', changes
		# N.B. have to manually validate here
		# FIXME: BADBADBAD to double schema here
		validation = validatePart changes,
			properties:
				id: schema.User.properties.id
				name: schema.User.properties.name
				email: schema.User.properties.email
		if not validation.valid
			return SyntaxError JSON.stringify validation.errors
		model.User.update Query().eq('id', @user.id), changes
	setPassword: (data) ->
		return TypeError 'Refuse to change the password' unless data.newPassword and data.newPassword is data.confirmPassword and @user.password is encryptPassword data.oldPassword, @user.salt
		# create salt, hash salty password
		changes = {}
		changes.salt = nonce()
		console.log 'PASSWORD SET TO', data.newPassword, @user.id
		changes.password = encryptPassword data.newPassword, changes.salt
		# N.B. we use plain Store method here
		wait model.User.__proto__.update(Query().eq('id', @user.id), changes), (err) ->
			return err if err
			# TODO: password changed, notify the user
			#if @user.email
				#	mail @user.email, 'Password set', data.password
}

defineUserType = (type) -> Compose.create model.User, {
	add: Compose.around (base) -> (data) ->
		data ?= {}
		data.type = type
		base.call @, data
	find: Compose.around (base) -> (query) ->
		q = Query(query).eq('type', type).ne('_deleted', true)
		q = q.eq('creator', @user.id) unless @user.type is 'root'
		base.call @, q
	update: Compose.around (base) -> (query, changes) ->
		changes.type = undefined
		q = Query(query).eq('type', type)
		q = q.eq('creator', @user.id) unless @user.type is 'root'
		base.call @, q, changes
	remove: (query) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		q = q.eq('creator', @user.id) unless @user.type is 'root'
		@update q.eq('type', type), active: false, _deleted: true
}

model.Affiliate = defineUserType 'affiliate'
model.Merchant = defineUserType 'merchant'
model.Admin = defineUserType 'admin'

model.Role = Model 'Role', null, {
}

model.Group = Model 'Group', null, {
}

######################################
################### Misc
######################################

parseXmlFeed = require('simple/remote').parseXmlFeed
model.Course = Model 'Course', null,
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
model.Language = Model 'Language', null, {
}

# custom regions
model.Region = Model 'Region', null, {
}

# currencies available in system
model.Currency = Model 'Currency', null, {
}

# geo info
model.Country = Model 'Country', null, {
}

######################################
################### Tests
######################################

model.Bar = Model 'Bar', null, {
	find: Compose.around (base) ->
		(q) ->
			console.log 'THISINFIND', @
			base q
}

facets.Bar = PermissiveFacet model.Bar, {
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
	getRoot: (query) ->
		s = {}
		for k, v of @
			if typeof v is 'function'
				s[k] = true
			else
				s[k] =
					schema: v.schema
					methods: U.functions v
		user: U.veto(@user, ['password', 'salt']), schema: s
	login: model.User.login
}

FacetForUser = Compose.create FacetForGuest, {
	getProfile: model.User.getProfile
	setProfile: model.User.setProfile
	setPassword: model.User.setPassword
	getCourseList: model.Course.find
}

# root -- hardcoded DB owner
FacetForRoot = Compose.create FacetForUser, {
	Course: PermissiveFacet model.Course,
		schema: schema.Course
	, 'fetch'
	Affiliate: PermissiveFacet model.Affiliate,
		schema: schema.Affiliate
	Merchant: PermissiveFacet model.Merchant,
		schema: schema.Merchant
	Admin: PermissiveFacet model.Admin,
		schema: schema.Admin
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
	getUserList: () ->
		[1,2,3]
	getAffiliateList: (query) ->
		FacetForRoot.Affiliate.find.call @, query
	#createAffiliate: (data) ->
	#	model.User.addNew.call @, U.extend(data or {}, {type: 'affiliate'})
	#createMerchant: (data) ->
	#	model.User.addNew.call @, U.extend(data or {}, {type: 'merchant'})
}

FacetForAffiliate = Compose.create FacetForUser, {
	Affiliate: FacetForRoot.Affiliate
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
FacetForAdmin1 = U.extend {},
	FacetForUser,
	FacetForRoot.Affiliate,
	FacetForRoot.Merchant,
	FacetForRoot.Admin,
	FacetForRoot.Role,
	FacetForRoot.Group,
	FacetForRoot.Course,
	FacetForRoot.Language,
	FacetForRoot.Region,
	FacetForRoot.Country,
	FacetForRoot.Currency

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
		#handler: handler
	}

	# run the application
	run app

# fetch the freshest Courses
#timeout 1000, facets.admin.Course.fetch
