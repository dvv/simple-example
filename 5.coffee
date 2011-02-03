#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'
global._ = require 'underscore'

_.mixin
	rql: require('jse/rql').rql

inspect = require('eyes.js').inspector stream: null
consoleLog = console.log
console.log = () -> consoleLog inspect arg for arg in arguments

Next = (context, steps...) ->
	next = (err, result) ->
		unless steps.length
			throw err if err
			return
		fn = steps.shift()
		try
			fn.call context, err, result, next
		catch err
			next err
		return context
	next()

###
a = () -> Next {foo: 'bar'},
	(err, result, next) ->
		console.log 'first', arguments
		return next err if err
		#throw 'Catch me1!'
		next 'err1', 'res1'
	(err, result, next) ->
		console.log 'second', arguments
		return next err if err
		next 'err2', 'res2'
	(err, result, next) ->
		console.log 'third', arguments
		return next err if err
		next 'err3', 'res3'

try
	console.log 'A', a()
catch err
	console.log 'CAUGHT', err
###

parseUrl = require('url').parse
mongo = require 'mongodb'

class Database
	constructor: (@url) ->
		conn = parseUrl @url
		@host = conn.hostname
		@port = +conn.port if conn.port
		@auth = conn.auth if conn.auth # FIXME: what is options analog?
		@name = conn.pathname.substring(1) if conn.pathname
		@collections = {}
		@idFactory = () ->
			(new mongo.BSONPure.ObjectID).toHexString()
		@db = new mongo.Db @name, new mongo.Server(@host, @port)
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
	query: (collection, query, callback) ->
		query = _.rql(query).toMongo()
		Next @,
			(err, result, next) ->
				#console.log 'FIND!', query
				@collections[collection].find query.search, query.meta, (err, cursor) ->
					return callback err if err
					cursor.toArray (err, docs) ->
						#console.log 'FOUND', arguments
						callback err, docs
	get: (collection, id, callback) ->
		@query collection, _.rql('limit(1)').eq('id',id), (err, result) ->
			return callback err if err
			callback null, result[0] or null
	add: (collection, document, callback) ->
		Next @,
			(err, coll, next) ->
				document._id = @idFactory() unless document._id
				@collections[collection].insert document, {safe: true}, (err, result) ->
					if err
						if err.message.substring(0,6) is 'E11000'
							err.message = 'Duplicated'
						return callback err.message
					callback null, document
	put: (collection, document, callback) ->
		Next @,
			(err, coll, next) ->
				@collections[collection].update {_id: document._id}, document, (err, result) ->
					callback err
	update: (collection, query, changes, callback) ->
		query = _.rql(query).toMongo()
		query.search.$atomic = 1
		changes = $set: changes
		Next @,
			(err, coll, next) ->
				@collections[collection].update query.search, changes, {multi: true}, (err, result) ->
					callback err
	remove: (collection, query, callback) ->
		query = _.rql(query).toMongo()
		# naive fuser
		return callback 'Refuse to remove all documents w/o conditions' unless _.keys(query.search).length
		Next @,
			(err, coll, next) ->
				@collections[collection].remove query.search, (err) ->
					callback err

db = new Database 'mongodb://127.0.0.1:27017/simple'
Next db,
	(err, result, next) ->
		@open ['Language'], next
	(err, result, next) ->
		@add 'Language', {_id: 'fr1'}, next
	(err, result, next) ->
		@add 'Language', {foo: 'bar'}, next
	(err, result, next) ->
		@put 'Language', {_id: 'fr2', name: 'Francais'}, next
	(err, result, next) ->
		@get 'Language', 'fr1', next
	(err, result, next) ->
		@remove 'Language', ['fr1'], next
	(err, result, next) ->
		@update 'Language', '', {tanya: true}, next
	(err, result, next) ->
		# FIXME: sort!
		#@query 'Language', 'tanya!=false&select(foo)&sort(-id)', next
		@query 'Language', 'tanya!=false&select(foo)', next
	(err, result, next) ->
		@remove 'Language', 'all!=true', next
	(err, result, next) ->
		console.log 'START:', Date.now(), next.toString()
		nonce = () -> Math.random.toString().substring(2)
		for i in [1000...0]
			do () -> db.add 'Language', {name: nonce()}, (err, result) -> next() unless i
		#console.log 'STARTED:', Date.now()
		return
	(err, result, next) ->
		console.log 'DONE:', Date.now()
