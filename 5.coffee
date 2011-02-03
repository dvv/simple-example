#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'
global._ = require 'underscore'

_.mixin
	rql: require('jse/rql').rql

_validate = require 'jse/validate'
validate = (instance, schema, options, next) -> _validate instance, schema, _.extend(options or {}, coerce: _.coerce), next

inspect = require('eyes.js').inspector stream: null
consoleLog = console.log
console.log = () -> consoleLog inspect arg for arg in arguments

Next = (context, steps...) ->
	next = (err, result) ->
		#unless steps.length
		#	console.log 'LASTSTEP', arguments
		#	throw err if err
		#	return
		# N.B. only simple steps are supported -- no next.group() and next.parallel() as in Step
		fn = steps.shift()
		if fn
			try
				fn.call context, err, result, next
			catch err
				next err
		context
	next()

Step = require 'step'

parseUrl = require('url').parse
mongo = require 'mongodb'
events = require 'events'

class Database extends events.EventEmitter

	constructor: (@url) ->
		conn = parseUrl @url
		@host = conn.hostname
		@port = +conn.port if conn.port
		@auth = conn.auth if conn.auth # FIXME: what is options analog?
		@name = conn.pathname.substring(1) if conn.pathname
		@collections = {}
		@idFactory = () ->
			(new mongo.BSONPure.ObjectID).toHexString()
		#@attrInactive = '_deleted'
		@db = new mongo.Db @name, new mongo.Server(@host, @port) #, native_parser: true

	open: (collections, callback) ->
		self = @
		register = (callback) ->
			len = collections.length
			for name in collections
				do (name) ->
					self.db.collection name, (err, coll) ->
						self.collections[name] = coll
						# TODO: may init indexes here
						# ...
						if --len <= 0
							callback err
		self.db.open (err, result) ->
			if self.auth
				[username, password] = self.auth.split ':', 2
				self.db.authenticate username, password, (err, result) ->
					return callback err if err
					register callback
			else
				return callback err if err
				register callback

	query: (collection, schema, context, query, callback) ->
		query = _.rql(query)
		if @attrInactive
			query = query.ne(@attrInactive,true)
		query = query.toMongo()
		#console.log 'FIND!', query
		@collections[collection].find query.search, query.meta, (err, cursor) ->
			return callback err if err
			cursor.toArray (err, docs) ->
				#console.log 'FOUND', arguments
				return callback err if err
				ta = query.meta.toArray
				for doc, i in docs
					# _id -> id
					doc.id = doc._id
					delete doc._id
					# filter out protected fields
					if schema
						validate doc, schema, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
					docs[i] = _.toArray doc if ta
				#console.log 'FOUND', docs, docs.length, callback.toString()
				callback null, docs

	get: (collection, schema, context, id, callback) ->
		@query collection, schema, context, _.rql('limit(1)').eq('id',id), (err, result) ->
			return callback err if err
			callback null, result[0] or null

	add: (collection, schema, context, document, callback) ->
		self = @
		user = context?.user?.id
		document ?= {}
		# assign new primary key unless specified
		document.id = @idFactory() unless document.id
		Next self,
			(err, result, next) ->
				#console.log 'BEFOREUPDATE', query, changes, schema
				# validate document
				if schema
					validate document, schema, {vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'add'}, next
				else
					next null, document
			(err, document, next) ->
				return next err if err
				# id -> _id
				document._id = document.id
				delete document.id
				# add history line
				document._meta =
					history: [
						who: user
						when: Date.now()
						# FIXME: should we put initial document here?
					]
				# do add
				@collections[collection].insert document, {safe: true}, next
			(err, result, next) ->
				#console.log 'ADD', arguments
				if err
					if err.message.substring(0,6) is 'E11000'
						err.message = 'Duplicated'
					callback err.message
					#self.emit 'add',
					#	collection: collection
					#	user: user
					#	error: err.message
				else
					result = result[0]
					result.id = result._id
					delete result._id
					# filter out protected fields
					if schema
						validate result, schema, vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, flavor: 'get'
					callback null, result
					#self.emit 'add',
					#	collection: collection
					#	user: user
					#	result: result

	update: (collection, schema, context, query, changes, callback) ->
		self = @
		user = context?.user?.id
		# atomize the query
		query = _.rql(query).toMongo()
		query.search.$atomic = 1
		# add history line
		changes ?= {}
		Next self,
			(err, result, next) ->
				#console.log 'BEFOREUPDATE', query, changes, schema
				# validate document
				if schema
					validate changes, schema, {vetoReadOnly: true, removeAdditionalProps: !schema.additionalProperties, existingOnly: true, flavor: 'update'}, next
				else
					next null, changes
			(err, changes, next) ->
				#console.log 'BEFOREUPDATEVALIDATED', arguments
				# N.B. we inhibit empty changes
				return next err if err or not _.keys changes
				history =
					who: user
					when: Date.now()
				delete changes._meta
				history.what = changes
				# ensure changes are in multi-update format
				# FIXME: should prohibit $set and id in changes at facet level!!!
				changes = $set: changes #unless changes.$set or changes.$unset
				changes.$push = '_meta.history': history
				# do multi update
				@collections[collection].update query.search, changes, {multi: true}, next
			(err, result) ->
				callback err
				#self.emit 'update',
				#	collection: collection
				#	user: user
				#	search: query.search
				#	changes: changes
				#	err: err?.message
				#	result: result

	remove: (collection, context, query, callback) ->
		self = @
		user = context?.user?.id
		query = _.rql(query)
		if @attrInactive
			query = query.ne(@attrInactive,true)
		query = query.toMongo()
		# naive fuser
		return callback 'Refuse to remove all documents w/o conditions' unless _.keys(query.search).length
		if @attrInactive
			# the only change is to set @attrInactive
			changes = {}
			changes[@attrInactive] = false
			schema =
				type: 'object'
			schema.properties = {}
			schema.properties[@attrInactive] =
				type: 'any'
			# update documents
			@update collection, schema, context, query.search, changes, (err) ->
				callback err
				#self.emit 'remove',
				#	collection: collection
				#	user: user
				#	search: query.search
				#	error: err?.message
		else
			@collections[collection].remove query.search, (err) ->
				callback err
				#self.emit 'remove',
				#	collection: collection
				#	user: user
				#	search: query.search
				#	error: err?.message

time1 = null
time2 = null

context =
	user:
		id: 'dummy'

s =
	type: 'object'
	properties:
		id:
			readonly:
				get: false
		name:
			type: 'any'

db = new Database 'mongodb://127.0.0.1:27017/simple'
#Step.async
Next db,
	(err, result, next) ->
		@open ['Language'], next
	#(err, result, next) ->
	#	@query 'Language', s, context, 'limit(5)', next
	(err, result, next) ->
		#console.log 'QUERIED', arguments
		@remove 'Language', context, 'all!=true', next
	(err, result, next) ->
		@add 'Language', null, context, {id: 'fr1'}, next
	(err, result, next) ->
		#console.log 'ADDED', arguments
		@add 'Language', null, context, {foo: 'bar'}, next
	(err, result, next) ->
		@get 'Language', null, context, 'fr1', next
	(err, result, next) ->
		#console.log 'GOT fr1', arguments
		@remove 'Language', context, ['fr1'], next
	(err, result, next) ->
		@update 'Language', null, context, '', {tanya: true}, next
	(err, result, next) ->
		# FIXME: sort!
		#@query 'Language', 'tanya!=false&select(foo)&sort(-id)', next
		@query 'Language', null, context, 'tanya!=false&select(foo)', next
	(err, result, next) ->
		#console.log 'QUERIED', arguments
		@remove 'Language', context, 'all!=true', next
	(err, result, next) ->
		time1 = Date.now()
		console.log 'START:', next.group
		nonce = () -> Math.random().toString().substring(2)
		add = db.add.bind db, 'Language', null, context
		#group = next.group()
		for i in [10000...0]
			do () ->
				add {name: nonce()}, (err, result) ->
					next() unless i
				#add {name: nonce()}, (err, result) ->
				#	group()() unless i
				#add {name: nonce()}, group()
		return
	(err, result, next) ->
		time2 = Date.now()
		# 6000
		# 5500 id <-> _id
		# 5300 emit 'add', ...
		# 4100 _meta
		# 3900 schema null
		console.log 'DONE:', "#{10000000/(time2-time1)} doc/sec"
		#console.log 'QUERYNEXT', next.toString()
		@query 'Language', s, context, 'limit(10)', next
	(err, result, next) ->
		console.log 'QUERIED', arguments
