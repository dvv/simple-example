'use strict'

require.paths.unshift __dirname + '/lib/node'

schema = {}

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
			enum: (value, next) -> model.Region.get value, (err, result) -> next err
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
						enum: () -> _.keys model # TODO: should be keys of the context!
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
				enum: (value, next) -> model.Role.get value, (err, result) -> next err

module.exports = schema
