'use strict'

config = require './config'

#
# helpers to secure particular property definition
# TODO: move to jse/store
#
ro = (attr) ->
	_.extend {}, attr,
		veto:
			update: true

wo = (attr) ->
	_.extend {}, attr,
		veto:
			get: true

cr = (attr) ->
	_.extend {}, attr,
		veto:
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
			veto:
				update: true
		name:
			type: 'string'
		localName:
			type: 'string'
	prototype:
		fetch: (callback) ->
			console.log 'FETCHED'
			callback?()

schema.Geo =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
			pattern: /^[A-Z]{2}$/
			veto:
				update: true
		name:
			type: 'string'
		iso3:
			type: 'string'
			pattern: /^[A-Z]{3}$/
		code:
			type: 'string'
			pattern: /^[0-9]{3}$/
		cont:
			type: 'string'
			default: 'SA'
			pattern: /^[A-Z]{2}$/
		tz:
			type: 'array'
			optional: true
			items:
				type: 'string'
				pattern: /^UTC/

schema.Currency =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
			pattern: /^[A-Z]{3}$/
			veto:
				update: true
		name:
			type: 'string'
		value:
			type: 'number'
			default: 1
		date:
			type: 'date'
		default:
			type: 'boolean'
			default: false
		active:
			type: 'boolean'
			default: false

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
			items: _.extend({}, schema.Role.properties.id,
				enum: (value, next) -> @Role.get value, (err, result) -> next not result
			)

schema.Hit =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
			veto:
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
			veto:
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
		lang: _.extend({}, schema.Language.properties.id,
			enum: (value, next) -> next null #@Language.get value, (err, result) -> next not result
			default: config.defaults.nls
		)
		# .....

#
# admin acting on other users
#
schema.User =
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

module.exports = schema
