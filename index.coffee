'use strict'

require.paths.unshift __dirname + '/lib/node'

# TODO: make 'development' come from environment
global.settings = require('./config').development

run = require('simple').run

# merge storage
# FIXME: DON'T, OTHERWISE ANYONE CAN GET DB ACCESS!!!
store = require 'simple/store'
global.Store = store.Store
global.Model = store.Model
global.Facet = store.Facet
global.RestrictiveFacet = store.RestrictiveFacet
global.PermissiveFacet = store.PermissiveFacet

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
			pattern: '^[a-zA-Z0-9_]+$'
			readonly:
				update: true
		creator:
			type: 'string'
			readonly:
				update: true
		name:
			type: 'string'
		password:
			type: 'string'
			readonly:
				get: true
				update: true
		salt:
			type: 'string'
			readonly:
				get: true
				update: true
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
		type:
			type: 'string'
			readonly:
				# FIXME: shouldn't be a role?
				update: true
		active:
			type: 'boolean'
		timezone:
			type: 'string'
			enum: ['UTC-11', 'UTC-10', 'UTC-09', 'UTC-08', 'UTC-07', 'UTC-06', 'UTC-05', 'UTC-04', 'UTC-03', 'UTC-02', 'UTC-01', 'UTC+00', 'UTC+01', 'UTC+02', 'UTC+03', 'UTC+04', 'UTC+05', 'UTC+06', 'UTC+07', 'UTC+08', 'UTC+09', 'UTC+10', 'UTC+11', 'UTC+12']
			default: 'UTC+04'
		lang:
			type: 'string'
			enum: ['en'] # to be filled with model.Language.all()
			default: 'en'

schema.SelfUser =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
			readonly:
				add: true
				update: true
		creator:
			type: 'string'
			readonly: true
		name:
			type: 'string'
		password:
			type: 'string'
		salt:
			type: 'string'
		secret:
			type: 'string'
			optional: true
		email: schema.User.properties.email
		regDate:
			type: 'date'
			readonly:
				update: true
		type:
			type: 'string'
			readonly:
				update: true
		active:
			type: 'boolean'
			readonly:
				update: true
		timezone: schema.User.properties.timezone
		lang: schema.User.properties.lang

schema.Language =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
			readonly:
				update: true
		name:
			type: 'string'
		localName:
			type: 'string'

schema.Course =
	type: 'object'
	properties:
		cur:
			type: 'string'
			pattern: '^[A-Z]{3}$'
			readonly:
				update: true
		value:
			type: 'number'
		date:
			type: 'date'

schema.Currency =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[A-Z]{3}$'
			readonly:
				update: true
		value:
			type: 'number'

schema.Region =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[A-Z_]+$'
			readonly:
				update: true
		name:
			type: 'string'

schema.Country =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[A-Z]+$'
			readonly:
				update: true
		name:
			type: 'string'
		region:
			type: 'string'
			enum: () -> model.Region.all()
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
			optional: true
		rights:
			type: 'array'
			items:
				type: 'object'
				properties:
					entity:
						type: 'string'
						enum: [] # to be filled with keys of model
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
				enum: [] # to be filled with all Roles

model.User = Model 'User', {schema: schema.User}, {
	get: (id, next) ->
		return next null unless id
		if settings.security.roots[id]
			next null, _.clone settings.security.roots[id]
		else
			model.User._get null, id, next
	# given the user, return his access level
	getLevel: (user) ->
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
	add: Compose.around (base) -> (data, next) ->
		data ?= {}
		self = @
		console.log 'SIGNUP BY', data, @user
		model.User.get data.id, (err, user) ->
			#console.log 'USER', user, data
			return next err if err
			return next SyntaxError 'Cannot create such user' if user
			# create salt, hash salty password
			salt = nonce()
			# generate random pass unless one is specified
			data.password = nonce().substring(0, 7) unless data.password
			password = encryptPassword data.password, salt
			base.call @, {
				id: data.id
				password: password
				salt: salt
				name: data.name
				email: data.email
				regDate: Date.now() # FIXME: default in schema?
				type: data.type
				# TODO: activation!
				active: data.active
				creator: self.user.id
			}, (err, user) ->
				return next err if err
				#console.log 'NEWUSER', user
				# TODO: password set, notify the user, if email is set
				console.log 'PASSWORD SET TO', data.password
				#if user.email
				#	mail user.email, 'Password set', data.password
				next null, user
	login: (data, next) ->
		#console.log 'LOGIN', arguments, this
		data ?= {}
		self = @
		model.User.get data.user, (err, user) ->
			#console.log 'GOT?', user
			if not user
				if data.user
					# invalid user
					console.log 'BAD'
					self.remember null
					next null, false
				else
					# log out
					console.log 'LOGOUT'
					self.remember null
					next null, true
			else
				if not user.password or not user.active
					# not been activated
					console.log 'INACTIVE'
					self.remember null
					next null, false
				else if user.password is encryptPassword data.pass, user.salt
					# log in
					console.log 'LOGIN'
					session =
						uid: user.id
					session.expires = new Date(15*24*60*60*1000 + (new Date()).valueOf()) if data.remember
					self.remember session
					next null, session
				else
					console.log 'WRONG'
					self.remember null
					next null, false
	getProfile: (next) ->
		next null, _.veto(@user, ['password', 'salt'])
	setProfile: (changes, next) ->
		changes ?= {}
		console.log 'PROFILECHANGE', changes
		# N.B. have to manually validate here
		# FIXME: BADBADBAD to double schema here
		#validation = validatePart changes,
		#	properties:
		#		id: schema.User.properties.id
		#		name: schema.User.properties.name
		#		email: schema.User.properties.email
		#if not validation.valid
		#	return next SyntaxError JSON.stringify validation.errors
		model.User.update Query().eq('id', @user.id), changes, next
	setPassword: (data, next) ->
		return next TypeError 'Refuse to change the password' unless data.newPassword and data.newPassword is data.confirmPassword and @user.password is encryptPassword data.oldPassword, @user.salt
		# create salt, hash salty password
		changes = {}
		changes.salt = nonce()
		console.log 'PASSWORD SET TO', data.newPassword, @user.id
		changes.password = encryptPassword data.newPassword, changes.salt
		# N.B. we use plain Store method here
		model.User._update null, Query().eq('id', @user.id), changes, (err) ->
			return next err if err
			# TODO: password changed, notify the user
			#if @user.email
				#	mail @user.email, 'Password set', data.password
			next null
}

defineUserType = (type) -> Compose.create model.User, {
	add: Compose.around (base) -> (data, next) ->
		data ?= {}
		data.type = type
		base.call @, data, next
	all: Compose.around (base) -> (query, next) ->
		q = Query(query).eq('type', type).ne('_deleted', true)
		q = q.eq('creator', @user.id) unless @user.type is 'root'
		base.call @, q, next
	update: Compose.around (base) -> (query, changes, next) ->
		#changes.type = undefined
		q = Query(query).eq('type', type)
		q = q.eq('creator', @user.id) unless @user.type is 'root'
		base.call @, q, changes, next
	remove: Compose.around (base) -> (query, next) ->
		q = Query(query)
		throw TypeError 'Please, be more specific' unless q.args.length
		q = q.eq('creator', @user.id) unless @user.type is 'root'
		base.call @, q.eq('type', type), {active: false, _deleted: true}, next
}

model.Affiliate = defineUserType 'affiliate'
model.Merchant = defineUserType 'merchant'
model.Admin = defineUserType 'admin'

model.Role = Model 'Role', {schema: schema.Role}, {
	add: Compose.around (base) -> (doc, next) ->
		base.call @, doc, (err, role) ->
			model.Role.all '', (err, roles) ->
				schema.Group.properties.roles.items.enum = roles
			next err, role
	update: Compose.around (base) -> (query, changes, next) ->
		console.log 'UPDATEDROLES?', arguments
		base.call @, query, changes, (err, role) ->
			console.log 'UPDATEDROLES!', arguments
			model.Role.all '', (err, roles) ->
				console.log 'UPDATEDROLES!!!!', arguments
				schema.Group.properties.roles.items.enum = roles
			next err
	remove: Compose.around (base) -> (query, next) ->
		base.call @, query, (err, role) ->
			model.Role.all '', (err, roles) ->
				schema.Group.properties.roles.items.enum = roles
			next err
}

model.Group = Model 'Group', {schema: schema.Group}, {
}

######################################
################### Misc
######################################

parseXmlFeed = require('simple/remote').parseXmlFeed
model.Course = Model 'Course', {schema: schema.Course},
	fetch: (next) ->
		console.log 'FETCHING'
		wait parseXmlFeed("http://xurrency.com/#{settings.defaults.currency}/feed"), (data) =>
			# TODO: only CHANGES should be added
			now = Date.now()
			@add cur: settings.defaults.currency.toUpperCase(), value: 1.0, date: now
			data.item?.forEach (x) =>
				@add cur: x['dc:targetCurrency'], value: parseFloat(x['dc:value']['#']), date: now
			console.log 'FETCHED'
			next null, true
			#delay 3000, model.Course.fetch.bind(model.Course)
	add: Compose.around (base) -> (props, next) ->
		props ?= {}
		props.date = Date.now()
		base.call @, props, next
	update: Compose.around (base) -> (query, changes, next) ->
		changes ?= {}
		changes.date = Date.now()
		base.call @, query, changes, next
	all: Compose.around (base) -> (query, next) ->
		base.call @, '', (err, result) ->
			#console.log 'R', result
			latest = U(result).chain().reduce((memo, item) ->
				id = item.cur
				memo[id] = item if not memo[id] or item.date > memo[id].date
				memo
			, {}).toArray().value()
			found = _.query latest, query
			found = found[0] or null if Query(query).normalize().pk
			next null, found

# languages available in system
model.Language = Model 'Language', {schema: schema.Language}, {
}

# custom regions
model.Region = Model 'Region', {schema: schema.Region}, {
}

# currencies available in system
model.Currency = Model 'Currency', {schema: schema.Currency}, {
}

# geo info
model.Country = Model 'Country', {schema: schema.Country}, {
}

######################################
################### FACETS
######################################

FacetForGuest = Compose.create {}, {
	getRoot: (query, next) ->
		s = {}
		#console.log 'ROOT', @
		for k, v of @
			if typeof v is 'function'
				s[k] = true
			else
				s[k] =
					schema: v.schema
					methods: _.functions v
		next null, {user: _.veto(@user, ['password', 'salt']), schema: s}
	login: model.User.login
}

FacetForUser = Compose.create FacetForGuest, {
	getProfile: model.User.getProfile
	setProfile: model.User.setProfile
	setPassword: model.User.setPassword
	getCourseList: model.Course.all
}

# root -- hardcoded DB owner
FacetForRoot = Compose.create FacetForUser, {
	Course: PermissiveFacet model.Course, 'fetch'
	Affiliate: PermissiveFacet model.Affiliate
	Merchant: PermissiveFacet model.Merchant
	Admin: PermissiveFacet model.Admin
	Role: PermissiveFacet model.Role
	Group: PermissiveFacet model.Group
	Language: PermissiveFacet model.Language
	Region: PermissiveFacet model.Region
	Country: PermissiveFacet model.Country
	Currency: PermissiveFacet model.Currency
	getUserList: (next) ->
		next null, [1,2,3]
	getAffiliateList: (query, next) ->
		FacetForRoot.Affiliate.all.call @, query, next
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
FacetForAdmin1 = _.extend {},
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

	# fill up variable enumerations
	schema.Role.properties.rights.items.properties.entity.enum = _.keys model
	model.Role.all 'values(name)', (err, roles) -> schema.Group.properties.roles.items.enum = _.pluck roles, 'name'
	model.Language.all 'values(name)', (err, langs) -> schema.User.properties.lang.enum = _.pluck langs, 'name'
	model.Region.all 'values(name)', (err, result) -> schema.Country.properties.region.enum = _.pluck result, 'id'

	# define the application
	app = Compose.create require('events').EventEmitter, {
		User: model.User
		#handler: handler
	}

	# run the application
	run app

# fetch the freshest Courses
#timeout 1000, facets.admin.Course.fetch
