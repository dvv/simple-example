'use strict'

module.exports = (config, model, callback) ->

	#console.log 'MODEL', model

	facets = {}

	#
	# nonce
	#
	crypto = require 'crypto'
	nonce = () ->
		(Date.now() & 0x7fff).toString(36) + Math.floor(Math.random()*1e9).toString(36) + Math.floor(Math.random()*1e9).toString(36) + Math.floor(Math.random()*1e9).toString(36) #+ Math.floor(Math.random()*1e9).toString(36)
	sha1 = (data, key) ->
		hmac = crypto.createHmac 'sha1', key
		hmac.update data
		hmac.digest 'hex'

	#
	# hash of power users -- owners of db
	#
	roots = config.security.roots or {}

	#
	# password hash function
	#
	encryptPassword = (password, salt) ->
		sha1(salt + password + config.security.secret)

	#
	# secure admin accounts
	#
	for own k, v of roots
		v.salt = nonce()
		v.password = encryptPassword v.password, v.salt

	######################################
	################### USER
	######################################

	# TODO: add "owned" conditions === .eq('_meta.history.0.who',@user.id) unless root
	model.User =

		get: (context, id, next) ->
			return next? null unless id
			isSelf = id is context?.user?.id
			if roots[id]
				user = roots[id]
				profile = _.extend {},
					id: user.id
					type: user.type
					email: user.email
				next? null, profile
			else
				(if isSelf then model.UserSelf else model.UserAdmin).get context, id, next
			return

		query: (context, query, next) ->
			model.UserAdmin.query context, query, next
			return

		add: (context, data, next) ->
			data ?= {}
			#console.log 'SIGNUP BY', data, context.user
			Next context,
				(err, result, step) ->
					step null, (roots[data.id] or null)
				(err, user, step) ->
					#console.log 'USER', user, data
					return step err if err
					return step [{property: 'id', message: 'duplicated'}] if user
					# create salt, hash salty password
					salt = nonce()
					# generate random pass unless one is specified
					data.password = nonce().substring(0, 7) unless data.password
					password = encryptPassword data.password, salt
					model.UserAdmin.add context, {
						id: data.id
						password: password
						salt: salt
						type: data.type
					}, step
				(err, user) ->
					#console.log 'ADDUSER', arguments
					return next err if err
					#console.log 'NEWUSER', user
					# TODO: password set, notify the user, if email is set
					if user.email
						console.log 'PASSWORD SET TO', data.password
						#mail user.email, 'Password set', data.password
					next? null, user
			return

		update: (context, query, changes, next) ->
			plainPassword = undefined
			#console.log 'UPDATE', query
			#
			# TODO: validate changes.rights to not contain more than self.rights
			#
			Next context,
				# act as profile manager upon own record
				(err, result, step) ->
					profileChanges = _.clone changes
					# password is special
					if profileChanges.password
						plainPassword = String profileChanges.password
						profileChanges.salt = nonce()
						#console.log 'PASSWORD SET TO', profileChanges.password, context.user.id
						profileChanges.password = encryptPassword plainPassword, profileChanges.salt
					#console.log 'SELFCHANGE', profileChanges
					#console.log 'UPDATE1', query
					model.UserSelf.update context, _.rql(query).eq('id',context.user.id), profileChanges, step
					###
					if plainPassword and @user.email
						console.log 'PASSWORD SET TO', plainPassword
						#	mail context.user.email, 'Password set', plainPassword
					###
					#console.log 'UPDATE2', query
				# act as admin upon other records
				(err, result, step) ->
					#console.log 'OTHERCHANGE', changes
					#console.log 'UPDATE', query
					model.UserAdmin.update context, _.rql(query).ne('id',context.user.id), changes, step
				(err) ->
					next? err
			return

		remove: (context, query, next) ->
			# forbid self-removal
			model.UserAdmin.remove context, _.rql(query).ne('id',context.user.id), next
			return

		delete: (context, query, next) ->
			# forbid self-removal
			model.UserAdmin.delete context, _.rql(query).ne('id',context.user.id), next
			return

		undelete: (context, query, next) ->
			# forbid self-undeletion
			model.UserAdmin.undelete context, _.rql(query).ne('id',context.user.id), next
			return

		purge: (context, query, next) ->
			# forbid self-deletion
			model.UserAdmin.purge context, _.rql(query).ne('id',context.user.id), next
			return

		#
		# profile getter/setter
		#
		# FIXME: needed?
		getProfile: (context, next) ->
			#console.log 'GETPROFILE for', context.user?.id
			model.UserSelf.get context, context.user?.id, next
			return
		setProfile: (context, changes, next) ->
			model.UserSelf.update context, [context.user?.id], changes, (err, result) ->
				return next? err if err
				model.User.getProfile context, next
			return

		#
		# try to login the user by credentials in data.user/data.pass
		#
		login: (context, data, next) ->
			Next @,
				(err, xxx, step) ->
					data ?= {}
					id = data.user
					return step() unless id
					if roots[id]
						step null, _.clone roots[id]
					else
						model.User._get null, @, id, step
				(err, user, step) ->
					#console.log 'GOTUSER!', err, user
					if not user
						if data.user
							# invalid user
							step 'Invalid user'
						else
							# log out
							step null, true
					else
						if not user.password or user.blocked
							# not been activated
							step 'Invalid user'
						else if user.password is encryptPassword data.pass, user.salt
							# log in
							session =
								uid: user.id
							session.expires = new Date(15*24*60*60*1000 + Date.now()) if data.remember
							step null, session
						else
							#console.log 'WRONG'
							step 'Invalid user'
				(err, session) ->
					# save session
					session = err or session
					# TODO: log attempts?
					@remember session, next
			return

		#
		# return capability object given user id
		#
		# TODO: consider _.memoize() here!!! .update should drop the cached value!
		#
		#
		getContext: (uid, next) ->
			Next null,
				(err, result, step) ->
					if not uid or roots[uid]
						step null, _.clone roots[uid]
					else
						model.User._get null, @, uid, step
				(err, user, step) ->
					user ?= {}
					#console.log 'USER', uid, user
					# config.server.disabled disables guest or vanilla user interface
					# TODO: watchFile ./down to control config.server.disabled
					if config.server.disabled and not roots[user.id]
						level = 'none'
					else if config.security.bypass or roots[user.id]
						level = 'root'
					else if user.id and user.type
						level = user.type # N.B. can be an array of levels
					else if user.id
						level = 'user'
					else
						level = 'public'
					level = [level] unless _.isArray level
					# collect capabilities
					context = _.extend.apply null, [{}].concat(level.map (x) -> facets[x])
					# mixin the user
					Object.defineProperty context, 'user', value: _.freeze user
					#console.log 'EFFECTIVE FACET', level, context
					next? null, context
			return

	#
	# define User flavors
	#
	# TODO: Affiliate should impose "owned" restriction also
	_.each {affiliate: 'Affiliate', merchant: 'Merchant', admin: 'Admin'}, (name, type) ->
		model[name] =
			query: (context, query, next) ->
				model.User.query context, _.rql(query).eq('type',type), next
				return
			get: (context, id, next) ->
				model.User.get context, id, (err, result) ->
					result = null unless result?.type is type
					next err, result
				return
			add: (context, data, next) ->
				data ?= {}
				data.type = type
				model.User.add context, data, next
				return
			update: (context, query, changes, next) ->
				model.User.update context, _.rql(query).eq('type',type), changes, next
				return
			remove: (context, query, next) ->
				model.User.remove context, _.rql(query).eq('type',type), next
				return
			delete: (context, query, next) ->
				model.User.delete context, _.rql(query).eq('type',type), next
				return
			undelete: (context, query, next) ->
				model.User.undelete context, _.rql(query).eq('type',type), next
				return
			purge: (context, query, next) ->
				model.User.purge context, _.rql(query).eq('type',type), next
				return
		#
		#
		#
		# TODO: reuse the code in Database.register!
		#
		#
		#
		Object.defineProperties model[name],
			id:
				value: name
			schema:
				value: model.UserAdmin.schema

	######################################
	################### FACETS
	######################################

	PermissiveFacet = (obj, plus...) ->
		# register permissive facet -- set of entity accessors
		expose = ['schema', 'id', 'query', 'get', 'add', 'update', 'remove']
		#
		# FIXME: @attrInactive?! from config?
		#
		#expose = expose.concat ['delete', 'undelete', 'purge'] if @attrInactive
		expose = expose.concat plus if plus.length
		_.proxy obj, expose

	FacetForGuest = _.freeze _.extend {},
		getRoot: (context, query, next) ->
			s = {}
			#console.log 'ROOT', context
			for own k, v of context
				if typeof v is 'function'
					s[k] = true
				else if v.schema
					#console.log k, v
					s[k] =
						schema: v.schema
						methods: _.functions v
			user = context.user
			next null,
				# expose the bare minimum
				user:
					id: user.id
					email: user.email
					type: user.type
					schema: s
				#context: context
		login: model.User.login
		Hit: PermissiveFacet model.Hit

	# user -- authenticated authority
	FacetForUser = _.freeze _.extend {}, FacetForGuest,
		#Profile:
		#	get: model.User.getProfile
		#	set: model.User.setProfile
		getProfile: model.User.getProfile
		setProfile: model.User.setProfile

	# root -- hardcoded DB owner
	FacetForRoot = _.freeze _.extend {}, FacetForUser,
		Affiliate: PermissiveFacet model.Affiliate
		Merchant: PermissiveFacet model.Merchant
		Admin: PermissiveFacet model.Admin
		Role: PermissiveFacet model.Role
		Group: PermissiveFacet model.Group
		Language: PermissiveFacet model.Language
		Region: PermissiveFacet model.Region
		Country: PermissiveFacet model.Country
		Currency: PermissiveFacet model.Currency
		#Course: PermissiveFacet model.Course, 'fetch'

	FacetForAffiliate = _.freeze _.extend {}, FacetForUser,
		# TODO: owned affiliates only
		Affiliate: FacetForRoot.Affiliate

	FacetForMerchant = _.freeze _.extend {}, FacetForUser, {}

	# admin -- powerful user
	FacetForAdmin = _.freeze _.extend {}, FacetForUser,
		Affiliate: FacetForRoot.Affiliate
		Merchant: FacetForRoot.Merchant
		Admin: FacetForRoot.Admin
		Role: FacetForRoot.Role
		Group: FacetForRoot.Group
		Language: FacetForRoot.Language
		Region: FacetForRoot.Region
		Country: FacetForRoot.Country
		Currency: FacetForRoot.Currency
		#Course: FacetForRoot.Course

	facets.public = FacetForGuest
	facets.user = FacetForUser
	facets.root = FacetForRoot

	facets.affiliate = FacetForAffiliate
	facets.merchant = FacetForMerchant
	facets.admin = FacetForAdmin

	#console.log 'FACET', facets

	#
	# return the sole method to get user authority
	#
	global.app =
		getContext: model.User.getContext

	callback? null, app
