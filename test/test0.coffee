####!/usr/local/bin/coffee
'use strict'

require.paths.unshift __dirname + '/../lib/node'

config = require '../config'
simple = require 'jse'
app = require '../app'

#{SecuredStore} = require('jse/store') config.database

###
model.User.query.call({user:{id:'root'}},'',console.log)
model.User.update.call({user:{id:'root'}},'id=a1',{password:123},console.log)
###

testCase = require('nodeunit').testCase

# TODO: for tests delete/undelete/purge should be in facets
context = {}

module.exports = testCase

	setUp: (callback) ->
		app.getContext 'root', (err, result) ->
			context = result
			callback()

	tearDown: (callback) ->
		callback()

	testMerchant: (test) ->
		context.entity = 'Merchant'
		Next context,
			(err, result, next) ->
				@[@entity].delete.call @, 'dummyfield!=dummyvalue', next
			(err, result, next) ->
				test.ok not err and not result, 'deleted ok'
				@[@entity].query.call @, '', next
			(err, result, next) ->
				test.ok not err, 'query ok'
				test.deepEqual result, [], 'empty recordset'
				@[@entity].add.call @, {id: 'a', name: 'Foo1'}, next
			(err, result, next) ->
				test.ok not err, 'added ok'
				test.ok result.id is 'a' and not result.name, 'added ok'
				@[@entity].add.call @, {id: 'a', name: 'Foo2'}, next
			(err, result, next) ->
				test.equal err, 'Duplicated', 'duplicated nak'
				@[@entity].add.call @, {id: 'b', name: 'Foo2'}, next
			(err, result, next) ->
				test.ok not err and result.id is 'b' and not result.name, 'added ok'
				@[@entity].add.call @, {id: 'c', name: 'Foo3'}, next
			(err, result, next) ->
				test.ok not err and result.id is 'c' and not result.name, 'added ok'
				@[@entity].query.call @, ['a', 'b', 'c'], next
			(err, result, next) ->
				test.ok not err and result.length is 3, 'queried 3 documents'
				@[@entity].query.call @, '(id=a|id=c)', next
			(err, result, next) ->
				test.ok not err and result.length is 2, 'queried 2 documents of ids a and c'
				test.ok result[0].id is 'a' and result[1].id is 'c'
				@[@entity].update.call @, 'in(id,(a,b))', {blocked: true, rights: 'whatever', type: 'admin', name: 'nonauthorized', email: 'fake', password: 'takeover'}, next
			(err, result, next) ->
				test.ok not err and not result
				@[@entity].query.call @, 'select(type)', next
			(err, result, next) ->
				test.ok not err and result.length is 3, 'queried 3 documents, only type attribute'
				test.ok _.all result, (x) -> x.type is 'merchant'
				@[@entity].query.call @, 'select(-type)', next
			(err, result, next) ->
				console.log arguments
				test.ok not err and result.length is 3, 'queried 3 documents, kick out type attribute'
				test.ok _.all result, (x) -> if x.id in ['a', 'b'] then x.rights is 'whatever' else not x.rights
				test.done()

###
				@[@entity].remove.call @, 'id!=re:aa', next
			(err, result, next) ->
				test.ok not err and not result, 'removed 1 document of ids not matching /aa/i'
				@[@entity].query.call @, 'values(id)', next
			(err, result, next) ->
				test.ok not err and result.length is 2, 'queried 2 remaining documents'
				test.deepEqual result, [['AAA'], ['AAB']], 'documents have expected ids'
				@[@entity].undelete.call @, '', next
			(err, result, next) ->
				console.log arguments
				test.ok not err and not result, 'undelete documents'
				@[@entity].get.call @, 'ABA', next
			(err, result, next) ->
				test.ok not err and result?.id is 'ABA', 'undeleted document ok'
				test.done()
###


###
	testRegion: (test) ->
		context.entity = 'Region'
		#store = SecuredStore context.entity
		Next context,
			(err, result, next) ->
				@[@entity].delete.call @, 'dummyfield!=dummyvalue', next
			(err, result, next) ->
				test.ok not err and not result, 'deleted ok'
				@[@entity].query.call @, '', next
			(err, result, next) ->
				test.ok not err, 'query ok'
				test.deepEqual result, [], 'empty recordset'
				@[@entity].add.call @, {id: 'AAA'}, next
			(err, result, next) ->
				test.deepEqual err, [{property: 'name', message: 'required'}], 'validation nak'
				@[@entity].add.call @, {id: 'AAA', name: 'Foo'}, next
			(err, result, next) ->
				test.ok not err, 'added ok'
				test.ok result.id is 'AAA' and result.name is 'Foo', 'added ok'
				@[@entity].add.call @, {id: 'AAA', name: 'Foo1'}, next
			(err, result, next) ->
				test.equal err, 'Duplicated', 'duplicated nak'
				@[@entity].add.call @, {id: 'AAB', name: 'Foo2'}, next
			(err, result, next) ->
				test.ok not err and result.id is 'AAB' and result.name is 'Foo2', 'added ok'
				@[@entity].add.call @, {id: 'ABA', name: 'Foo3'}, next
			(err, result, next) ->
				test.ok not err and result.id is 'ABA' and result.name is 'Foo3', 'added ok'
				@[@entity].query.call @, '', next
			(err, result, next) ->
				test.ok not err and result.length is 3, 'queried 3 documents'
				@[@entity].query.call @, 'id=re:aa', next
			(err, result, next) ->
				test.ok not err and result.length is 2, 'queried 2 documents of ids matching /aa/i'
				@[@entity].query.call @, 'id!=re:aa', next
			(err, result, next) ->
				test.ok not err and result.length is 1, 'queried 1 document of ids not matching /aa/i'
				@[@entity].update.call @, 'id=re:aa', {foo: 'bar', _meta: 'tainted', name: 'Foos', id: 'ZZZ'}, next
			(err, result, next) ->
				test.ok not err and not result, 'updated 2 documents of ids matching /aa/i, name set to Foos'
				@[@entity].query.call @, 'foo=null', next
			(err, result, next) ->
				test.ok not err and result.length is 3, 'queried 3 documents, foo attribute not set'
				@[@entity].remove.call @, 'id!=re:aa', next
			(err, result, next) ->
				test.ok not err and not result, 'removed 1 document of ids not matching /aa/i'
				@[@entity].query.call @, 'values(id)', next
			(err, result, next) ->
				test.ok not err and result.length is 2, 'queried 2 remaining documents'
				test.deepEqual result, [['AAA'], ['AAB']], 'documents have expected ids'
				@[@entity].undelete.call @, '', next
			(err, result, next) ->
				test.ok not err and not result, 'undelete documents'
				@[@entity].get.call @, 'ABA', next
			(err, result, next) ->
				test.ok not err and result?.id is 'ABA', 'undeleted document ok'
				test.done()
###

