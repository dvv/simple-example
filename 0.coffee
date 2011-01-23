#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

sys = require 'util'
console.log = () ->
	for arg in arguments
		sys.debug sys.inspect arg

Compose = require 'compose'

aaa = (base) -> Object.freeze Object.create null, {
	id:
		get: () -> base.id
	creator:
		get: () -> base.creator
	pass1:
		get: () -> base.pass
	bar:
		get: () -> base.bar
	foo:
		get: () -> base.foo
		set: (value) -> base.foo = value
	pass:
		set: (value) -> base.pass = value
}

obj =
	foo: 'bar'
	bar: 'baz'
	pass: 'hz'

obj1 = aaa obj

#console.log obj1.pass, obj1.pass1

f1Factory = (text) ->
	(req, res, next) ->
		console.log text
		next()

f2Factory = () ->
	(req, res, next) ->
		console.log 'F22'
		#req.result = {foo: 'bar'}
		next()
		#if Math.random() >= 0.5
		#	next()
		#else
		#	res.writeHead 444
		#	res.end()

f3 = (req, res, next) ->
	console.log 'F33'
	res.writeHead 200
	if req.result
		res.end JSON.stringify req.result
	else
		next()

f4 = (req, res, next) ->
	console.log 'F33'
	next()

require('http').createServer(require('stack')(
	#require('loggerMiddleware')(),
	#require('staticMiddleware')(root, mount)
	require('creationix/auth')({dvv: "hashedpasswordhere"}),
	f1Factory('F111'),
	f2Factory(),
	f3
)).listen(3000)
