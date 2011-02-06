#!/usr/bin/env coffee

faker = require 'faker'
assert = require 'assert'

nonce = () -> Math.random().toString().substring(2)

fillEntity = (name, factory) ->
	topic: (ctx) ->
		ctx[name].remove ctx, 'fake!=true', @callback
	'entity clean':
		topic: (ctx) ->
			ctx[name].query ctx, '', @callback
		'no result, no error': (err, result) ->
			console.log "#{name} clean"
			assert.equal err, null
			assert.deepEqual result, []
		'adding 10':
			topic: (xxx, ctx) ->
				done = @callback
				count = 10
				while count--
					ctx[name].add ctx, factory(), (err, result) ->
						#console.error 'CNT', count
						if err
							console.error 'ERROR', err, err.stack
							count += 1
						else
							ctx[name].query ctx, '', done if count < 0
				return
			'added 10 documents': (r) ->
				#console.log '10', arguments
				assert.isArray r
				assert.length r, 10
				#assert.deepEqual result, []

changeUserType = (name, type) ->
	topic: (ctx) ->
		ctx[name].update ctx, '', {type: 'root'}, @callback
	'fetch': (result) ->
		assert.isUndefined result
	'check types':
		topic: (ctx) ->
			ctx[name].query ctx, "type=#{type}", @callback
		'all 10': (result) ->
			assert.length result, 10

changeID = (name) ->
	topic: (ctx) ->
		done = @callback
		ctx[name].query ctx, '', (err, result) ->
			saved = result
			ctx[name].update ctx, '', {id: 'asd', _meta: 'dsa'}, (err, result) ->
				ctx[name].query ctx, '', (err, result) ->
					done err, saved: saved, result: result
	'fetch': (r) ->
		saved = _.sortBy r.saved, (x) -> x.id
		result = _.sortBy r.result, (x) -> x.id
		assert.length saved, 10
		assert.length result, 10
		for i in [0...10]
			assert.deepEqual saved[i], result[i]

module.exports = (app) ->

	vows = require 'vows'

	globals = {}

	vows.describe('Capabilities').addBatch(
		'Basic':
			topic: {a: 'b'},
			'prepare': (topic) ->
				# BEWARE!
				require = () -> console.error 'FORBIDDEN'
				assert.isFunction require
			'can get context': (topic) ->
				assert.isFunction app.getContext
				assert.length app.getContext, 2
			'get guest context':
				topic: () ->
					app.getContext 'fake user', @callback
				'context user should be empty': (ctx) ->
					assert.isEmpty ctx.user
				'context user should be frozen': (ctx) ->
					# FIXME: this is a clone of context?!
					###
					assert.throws (() -> ctx.user.id = 'root'), TypeError
					assert.throws (() -> ctx.user = 'root'), TypeError
					assert.throws (() -> ctx.forgedMethod = () -> 123), TypeError
					assert.throws (() -> delete ctx.user), TypeError
					###
				'context should have only getRoot': (ctx) ->
					assert.deepEqual _(ctx).functions().sort((x) -> x), ['getRoot']
					assert.length ctx.getRoot, 3
				'guest caps':
					topic: (ctx) ->
						globals.guestCtx = ctx
						ctx.getRoot.call undefined, ctx, 'this is just ignored', @callback
					'guest caps should have dummy user': (root) ->
						assert.deepEqual root.user,
							id: undefined
							email: undefined
							type: undefined
					'guest caps should have schema reflecting context': (root) ->
						schema = {}
						_(globals.guestCtx).functions().map (x) -> schema[x] = true
						assert.deepEqual root.schema, schema
					'guest should have no access to users': (root) ->
						assert.isUndefined root.schema.Affiliate
						assert.isUndefined root.schema.Admin
						assert.isUndefined root.schema.Merchant
			'get root context':
				topic: () ->
					app.getContext 'root', @callback
				'context user should be root': (ctx) ->
					assert.equal ctx.user.id, 'root'
					assert.equal ctx.user.type, 'root'
				'context user should be frozen': (ctx) ->
					# FIXME: this is a clone of context?!
					###
					assert.throws (() -> ctx.user.id = 'root'), TypeError
					assert.throws (() -> ctx.user = 'root'), TypeError
					assert.throws (() -> ctx.forgedMethod = () -> 123), TypeError
					assert.throws (() -> delete ctx.user), TypeError
					###
				'context should have only getRoot/getProfile/setProfile': (ctx) ->
					assert.deepEqual _(ctx).functions().sort((x) -> x), ['getProfile', 'getRoot', 'setProfile']
					assert.length ctx.getRoot, 3
					assert.length ctx.getProfile, 2
					assert.length ctx.setProfile, 3
				'root should have access to users': (ctx) ->
					#console.error root, schema
					assert.include ctx.Affiliate, 'update'
					assert.include ctx.Admin, 'add'
					assert.include ctx.Merchant, 'remove'
				'root caps':
					topic: (ctx) ->
						globals.rootCtx = ctx
						ctx.getRoot.call undefined, ctx, 'this is just ignored', @callback
					'root has access to users': (root) ->
						#console.error root, schema
						assert.isObject root.schema.Affiliate
						assert.isObject root.schema.Admin
						assert.isObject root.schema.Merchant
					'root has access to entities': (root) ->
						#console.error root, schema
						assert.isObject root.schema.Language
						assert.isObject root.schema.Currency
						assert.isObject root.schema.Country
				'root can reset/fill entities': {
					'Language': fillEntity 'Language', () ->
						id: faker.Lorem.words(3).join('')
						name: faker.Lorem.sentence(1)
						localName: faker.Lorem.sentence(1)
					'Currency': fillEntity 'Currency', () ->
						id: faker.Lorem.words(3).join('').substring(1, 4).toUpperCase()
						name: faker.Lorem.sentence(1)
						value: faker.Helpers.randomNumber(100)
					'Region': fillEntity 'Region', () ->
						id: faker.Lorem.words(3).join('_').toUpperCase()
						name: faker.Lorem.sentence(1)
					'Country': fillEntity 'Country', () ->
						id: faker.Lorem.words(3).join('').toUpperCase()
						name: faker.Lorem.sentence(1)
						region: faker.Lorem.words(3).join('_').toUpperCase()
					'Admin': fillEntity 'Admin', () ->
						id: faker.Lorem.words(2).join('')
					'Affiliate': fillEntity 'Affiliate', () ->
						id: faker.Lorem.words(2).join('')
					'Merchant': fillEntity 'Merchant', () ->
						id: faker.Lorem.words(2).join('')
					}
	).addBatch(
		'Full gas':
			topic: () -> app.getContext 'root', @callback
			'change users types should fail':
				'Admin': changeUserType 'Admin', 'admin'
				'Affiliate': changeUserType 'Affiliate', 'affiliate'
				'Merchant': changeUserType 'Merchant', 'merchant'
			'change id should fail':
				'Language': changeID 'Language'
				'Currency': changeID 'Currency'
				'Region': changeID 'Region'
				'Country': changeID 'Country'
	).run () -> console.log 'DONE', arguments
