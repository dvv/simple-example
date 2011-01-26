'use strict'

require.paths.unshift __dirname + '/lib/node'

schema = {}

metaProperty =
	type: 'object'
	additionalProperties: false
	properties:
		version:
			type: 'integer'
			#
			#
			#
			#readonly:
			#	update: true
		deleted:
			type: 'boolean'
			readonly:
				add: true
		creator:
			type: 'string'
			readonly:
				update: true
		created:
			type: 'integer' # epoch!
			readonly:
				update: true
		modifier:
			type: 'string'
			readonly:
				add: true
		modified:
			type: 'integer' # epoch!
			readonly:
				add: true
	optional: true

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

# fill up variable enumerations
#schema.Role.properties.rights.items.properties.entity.enum = U.keys model
#model.Role.all 'values(name)', (err, roles) -> schema.Group.properties.roles.items.enum = U.pluck roles, 'name'
#model.Language.all 'values(name)', (err, langs) -> schema.User.properties.lang.enum = U.pluck langs, 'name'
#model.Region.all 'values(name)', (err, result) -> schema.Country.properties.region.enum = U.pluck result, 'id'

#schema.User = schema.Affiliate = schema.Reseller = schema.Merchant = schema.Admin =
schema.User =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
			readonly:
				update: true
		_meta: metaProperty
		# ----- authority -----
		type:
			type: 'string'
			readonly:
				# FIXME: shouldn't be a role?
				update: true
		blocked:
			type: 'boolean'
			readonly:
				update: true
			default: false
		group:
			type: 'string'
		# ----- authentication -----
		email:
			type: 'string'
			pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
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
		# ----- profile -----
		name:
			type: 'string'
		secret:
			type: 'string'
			readonly: true
			optional: true
		timezone:
			type: 'string'
			enum: ['UTC-11', 'UTC-10', 'UTC-09', 'UTC-08', 'UTC-07', 'UTC-06', 'UTC-05', 'UTC-04', 'UTC-03', 'UTC-02', 'UTC-01', 'UTC+00', 'UTC+01', 'UTC+02', 'UTC+03', 'UTC+04', 'UTC+05', 'UTC+06', 'UTC+07', 'UTC+08', 'UTC+09', 'UTC+10', 'UTC+11', 'UTC+12']
			default: 'UTC+04'
		lang:
			type: 'string'
			enum: ['en'] # to be filled with model.Language.all()
			default: 'en'

schema.UserProfileRead =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
		creator:
			type: 'string'
		# ----- authority -----
		type:
			type: 'string'
		blocked:
			type: 'boolean'
		group:
			type: 'string'
		# ----- profile -----
		email:
			type: 'string'
		name:
			type: 'string'
		secret:
			type: 'string'
		regDate:
			type: 'date'
		timezone:
			type: 'string'
		lang:
			type: 'string'

schema.UserProfileWrite =
	type: 'object'
	additionalProperties: false
	properties:
		# ----- profile -----
		email:
			type: 'string'
			pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i
		name:
			type: 'string'
		secret:
			type: 'string'
			optional: true
		timezone:
			type: 'string'
			enum: ['UTC-11', 'UTC-10', 'UTC-09', 'UTC-08', 'UTC-07', 'UTC-06', 'UTC-05', 'UTC-04', 'UTC-03', 'UTC-02', 'UTC-01', 'UTC+00', 'UTC+01', 'UTC+02', 'UTC+03', 'UTC+04', 'UTC+05', 'UTC+06', 'UTC+07', 'UTC+08', 'UTC+09', 'UTC+10', 'UTC+11', 'UTC+12']
			default: 'UTC+04'
		lang:
			type: 'string'
			enum: ['en'] # to be filled with model.Language.all()
			default: 'en'

schema.UserAuthorityRead =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
		creator:
			type: 'string'
		regDate:
			type: 'date'
		# ----- authority -----
		type:
			type: 'string'
		blocked:
			type: 'boolean'
		group:
			type: 'string'

schema.UserAuthorityWrite =
	type: 'object'
	additionalProperties: false
	properties:
		# ----- authority -----
		type:
			type: 'string'
		blocked:
			type: 'boolean'
		group:
			type: 'string'

schema.UserAuthorityCreate =
	type: 'object'
	additionalProperties: false
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
		creator:
			type: 'string'
		regDate:
			type: 'date'
		# ----- authority -----
		type:
			type: 'string'
		blocked:
			type: 'boolean'
		group:
			type: 'string'
		email: schema.UserProfileWrite.properties.email

schema.UserChangePassword =
	type: 'object'
	additionalProperties: false
	properties:
		password:
			type: 'string'
		salt:
			type: 'string'

module.exports = schema
