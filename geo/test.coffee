#!/usr/local/bin/coffee
'use strict'

require.paths.unshift __dirname + '/../lib/node'

GeoIP = require('maxmind').GeoIP
geo = new GeoIP './GeoLiteCity.dat.0'

getCountry = require('./maxmind') './GeoLiteCity.dat.0'

#geoip = new (require('geoip').GeoIP) './GeoLiteCity.dat'

assert = require 'assert'
faker = require 'faker'
n255 = -> faker.Helpers.randomNumber 256
for i in [0...100000]
	ip = n255() + '.' + n255() + '.' + n255() + '.' + n255()
	vanilla = geo.getCountry ip, 'id'
	mine = getCountry ip, 'id'
	#mmaped = geoip._seekCountry geoip.ip2num ip
	assert.equal vanilla, mine
	#console.log vanilla, mine, mmaped
	#assert.equal vanilla, mmaped - 16776960
	#mine = getCountry ip
	#console.log mine
