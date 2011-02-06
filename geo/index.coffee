#!/usr/local/bin/coffee
'use strict'

require.paths.unshift __dirname + '/../lib/node'

GeoIP = require('maxmind').GeoIP

geo = new GeoIP './GeoLiteCity.dat'
console.log geo.getCountry '212.127.33.195'
