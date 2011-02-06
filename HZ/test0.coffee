#!/usr/local/bin/coffee
'use strict'

#
# tests
#

###
model.User.query.call({user:{id:'root'}},'',console.log)
model.User.update.call({user:{id:'root'}},'id=a1',{password:123},console.log)
###

#
# tests if doc created by user, or user creator
#
ownedBy = (doc, user, next) ->
	who = doc?._meta?.history[0].who
	console.log 'OWNED?', doc, user?.id
	if who is user?.id
		return next null, user
	model.User._get who, (err, parent) ->
		#console.log 'PARENT', arguments
		return next err, parent unless parent
		ownedBy parent, user, next


assert = require 'assert'
'''
Step(
	() ->
		console.log 'Fetching AAC'
		model.Region._get 'AAC', @
		return
	(err, result) ->
		console.log arguments
		assert.equal result.id, 'AAC'
		console.log 'Checking if AAC owned by root'
		ownedBy result, roots.root, @
		return
	(err, result) ->
		console.log 'OWNED', arguments
)
'''
'''
Step(
	() ->
		console.log 'Resetting collection'
		model.Language.delete '__nonexistent!=true', @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, null, 'remove ok'
		console.log 'Adding an empty document'
		model.Language.add {}, @
		return
	(err, result) ->
		console.log arguments
		assert.notEqual err, null, 'add empty nak'
		assert.equal result, null, 'add empty nak'
		console.log 'Adding a document'
		model.Language.add {id: 'RUS', name: 'Russian', localName: 'Русский', foo: 'bar'}, @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, null, 'add ok'
		assert.equal result.id, 'RUS', 'id is set'
		assert.equal result.foo, null, 'no additional props'
		console.log 'Querying all documents'
		model.Language.query '', @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.length, 1
		console.log 'Adding duplicate ID'
		model.Language.add {id: 'RUS', name: 'Russian', localName: 'Русский', foo: 'bar'}, @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, 'Duplicated'
		assert.equal result, null
		console.log 'Adding another document'
		model.Language.add {id: 'ENG', name: 'English', localName: 'English', _meta: {history: 'tainted'}}, @
		return
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.id, 'ENG', 'id is set'
		assert.equal result._meta, null, 'no additional props'
		console.log 'Updating localName'
		model.Language.update _.rql().eq('id', 'RUS'), {name: 'Russkiy', localName: 'Рашн'}, @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result, null
		console.log 'Getting RUS'
		model.Language.get 'RUS', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.deepEqual result, {id: 'RUS', name: 'Russkiy', localName: 'Рашн'}
		console.log 'Removing RUS'
		model.Language.remove 'id=RUS', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result, null
		console.log 'Counting 1'
		model.Language.query '', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.length, 1
		console.log 'Undeleting'
		model.Language.undelete '', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result, null
		console.log 'Counting 2'
		model.Language.query '', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.length, 2
		console.log 'Deleting'
		model.Language.delete 'i!=1', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result, null
		console.log 'Counting 3'
		model.Language.query '', @
	(err, result) ->
		console.log arguments
		assert.equal err, null
		assert.equal result.length, 0
		console.log 'Finishing'
	(err, result) ->
		console.log arguments
		#process.exit 0
)
'''
