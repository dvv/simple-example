#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

Compose = require 'compose'
parseQuery = require('rql/parser').parseGently

sys = require 'util'
p = (args...) ->
	(args or []).forEach (result) ->
		if result?.then
			result.then p
		else
			console.log sys.inspect result

Store = (entity) ->
	add: () ->
		p "ADD #{entity}", arguments, this
		{}
	remove: () ->
		p "REMOVE #{entity}", arguments, this
	update: (changes) ->
		p "UPDATE #{entity}", arguments, this
	all: () ->
		p "ALL #{entity}", arguments, this
		[]
	one: () ->
		p "ONE #{entity}", arguments, this
		[]
	where: (query) ->
		store = @
		q = parseQuery query
		Object.defineProperty q, 'add', value: (doc) -> store.add q, doc
		Object.defineProperty q, 'remove', value: () -> store.remove q
		Object.defineProperty q, 'update', value: (changes) -> store.update q, changes
		Object.defineProperty q, 'all', value: () -> store.all q
		Object.defineProperty q, 'one', value: () -> store.one q
		q

Model = (entity, store, overrides) ->
	Compose.create store or Store(entity), {id: entity}, overrides

User = Model 'User', null, {
	getLatestPosts: () ->
		User.where("user=#{@uid},sort(-date),limit(5)").all()
}

#p User.where('a=b').all()
#p User.where().add({foo:'bar'})
#p User.where().add({foo:'bar'})
p User.where('a=b').update({bar:'baz'})
#p User.getLatestPosts({foo:'bar'})
