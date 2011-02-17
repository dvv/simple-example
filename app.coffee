'use strict'

#
# Country r/o from geoip, regions from geoip, geo info in user record
#

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

	#
	# N.B. we redefine User accessors to honor security when a user acts on self
	#
	User = model.User
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
				if isSelf
					User._get model.UserSelf.schema, context, id, next
				else
					User.get context, id, next
			return

		query: (context, query, next) ->
			User.query context, query, next

		# N.B. ensure new user doesn't clash root
		#
		# FIXME: shouldn't root be the one and login completely different?!
		#
		add: (context, data = {}, next) ->
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
					User.add context, {
						id: data.id
						password: password
						salt: salt
						type: data.type
					}, step
				(err, user) ->
					#console.log 'ADDUSER', arguments
					return next? err if err
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
					User._update model.UserSelf.schema, context, _.rql(query).eq('id',context.user.id), profileChanges, step
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
					User.update context, _.rql(query).ne('id',context.user.id), changes, step
				(err) ->
					next? err
			return

		remove: (context, query, next) ->
			# forbid self-removal
			User.remove context, _.rql(query).ne('id',context.user.id), next
			return

		delete: (context, query, next) ->
			# forbid self-removal
			User.delete context, _.rql(query).ne('id',context.user.id), next
			return

		undelete: (context, query, next) ->
			# forbid self-undeletion
			User.undelete context, _.rql(query).ne('id',context.user.id), next
			return

		purge: (context, query, next) ->
			# forbid self-deletion
			User.purge context, _.rql(query).ne('id',context.user.id), next
			return

		#
		# profile getter/setter
		#
		# FIXME: needed?
		getProfile: (context, next) ->
			#console.log 'GETPROFILE for', context.user?.id
			User._get model.UserSelf.schema, context, context.user?.id, next
			return
		setProfile: (context, changes, next) ->
			User._update model.UserSelf.schema, context, [context.user?.id], changes, (err, result) ->
				return next? err if err
				model.User.getProfile context, next
			return

		#
		# verify credentials in data.user/data.pass
		#
		verify: (data = {}, next) ->
			Next null,
				(err, result, step) ->
					model.User.getContext data.user, step
				(err, context, step) ->
					user = context.user
					#console.log 'GOTUSER!', user
					if not user.id
						if data.user
							# invalid user
							step 'Invalid user'
						else
							# log out
							step()
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
				(err, session, step) ->
					#console.log 'GOTSESSION!', arguments
					next err, session

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
						User._get null, @, uid, step
				(err, user = {}, step) ->
					#console.log 'USER', uid, user, user._meta.history
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
					Object.defineProperty context, 'user', value: user
					# define authentication checker
					Object.defineProperty context, 'verify', value: model.User.verify
					#console.log 'EFFECTIVE FACET', level, context
					# bind all functions in the context to the context
					#safe = {}
					#for own k, v of context
					#	safe[k] = {}
					#	for own n, f of v
					#		safe[k][n] = if _.isFunction f then f.bind null, context else f
					#next? null, _.freeze safe
					next? null, _.freeze context
			return

	#
	# define User flavors
	#
	_.each {affiliate: 'Affiliate', merchant: 'Merchant', admin: 'Admin'}, (name, type) ->
		model[name] =
			query: (context, query, next) ->
				model.User.query context, User.owned(context, query).eq('type',type), next
			get: (context, id, next) ->
				query = User.owned(context, 'limit(1)').eq('type',type).eq('id',id)
				model.User.query context, query, (err, result) ->
					next? err, result[0] or null
			add: (context, data = {}, next) ->
				data.type = type
				model.User.add context, data, next
			update: (context, query, changes, next) ->
				model.User.update context, User.owned(context, query).eq('type',type), changes, next
			remove: (context, query, next) ->
				model.User.remove context, User.owned(context, query).eq('type',type), next
			delete: (context, query, next) ->
				model.User.delete context, User.owned(context, query).eq('type',type), next
			undelete: (context, query, next) ->
				model.User.undelete context, User.owned(context, query).eq('type',type), next
			purge: (context, query, next) ->
				model.User.purge context, User.owned(context, query).eq('type',type), next
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
				value: User.schema

	#
	# Geo and Course fetch routines
	#
	model.Geo.fetch = (context, next) ->
		require('./geo').fetchGeo (err, result) ->
			model.Geo.remove context, 'a!=b', () ->
				_.each result, (rec) ->
					model.Geo.add context, rec, (err, result) ->
						console.log 'GEOFAILED', rec.name if err
				next()

	model.Course.fetch = (context, callback) ->
		All {},
			(err, result, next) ->
				# fetch currencies
				context.Currency.query context, '', next
			(err, currencies, next) ->
				@currencies = currencies
				# fetch courses
				require('./geo').fetchCourses null, next
			(err, courses, next) ->
				#console.log 'CURR?', courses
				#courses = _.query courses, _.pluck(@currencies, 'id')
				courses = _.query courses, ['USD', 'RUB']
				#console.log 'CURR!', courses
				_.each courses, (rec) ->
					console.log 'CURADDING', rec
					context.Course.add context, rec, (err, result) ->
						if err?[0]?.message is 'duplicated'
							context.Course.update context, [rec.id], rec, (err, result) ->
								console.log 'CURFAILED1', rec.name, err if err
						if err
							console.log 'CURFAILED2', rec.name, err if err
				callback()

	#
	#
	# TODO: shouldn't be external?
	#
	#

	######################################
	################### FACETS
	######################################

	PermissiveFacet = (obj, plus...) ->
		# register permissive facet -- set of entity accessors
		expose = ['schema', 'id', 'query', 'get', 'add', 'update', 'remove', 'delete', 'undelete', 'purge']
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

	# user -- authenticated authority
	FacetForUser = _.freeze _.extend {}, FacetForGuest,
		#Profile:
		#	get: model.User.getProfile
		#	set: model.User.setProfile
		getProfile: model.User.getProfile
		setProfile: model.User.setProfile
		Hit: PermissiveFacet model.Hit

	# root -- hardcoded DB owner
	FacetForRoot = _.freeze _.extend {}, FacetForUser,
		Affiliate: PermissiveFacet model.Affiliate
		Merchant: PermissiveFacet model.Merchant
		Admin: PermissiveFacet model.Admin
		Role: PermissiveFacet model.Role
		Group: PermissiveFacet model.Group
		Language: PermissiveFacet model.Language
		Currency: PermissiveFacet model.Currency
		Geo: PermissiveFacet model.Geo, 'fetch'
		Course: PermissiveFacet model.Course, 'fetch'

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
		Currency: FacetForRoot.Currency
		Geo: FacetForRoot.Geo
		Course: FacetForRoot.Course

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
	global.app = app = Object.freeze
		getContext: model.User.getContext

	callback? null, app
