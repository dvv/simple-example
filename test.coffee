#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

# TODO: make 'development' come from environment
global.settings = require('./config').development

run = require('simple').run

schema = {}
model = {}
facets = {}

schema.Region =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[A-Z_]+$'
		name:
			type: 'string'
			readonly:
				update: true

#model.Region = Store('Region', schema: schema.Region)
#model.Region = Model 'Region', null, {schema: schema.Region}, {
#}
model.Region = Store 'Region', schema: schema.Region, {
	foo: 'bar'
}, {
	bar: 'baz'
}

schema.User = schema.Affiliate = schema.Reseller = schema.Merchant = schema.Admin =
	type: 'object'
	properties:
		id:
			type: 'string'
			pattern: '^[a-zA-Z0-9_]+$'
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
			#enum: model.Language.all model.Language
			default: 'en'

model.User = Store 'User', schema: schema.User, {
	setPassword: (pass, next) ->
		model.User._update null, ['a'], {password: pass}, next
}

model.User.remove 'a!=b', () ->
	model.User.add {id:'a',creator:'root',name:123,email:'a@b.cc',active:'true'}, () ->
		model.User.setPassword 'aaa', () ->
			model.User._all null, ''

#model.User.get('a',function(err,doc){doc.password='aaa';doc.save();console.log(doc)})

# TODO: remove from global
global.model = model
global.facets = facets

#model.Bar
#p(model.Bar.find.call({foo:'bar'}));
#p(Q('User').where(['z']).all());
#p(Store1('User').where(['q']).one());
#p(Store1('User').where(['q']).where(['z']).one());

wait waitAllKeys(model), () ->

	# define the application
	app = Compose.create require('events').EventEmitter, {
		getSession: (req, res) ->
			Object.freeze Compose.call {user: {id: 'faker'}}, context: facets
		#handler: handler
	}

	# run the application
	run app
