'use strict'

config = require './config'

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
	prototype:
		fetch: (callback) ->
			console.log 'FETCHED'
			callback?()

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
			enum: (value, next) -> model.Region.get value, (err, result) -> next not result
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
				enum: (value, next) -> model.Role.get value, (err, result) -> next not result

schema.Hit =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
			readonly:
				update: true
		name:
			type: 'string'

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
			enum: (value, next) ->
				#console.log 'LANGENUM?', arguments
				model.Language.get value, (err, result) ->
					#console.log 'LANGENUM!', arguments
					next not result
			default: config.defaults.nls
		# .....

#
# admin acting on other users
#
schema.UserAdmin =
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
	prototype:
		signup: (uid) ->
			@add {user: {id: 'trickey'}}, {id: uid}, console.log

#
# any user acting on himself
#
schema.UserSelf =
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

module.exports = schema
