#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

require 'jse'

time1 = null
time2 = null

context =
	user:
		id: 'dummy'

schema = require './schema'

###
UU = db.Entity('User', null, {signup: function(uid){return this.add({user:'tricky'},{name:'123'})}})
db.model.User.signup.call(db.model.Language)
###

model = {}
facet = model

All context,
	(err, result, next) ->
		new (require('jse/database').Database) '', schema, next
	(err, exposed, next) ->
		facet = model = _.freeze exposed
		###
					# register permissive facet -- set of entity accessors
					expose = ['schema', 'id', 'query', 'get', 'add', 'update', 'remove']
					expose = expose.concat ['delete', 'undelete', 'purge'] if @attrInactive
					self.facet[name] = _.proxy store, expose
		###
		global.facet = facet
		facet.Language.query @, 'limit(5)&sort(-id)', next
	(err, result, next) ->
		console.log 'QUERIED', arguments
		require('repl').start 'test>'

###
		facet.Language.remove @, 'all!=true', next
	(err, result, next) ->
		console.log 'REMOVED', arguments
		facet.Language.add @, {id: 'fr1', name: 'name1', localName: 'Chti'}, next
	#(err, result, next) ->
	#	console.log 'ADDED1', arguments
	#	facet.Language._add null, @, {foo: 'bar'}, next
	(err, result, next) ->
		console.log 'ADDED2', arguments
		facet.Language.get @, 'fr1', next
	(err, result, next) ->
		console.log 'GOT fr1', arguments
		facet.Language._query null, @, ['fr1'], next
	(err, result, next) ->
		console.log '_GOT fr1', arguments
		facet.Language._update null, @, '', {tanya: true}, next
	(err, result, next) ->
		facet.Language.delete @, 'id=re:fr1', next
	(err, result, next) ->
		console.log 'DELETED', arguments
		facet.Language.query @, 'tanya!=false&select(foo)&sort(-id)', next
	(err, result, next) ->
		console.log 'QUERIED', arguments
		facet.Language.undelete @, ['fr1'], next
	(err, result, next) ->
		console.log 'UNDELETED', arguments
		facet.Language.query @, 'tanya!=false&select(foo)&sort(-id)', next
	(err, result, next) ->
		console.log 'QUERIED', arguments
		time1 = Date.now()
		console.log 'START:', next.group
		nonce = () -> Math.random().toString().substring(2)
		#group = next.group()
		for i in [10...0]
			do () ->
				facet.Language.add @, {name: nonce()}, (err, result) ->
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
		console.log 'DONE:', "#{10000/(time2-time1)} doc/sec"
		#console.log 'QUERYNEXT', next.toString()
		facet.Language._query null, @, 'limit(10)', next
	(err, result, next) ->
		console.log 'QUERIED', arguments
		require('repl').start 'test>'
###
