'use strict'

require.paths.unshift __dirname + '/lib/node'

#{Store, Model, Facet, RestrictiveFacet, PermissiveFacet} = require 'jse/store'

module.exports = (options) ->

	{Store, applySchema, onevent} = require('jse/store') options.database

	schema = require './schema'

	model = {}

	# vanilla entities
	for own id, def of schema
		store = Store id
		model[id] = applySchema store, def

	# User entity
	user = require './user'
	User = Store 'User'
	model.User = {}
	#for own id, def of user
	#	model.User[id] = applySchema User, def
	#model.User[id] = applySchema User, def

	facets = {}

	Profile = applySchema User, user.PROFILE
	Admin = applySchema User, user.ADMIN


	#
	# EXTRADIT!
	#
	encryptPassword = (password, salt) ->
		sha1(salt + password + options.security.secret)
	roots = options.security.roots

	#
	# TODO: add "owned" conditions === .eq('_meta.history.0.who',@user.id) unless root
	#
	AdminModel =
		get: (id, next) ->
			return next null unless id
			if id is @user?.id
				if roots[id]
					profile = _.clone roots[id]
					validate profile, user.PROFILE, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
					next null, profile
				else
					Profile.get.call @, id, next
			else
				if roots[id]
					profile = _.clone roots[id]
					validate profile, user.ADMIN, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
					next null, profile
				else
					Admin.get.call @, id, next
		#getProfile: (next) ->
		#	AdminModel.get @user?.id, next
		query: (query, next) ->
			Admin.query.call @, query, next
		update: (query, changes, next) ->
			self = @
			plainPassword = undefined
			#console.log 'UPDATE', query
			#
			# TODO: validate changes.rights to not contain more than self.rights
			#
			Step(
				# act as profile manager upon own record
				() ->
					profileChanges = _.clone changes
					# password is special
					if profileChanges.password
						plainPassword = String profileChanges.password
						profileChanges.salt = nonce()
						console.log 'PASSWORD SET TO', profileChanges.password, self.user.id
						profileChanges.password = encryptPassword plainPassword, profileChanges.salt
					console.log 'SELFCHANGE', profileChanges
					#console.log 'UPDATE1', query
					Profile.update.call self, _.rql(query).eq('id', self.user.id), profileChanges, @
					#console.log 'UPDATE2', query
				# act as admin upon other records
				(err) ->
					console.log 'OTHERCHANGE', changes
					#console.log 'UPDATE', query
					Admin.update.call self, _.rql(query).ne('id', self.user.id), changes, @
				(err) ->
					if plainPassword and self.user.email
						console.log 'PASSWORD SET TO', plainPassword
						#	mail self.user.email, 'Password set', plainPassword
					next err
			)
		remove: (query, next) ->
			# forbid self-removal
			Admin.remove.call @, _.rql(query).ne('id', @user.id), next
		add: (data, next) ->
			data ?= {}
			self = @
			console.log 'SIGNUP BY', data, @user
			Step(
				() ->
					roots[data.id] or null
				(err, user) ->
					console.log 'USER', user, data
					return @ err if err
					return @ 'Duplicated' if user
					# create salt, hash salty password
					salt = nonce()
					# generate random pass unless one is specified
					data.password = nonce().substring(0, 7) unless data.password
					password = encryptPassword data.password, salt
					Admin.add.call self, {
						id: data.id
						password: password
						salt: salt
						name: data.name
						email: data.email
						type: data.type
					}, @
				(err, user) ->
					return next err if err
					console.log 'NEWUSER', user
					# TODO: password set, notify the user, if email is set
					console.log 'PASSWORD SET TO', data.password
					#if user.email
					#	mail user.email, 'Password set', data.password
					next null, user
			)
		login: (data, next) ->
			self = @
			Step(
				() ->
					data ?= {}
					id = data.user
					return null unless id
					if roots[id]
						return _.clone roots[id]
					else
						User.get id, @
				(err, user) ->
					#console.log 'GOTUSER!', user
					if not user
						if data.user
							# invalid user
							#console.log 'BAD'
							false
						else
							# log out
							#console.log 'LOGOUT'
							true
					else
						if not user.password or not user.active
							# not been activated
							#console.log 'INACTIVE'
							false
						else if user.password is encryptPassword data.pass, user.salt
							# log in
							#console.log 'LOGIN'
							session =
								uid: user.id
							session.expires = new Date(15*24*60*60*1000 + Date.now()) if data.remember
							session
						else
							#console.log 'WRONG'
							false
				(err, session) ->
					# save session
					session = false if err
					#if session and session isnt true
					# TODO: log attempts?
					self.remember session, next
			)

	model.User = AdminModel

	['affiliate', 'merchant', 'admin'].forEach (type) ->
		model[_.capitalize type] =
			add: (data, next) ->
				data ?= {}
				data.type = type
				model.User.add.call @, data, next
			update: (query, changes, next) ->
				model.User.update.call @, _.rql(query).eq('type',type), changes, next
			remove: (query, next) ->
				model.User.remove.call @, _.rql(query).eq('type',type), next
			query: (query, next) ->
				model.User.query.call @, _.rql(query).eq('type',type), next
			get: (id, next) ->
				model.User.get.call @, id, (err, result) ->
					result = null unless result?.type is type
					next err, result

	return {
		schema: schema
		model: model
		facets: facets
	}

