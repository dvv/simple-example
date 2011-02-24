#!/usr/local/bin/coffee
'use strict'

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 20

fetchCourses = require('./geo').fetchCoursesXurrency
#fetchCourses = require('./geo').fetchCoursesForex
#fetchCourses = require('./geo').fetchCoursesCBR
#fetchCourses = require('./geo').fetchCoursesECB

fetchCourses 'usd', console.log
process.exit 0
