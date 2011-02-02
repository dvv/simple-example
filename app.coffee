'use strict'

require.paths.unshift __dirname + '/lib/node'

config = require './config'

{Store, SecuredStore, Model, Facet, RestrictiveFacet, PermissiveFacet} = require('jse/store') config.database

#
# helpers to secure particular property definition
# TODO: move to jse/store
#
ro = (attr) ->
	_.extend {}, attr,
		readonly:
			update: true

wo = (attr) ->
	_.extend {}, attr,
		readonly:
			get: true

cr = (attr) ->
	_.extend {}, attr,
		readonly:
			get: true
			update: true

schema = {}
model = {}
facets = {}

######################################
################### SCHEMA
######################################

schema.Language =
	type: 'object'
	additionalProperties: false
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
	additionalProperties: false
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
	additionalProperties: false
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
	additionalProperties: false
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
	additionalProperties: false
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
			enum: (value, next) -> model.Region.get value, (err, result) -> next err
		###
		#currency: {$ref: 'Currency.properties.id'}
		iso2:
			type: 'string'
			minLength: 2
			maxLength: 2
		code:
			type: 'number'
		###

schema.Role =
	type: 'object'
	additionalProperties: false
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
						enum: () -> _.keys model # TODO: should be keys of the context!
					access:
						type: 'integer'
						enum: [0, 1, 2, 3]

schema.Group =
	type: 'object'
	additionalProperties: false
	properties:
		name:
			type: 'string'
		description:
			type: 'string'
		roles:
			type: 'array'
			items:
				type: 'string'
				enum: (value, next) -> model.Role.get value, (err, result) -> next err

#
# User entity
#

UserEntity =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
			readonly:
				update: true
		# ----- authority -----
		type:
			type: 'string'
		rights:
			type: 'any' # so far
			default: ''
		blocked:
			type: 'boolean'
			default: false
		# ----- authentication -----
		password:
			type: 'string'
		salt:
			type: 'string'
		secret:
			type: 'string'
			optional: true
		# ----- profile -----
		name:
			type: 'string'
			optional: true
		email:
			type: 'string'
			pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
			optional: true
		# ----- profile -----
		timezone:
			type: 'string'
			enum: ['UTC-11', 'UTC-10', 'UTC-09', 'UTC-08', 'UTC-07', 'UTC-06', 'UTC-05', 'UTC-04', 'UTC-03', 'UTC-02', 'UTC-01', 'UTC+00', 'UTC+01', 'UTC+02', 'UTC+03', 'UTC+04', 'UTC+05', 'UTC+06', 'UTC+07', 'UTC+08', 'UTC+09', 'UTC+10', 'UTC+11', 'UTC+12']
			default: 'UTC+04'
		lang:
			type: 'string'
			enum: ['en'] # to be filled with model.Language.all()
			default: 'en'
		# .....

###
schemaUser =
	type: 'object'
	properties:
		id: UserEntity.properties.id
		# ----- authority -----
		type: UserEntity.properties.type
		rights: UserEntity.properties.rights
		blocked: UserEntity.properties.blocked
		# ----- authentication -----
		password: UserEntity.properties.password
		salt: UserEntity.properties.salt
		# ----- public profile -----
		name: UserEntity.properties.name
		email: UserEntity.properties.email
		timezone: UserEntity.properties.timezone
		lang: UserEntity.properties.lang
		# ----- private profile -----
		secret: UserEntity.properties.secret
###

#
# admin acting on other users
#
schemaUserAdmin =
	type: 'object'
	properties:
		id: UserEntity.properties.id
		# ----- authority -----
		# type is always readonly
		type: ro UserEntity.properties.type
		# admin can get/set rights
		rights: UserEntity.properties.rights
		# admin can block/unblock users
		blocked: UserEntity.properties.blocked
		# ----- authentication -----
		# admin can set initial values to password/salt
		# TODO: think whether feasible to let only user to change the pass?!
		password: cr UserEntity.properties.password
		salt: cr UserEntity.properties.salt
		# ----- public profile -----
		# admin can read public profile
		name: ro UserEntity.properties.name
		email: ro UserEntity.properties.email
		timezone: ro UserEntity.properties.timezone
		lang: ro UserEntity.properties.lang
		# ----- private profile -----
		# admin cannot access private profile

#
# any user acting on himself
#
schemaUserSelf =
	type: 'object'
	properties:
		id: UserEntity.properties.id
		# ----- authority -----
		# user can read his authority
		type: ro UserEntity.properties.type
		rights: ro UserEntity.properties.rights
		blocked: ro UserEntity.properties.blocked
		# ----- authentication -----
		# user can set his password, but cannot get it
		password: wo UserEntity.properties.password
		salt: wo UserEntity.properties.salt
		# ----- public profile -----
		# user can read/change his public profile
		name: UserEntity.properties.name
		email: UserEntity.properties.email
		timezone: UserEntity.properties.timezone
		lang: UserEntity.properties.lang
		# ----- private profile -----
		# user can read/change his private profile
		secret: UserEntity.properties.secret

#schema.Affiliate = schema.Reseller = schema.Merchant = schema.Admin = _.extend schema.User

######################################
################### MODEL
######################################

# vanilla entities
for id, def of schema
	store = Store id
	model[id] = SecuredStore store, def
	Object.defineProperty model[id], 'schema', value: def
	_.freeze model[id]

# User entity
UserStore = Store 'User'
# facet to fetch the whole User objects
UserAsIs = SecuredStore UserStore
# facet to get/set user's profile
UserSelf = SecuredStore UserStore, schemaUserSelf
# facet to get/set user authority
UserAdmin = SecuredStore UserStore, schemaUserAdmin

#
# nonce
#
crypto = require 'crypto'
nonce = () ->
	(Date.now() & 0x7fff).toString(36) + Math.floor(Math.random()*1e9).toString(36) + Math.floor(Math.random()*1e9).toString(36) + Math.floor(Math.random()*1e9).toString(36) #+ Math.floor(Math.random()*1e9).toString(36)
sha1 = (data, key) ->
	hmac = crypto.createHmac 'sha1', key
	hmac.update data
	hmac.digest 'hex'

#
# hash of power users -- owners of db
#
roots = config.security.roots or {}

#
# password hash function
#
encryptPassword = (password, salt) ->
	sha1(salt + password + config.security.secret)

#
# secure admin accounts
#
for own k, v of roots
	v.salt = nonce()
	v.password = encryptPassword v.password, v.salt


# TODO: add "owned" conditions === .eq('_meta.history.0.who',@user.id) unless root
model.User =

	get: (id, next) ->
		return next null unless id
		isSelf = id is @user?.id
		if roots[id]
			profile = _.clone roots[id]
			validate profile, (if isSelf then schemaUserSelf else schemaUserAdmin), vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
			next null, profile
		else
			(if isSelf then UserSelf else UserAdmin).get.call @, id, next

	query: (query, next) ->
		UserAdmin.query.call @, query, next

	add: (data, next) ->
		data ?= {}
		#console.log 'SIGNUP BY', data, @user
		Next @,
			(err, xxx, step) ->
				step null, (roots[data.id] or null)
			(err, user, step) ->
				#console.log 'USER', user, data
				return step err if err
				return step 'Duplicated' if user
				# create salt, hash salty password
				salt = nonce()
				# generate random pass unless one is specified
				data.password = nonce().substring(0, 7) unless data.password
				password = encryptPassword data.password, salt
				UserAdmin.add.call @, {
					id: data.id
					password: password
					salt: salt
					#name: data.name
					#email: data.email
					type: data.type
				}, step
			(err, user) ->
				#console.log 'ADDUSER', arguments
				return next err if err
				#console.log 'NEWUSER', user
				# TODO: password set, notify the user, if email is set
				if user.email
					console.log 'PASSWORD SET TO', data.password
					#mail user.email, 'Password set', data.password
				next null, user

	update: (query, changes, next) ->
		plainPassword = undefined
		#console.log 'UPDATE', query
		#
		# TODO: validate changes.rights to not contain more than self.rights
		#
		Next @,
			# act as profile manager upon own record
			(err, xxx, step) ->
				profileChanges = _.clone changes
				# password is special
				if profileChanges.password
					plainPassword = String profileChanges.password
					profileChanges.salt = nonce()
					#console.log 'PASSWORD SET TO', profileChanges.password, @user.id
					profileChanges.password = encryptPassword plainPassword, profileChanges.salt
				#console.log 'SELFCHANGE', profileChanges
				#console.log 'UPDATE1', query
				UserSelf.update.call @, _.rql(query).eq('id', @user.id), profileChanges, step
				#console.log 'UPDATE2', query
			# act as admin upon other records
			(err, xxx, step) ->
				#console.log 'OTHERCHANGE', changes
				#console.log 'UPDATE', query
				UserAdmin.update.call @, _.rql(query).ne('id', @user.id), changes, step
			(err) ->
				if plainPassword and @user.email
					console.log 'PASSWORD SET TO', plainPassword
					#	mail @user.email, 'Password set', plainPassword
				next err

	remove: (query, next) ->
		# forbid self-removal
		UserAdmin.remove.call @, _.rql(query).ne('id', @user.id), next

	delete: (query, next) ->
		# forbid self-removal
		UserAdmin.delete.call @, _.rql(query).ne('id', @user.id), next

	undelete: (query, next) ->
		# forbid self-undeletion
		UserAdmin.undelete.call @, _.rql(query).ne('id', @user.id), next

	#
	# profile getter/setter
	#
	# FIXME: needed?
	getProfile: (next) ->
		#console.log 'GETPROFILE for', @user?.id
		UserSelf.get.call @, @user?.id, next
	setProfile: (changes, next) ->
		UserSelf.update.call @, [@user?.id], changes, next

	#
	# try to login the user by credentials in data.user/data.pass
	#
	login: (data, next) ->
		Next @,
			(err, xxx, step) ->
				data ?= {}
				id = data.user
				return step() unless id
				if roots[id]
					step null, _.clone roots[id]
				else
					UserAsIs.get.call @, id, step
			(err, user, step) ->
				#console.log 'GOTUSER!', err, user
				if not user
					if data.user
						# invalid user
						step 'Invalid user'
					else
						# log out
						step null, true
				else
					if not user.password or user.blocked
						# not been activated
						step 'Invalid user'
					else if user.password is encryptPassword data.pass, user.salt
						# log in
						session =
							uid: user.id
						session.expires = new Date(15*24*60*60*1000 + Date.now()) if data.remember
						step null, session
					else
						#console.log 'WRONG'
						step 'Invalid user'
			(err, session) ->
				# save session
				session = err or session
				# TODO: log attempts?
				@remember session, next

	#
	# return capability object given user id
	#
	getContext: (uid, next) ->
		Next @,
			(err, xxx, step) ->
				if not uid or roots[uid]
					step null, _.clone roots[uid]
				else
					UserAsIs.get.call @, uid, step
			(err, user, step) ->
				user ?= {}
				#console.log 'USER', uid, user
				# config.server.disabled disables guest or vanilla user interface
				# TODO: watchFile ./down to control config.server.disabled
				if config.server.disabled and not roots[user.id]
					level = 'none'
				else if config.security.bypass or roots[user.id]
					level = 'root'
				else if user.id and user.type
					level = user.type # N.B. can be an array of levels
				else if user.id
					level = 'user'
				else
					level = 'public'
				level = [level] unless _.isArray level
				# collect capabilities
				context = _.extend.apply null, [{}].concat(level.map (x) -> facets[x])
				# mixin the user
				Object.defineProperty context, 'user', value: _.freeze user
				#console.log 'EFFECTIVE FACET', level, context
				next null, context

# User types
_.each {affiliate: 'Affiliate', merchant: 'Merchant', admin: 'Admin'}, (name, type) ->
	model[name] =
		add: (data, next) ->
			data ?= {}
			data.type = type
			model.User.add.call @, data, next
		update: (query, changes, next) ->
			model.User.update.call @, _.rql(query).eq('type',type), changes, next
		remove: (query, next) ->
			model.User.remove.call @, _.rql(query).eq('type',type), next
		delete: (query, next) ->
			model.User.delete.call @, _.rql(query).eq('type',type), next
		undelete: (query, next) ->
			model.User.undelete.call @, _.rql(query).eq('type',type), next
		query: (query, next) ->
			model.User.query.call @, _.rql(query).eq('type',type), next
		get: (id, next) ->
			model.User.get.call @, id, (err, result) ->
				result = null unless result?.type is type
				next err, result
	Object.defineProperty model[name], 'schema', value: schemaUserAdmin
	_.freeze model[name]

######################################
################### FACETS
######################################

FacetForGuest = _.freeze _.extend {}, {
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
		user = @user
		next null,
			# expose the bare minimum
			user:
				id: user.id
				email: user.email
				type: user.type
			schema: s
			#context: @
	login: model.User.login
}

# user -- authenticated authority
FacetForUser = _.freeze _.extend {}, FacetForGuest, {
	#Profile:
	#	get: model.User.getProfile
	#	set: model.User.setProfile
	getProfile: model.User.getProfile
	setProfile: model.User.setProfile
}

# root -- hardcoded DB owner
FacetForRoot = _.freeze _.extend {}, FacetForUser, {
	Affiliate: PermissiveFacet model.Affiliate
	Merchant: PermissiveFacet model.Merchant
	Admin: PermissiveFacet model.Admin
	Role: PermissiveFacet model.Role
	Group: PermissiveFacet model.Group
	Language: PermissiveFacet model.Language
	Region: PermissiveFacet model.Region
	Country: PermissiveFacet model.Country
	Currency: PermissiveFacet model.Currency
	#Course: PermissiveFacet model.Course, 'fetch'
}

FacetForAffiliate = _.freeze _.extend {}, FacetForUser, {
	# TODO: owned affiliates only
	Affiliate: FacetForRoot.Affiliate
}

FacetForMerchant = _.freeze _.extend {}, FacetForUser, {
}

# admin -- powerful user
FacetForAdmin = _.freeze _.extend {}, FacetForUser, {
	Affiliate: FacetForRoot.Affiliate
	Merchant: FacetForRoot.Merchant
	Admin: FacetForRoot.Admin
	Role: FacetForRoot.Role
	Group: FacetForRoot.Group
	Language: FacetForRoot.Language
	Region: FacetForRoot.Region
	Country: FacetForRoot.Country
	Currency: FacetForRoot.Currency
	#Course: FacetForRoot.Course
}

facets.public = FacetForGuest
facets.user = FacetForUser
facets.root = FacetForRoot

facets.affiliate = FacetForAffiliate
facets.merchant = FacetForMerchant
facets.admin = FacetForAdmin

# TODO: remove from global
#global.model = model
#global.facets = facets

#console.log 'FACET', facets

module.exports =
	getContext: model.User.getContext
