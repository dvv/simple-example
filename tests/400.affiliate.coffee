'use strict'

require.paths.unshift __dirname + '/../lib/node'

config = require '../config'
simple = require 'jse'
app = require '../app'

testCase = require('nodeunit').testCase

# TODO: for tests delete/undelete/purge should be in facets
context = {}

module.exports = testCase

	setUp: (callback) ->
		app.getContext 'g', (err, result) ->
			context = result
			callback()

	tearDown: (callback) ->
		callback()

	testEntities: (test) ->
		authority = []
		for own entity, facet of context
			continue if entity.match /^(get|set|login)/
			authority.push entity
		test.ok authority.length is 1 and authority[0] is 'Affiliate', 'Right to manage sub-affiliates'
		test.done()

	testProfile: (test) ->
		Next context,
			(err, result, next) ->
				@getProfile.call @, next
			(err, result, next) ->
				test.ok not err and result and result.type is 'affiliate' and result.lang and result.timezone, 'got profile'
				#test.ok not result.secret and not result.salt and not result.password, 'got no authentication info'
				test.ok (not result.secret or result.secret is 'gsecret') and not result.salt and not result.password, 'got no authentication info'
				@setProfile.call @, {secret: 'gsecret', 'rights': 'trytoelevate', type: 'trytoescape', lang: 'en', timezone: 'UTC+04'}, next
			(err, result, next) ->
				test.ok not err and result, 'setProfile should return the profile'
				test.ok result.secret is 'gsecret' and not result.rights and result.type is 'affiliate', 'got profile updated'
				@setProfile.call @, {lang: 'dummylang', timezone: 'UTC+01'}, next
			(err, result, next) ->
				test.ok err and not result, 'setProfile should return the error'
				@setProfile.call @, {lang: 'ru', timezone: 'UTC+05'}, next
			(err, result, next) ->
				test.ok not err and result, 'setProfile should return the profile'
				test.ok result.lang is 'ru' and result.timezone is 'UTC+05', 'language and timezone updated'
				@setProfile.call @, {id: 'lemmebeadminz', extrafoo: 'bar', blocked: true, active: false}, next
			(err, result, next) ->
				test.ok not err and result, 'setProfile should return the profile'
				test.ok result.id is 'g' and not result.extrafoo and not result.blocked, 'non-profile info intact'
				test.done()

	# TODO: test sub-affiliating

