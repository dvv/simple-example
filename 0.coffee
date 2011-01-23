#!/usr/bin/env coffee
'use strict'

require.paths.unshift __dirname + '/lib/node'

sys = require 'util'
#inspect = require('eyes.js').inspector stream: null
#oldConsoleLog = console.log

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

console.log obj1.pass, obj1.pass1
