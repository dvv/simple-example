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

module.exports = schema
