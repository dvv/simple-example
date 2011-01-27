'use strict'

schema = {}

ro = (attr) ->
	U.extend attr,
		readonly:
			update: true

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
			readonly:
				# FIXME: shouldn't be a role?
				update: true
		rights:
			type: 'any' # so far
		blocked:
			type: 'boolean'
			readonly:
				update: true
			default: false
		# ----- authentication -----
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
		# ----- profile -----
		name:
			type: 'string'
		email:
			type: 'string'
			pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
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

#schema.User = schema.Affiliate = schema.Reseller = schema.Merchant = schema.Admin =
schema.User =
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
		secret: UserEntity.properties.secret
		# ----- profile -----
		name: UserEntity.properties.name
		email: UserEntity.properties.email
		# ----- profile -----
		timezone: UserEntity.properties.timezone
		lang: UserEntity.properties.lang

schema.ADMIN =
	type: 'object'
	properties:
		id: UserEntity.properties.id
		# ----- authority -----
		type: UserEntity.properties.type
		rights: UserEntity.properties.rights
		blocked: UserEntity.properties.blocked
		# ----- authentication -----
		# ----- profile -----
		name: ro UserEntity.properties.name
		email: ro UserEntity.properties.email
		# ----- profile -----
		timezone: ro UserEntity.properties.timezone
		lang: ro UserEntity.properties.lang

schema.PROFILE =
	type: 'object'
	properties:
		id: UserEntity.properties.id
		# ----- authority -----
		type: ro UserEntity.properties.type
		blocked: ro UserEntity.properties.blocked
		# ----- authentication -----
		# ----- profile -----
		name: UserEntity.properties.name
		email: UserEntity.properties.email
		# ----- profile -----
		timezone: UserEntity.properties.timezone
		lang: UserEntity.properties.lang

schema.PASSWORD =
	type: 'object'
	properties:
		id: UserEntity.properties.id
		# ----- authority -----
		# ----- authentication -----
		password: UserEntity.properties.password
		salt: UserEntity.properties.salt
		secret: UserEntity.properties.secret
		# ----- profile -----

console.log schema

module.exports = schema
