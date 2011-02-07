#!/usr/local/bin/coffee
'use strict'

require.paths.unshift __dirname + '/../lib/node'

GeoIP = require('maxmind').GeoIP
geo = new GeoIP './GeoIP.dat'

getCountry = require('./maxmind') './GeoIPASNum.dat' # './GeoLiteCity.dat'

console.log getCountry '80.246.64.6', true
console.log getCountry '79.171.11.94', true
console.log getCountry '212.119.127.33', true
console.log getCountry '121.11.127.33', false
process.exit 0

#geoip = new (require('geoip').GeoIP) './GeoLiteCity.dat'

assert = require 'assert'
faker = require 'faker'
n255 = -> faker.Helpers.randomNumber 256
for i in [0...10000]
	ip = n255() + '.' + n255() + '.' + n255() + '.' + n255()
	vanilla = geo.getCountry ip, 'id'
	mine = getCountry ip
	#mmaped = geoip._seekCountry geoip.ip2num ip
	assert.deepEqual vanilla, mine, "vanilla: #{vanilla}, mine: #{mine}, ip: #{ip}"
	#console.log vanilla, mine, mmaped
	#assert.equal vanilla, mmaped - 16776960
	#mine = getCountry ip
	#console.log mine
