'use strict'

require.paths.unshift __dirname + '/lib/node'

schema = {}

ro = (attr) ->
	Compose.create attr,
		readonly:
			update: true

wo = (attr) ->
	Compose.create attr,
		readonly:
			get: true

cr = (attr) ->
	Compose.create attr,
		readonly:
			get: true
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

#
# admin acting on other users
#
schema.ADMIN =
	type: 'object'
	properties:
		id: UserEntity.properties.id
		# ----- authority -----
		type: ro UserEntity.properties.type
		rights: UserEntity.properties.rights
		blocked: UserEntity.properties.blocked
		# ----- authentication -----
		# TODO: think whether feasible to let only user to change the pass?!
		password: cr UserEntity.properties.password
		salt: cr UserEntity.properties.salt
		# ----- profile -----
		name: ro UserEntity.properties.name
		email: ro UserEntity.properties.email
		# ----- profile -----
		timezone: ro UserEntity.properties.timezone
		lang: ro UserEntity.properties.lang

#
# any user acting on himself
#
schema.PROFILE =
	type: 'object'
	properties:
		id: UserEntity.properties.id
		# ----- authority -----
		type: ro UserEntity.properties.type
		rights: ro UserEntity.properties.rights
		blocked: ro UserEntity.properties.blocked
		# ----- authentication -----
		password: wo UserEntity.properties.password
		salt: wo UserEntity.properties.salt
		secret: UserEntity.properties.secret
		# ----- profile -----
		name: UserEntity.properties.name
		email: UserEntity.properties.email
		# ----- profile -----
		timezone: UserEntity.properties.timezone
		lang: UserEntity.properties.lang

#
# admin acting on user authentication
#
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

#console.log schema.PROFILE

module.exports = schema
