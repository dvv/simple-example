'use strict'

require.paths.unshift __dirname + '/lib/node'

#{Store, Model, Facet, RestrictiveFacet, PermissiveFacet} = require 'jse/store'

module.exports = (options) ->

	{Store, applySchema, onevent} = require('jse/store') options.database

	schema = require './schema'

	model = {}

	# vanilla entities
	for id, def of schema
		store = Store id
		model[id] = applySchema store, def

	user = require './user'
	User = Store 'User'
	model.User = {}
	for id, def of user
		model.User[id] = applySchema User, def

	facets = {}

	return {
		schema: schema
		model: model
		facets: facets
	}

	'''
model.User = Model 'User', {schema: schema.User}, {
	get: (id, next) ->
		return next null unless id
		if settings.security.roots[id]
			next null, U.clone settings.security.roots[id]
		else
			model.User._get null, id, next
	# given the user, return his access level
	getLevel: (user) ->
		# settings.server.disabled disables guest or vanilla user interface
		# TODO: watchFile ./down to control settings.server.disabled
		if settings.server.disabled and not settings.security.roots[user.id]
			level = 'none'
		else if settings.security.bypass or settings.security.roots[user.id]
			level = 'root'
		else if user.id and user.type
			level = user.type
		else if user.id
			level = 'user'
		else
			level = 'public'
		level
	add: Compose.around (base) -> (data, next) ->
		data ?= {}
		self = @
		console.log 'SIGNUP BY', data, @user
		model.User.get data.id, (err, user) ->
			#console.log 'USER', user, data
			return next err if err
			return next SyntaxError 'Cannot create such user' if user
			# create salt, hash salty password
			salt = nonce()
			# generate random pass unless one is specified
			data.password = nonce().substring(0, 7) unless data.password
			password = encryptPassword data.password, salt
			base.call @, {
				id: data.id
				password: password
				salt: salt
				name: data.name
				email: data.email
				regDate: Date.now() # FIXME: default in schema?
				type: data.type
				# TODO: activation!
				active: data.active
				creator: self.user.id
			}, (err, user) ->
				return next err if err
				#console.log 'NEWUSER', user
				# TODO: password set, notify the user, if email is set
				console.log 'PASSWORD SET TO', data.password
				#if user.email
				#	mail user.email, 'Password set', data.password
				next null, user
	getProfile: (next) ->
		next null, U.veto(@user, ['password', 'salt'])
	setProfile: (changes, next) ->
		changes ?= {}
		console.log 'PROFILECHANGE', changes
		# N.B. have to manually validate here
		# FIXME: BADBADBAD to double schema here
		#validation = validatePart changes,
		#	properties:
		#		id: schema.User.properties.id
		#		name: schema.User.properties.name
		#		email: schema.User.properties.email
		#if not validation.valid
		#	return next SyntaxError JSON.stringify validation.errors
		model.User.update Query().eq('id', @user.id), changes, next
	setPassword: (data, next) ->
		return next TypeError 'Refuse to change the password' unless data.newPassword and data.newPassword is data.confirmPassword and @user.password is encryptPassword data.oldPassword, @user.salt
		# create salt, hash salty password
		changes = {}
		changes.salt = nonce()
		console.log 'PASSWORD SET TO', data.newPassword, @user.id
		changes.password = encryptPassword data.newPassword, changes.salt
		# N.B. we use plain Store method here
		model.User._update null, Query().eq('id', @user.id), changes, (err) ->
			return next err if err
			# TODO: password changed, notify the user
			#if @user.email
				#	mail @user.email, 'Password set', data.password
			next null
}
	'''
