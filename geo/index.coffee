#!/usr/local/bin/coffee
'use strict'

require.paths.unshift __dirname + '/../lib/node'

GeoIP = require('maxmind').GeoIP
geo = new GeoIP './GeoLiteCity.dat.0'
#console.log geo.getCountry '212.119.127.33', 'code'

#geo = new (require('geoip').GeoIP) './GeoLiteCity.dat'
#console.log geo.getRecordByAddr '79.171.11.94', geo.consts().COUNTRY_NAMES[185]

faker = require 'faker'
n255 = -> faker.Helpers.randomNumber 256
for i in [0...1000]
	ip = n255() + '.' + n255() + '.' + n255() + '.' + n255()
	#console.log geo.consts().COUNTRY_NAMES[185]
	#console.log ip, geo.getRecordByAddr ip
	console.log ip, geo.getCountry ip, 'code'

