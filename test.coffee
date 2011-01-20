#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

# TODO: make 'development' come from environment
global.settings = require('./config').development

run = require('simple').run

schema = {}
model = {}
facets = {}

model.Bar = Model 'Bar', Store('Bar'), {
	find: Compose.around (base) ->
		(q) ->
			console.log 'USER', @user
			base q
}

facets.Bar = PermissiveFacet model.Bar, {
	schema:
		type: 'object'
		properties:
			v:
				type: 'string'
				readonly:
					add: true
					get: true
			test:
				type: 'string'
				readonly:
					update: true
}

# TODO: remove from global
global.model = model
global.facets = facets

#model.Bar
#p(model.Bar.find.call({foo:'bar'}));
#p(facets.Bar.find.call({foo:'bar'}));

wait waitAllKeys(model), () ->

	# define the application
	app = Compose.create require('events').EventEmitter, {
		getSession: (req, res) ->
			Object.freeze Compose.call {user: {id: 'faker'}}, context: facets
		#handler: handler
	}

	# run the application
	run app

###############################

User = Store 'User'
Session = Store 'Session'

App =
	getProfile = () ->
		model.get 'user'
	setProfile = (changes) ->
		model.set 'user', changes
	auth = (id, password) ->
		if id
			wait User.get(id), (user) ->
				return null unless user
				Session.add ?
				model.set 'user', user
				# set cookie
		else
			model.unset 'user'
			Session.remove ?
			# clear cookie
			return
