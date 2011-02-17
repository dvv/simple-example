'use strict'

#
# uses dvv/simple/remote helper
#
parseLocation = require('simple/remote').parseLocation

#
# fetch currency courses from http://xurrency.com
#
fetchCourses = (referenceCurrency = 'usd', next) ->
	parseLocation "http://xurrency.com/#{referenceCurrency.toLowerCase()}/feed", (err, dom) ->
		course = dom[1].children.map (rec) ->
			id: rec.children[9]?.children[0].data
			value: +rec.children[10]?.children[0].data
			date: Date rec.children[4]?.children[0].data
		course[0].id = referenceCurrency.toUpperCase()
		course[0].value = 1
		temp = {}
		course.forEach (x) -> temp[x.id] = x
		course = temp
		parseLocation 'http://xurrency.com/currencies', (err, dom) ->
			currs = dom[1].children[1].children[0].children[1].children[0].children[4].children.slice(1)
			currs.forEach (rec) ->
				x = rec.children[1].children[0]
				course[x.attribs.href.substring(1).toUpperCase()]?.name = x.children[0].data
			#console.log course
			#process.exit 0
			next null, course

#
# fetch world countries with some ISO info from various WIKI pages
#
fetchGeo = (next) ->
	#console.log 'FETCHGEO'
	geo = {}
	geoByName = {}
	parseLocation 'http://en.wikipedia.org/wiki/ISO_3166-1', (err, data) ->
		fn = (node) ->
			if node.name is 'table' and node.attribs?.class is 'wikitable sortable'
				#console.log 'NODE?'
				node.children.slice(1).forEach (tr) ->
					#console.log tr.children[0].children[1]
					id = tr.children[1].children[0].children[0].children[0].data
					geo[id] =
						id: id
						name: decodeURI(tr.children[0].children[1]?.attribs?.title or tr.children[0].children[1].children[1]?.attribs?.title)
						#wiki: tr.children[0].children[1].attribs?.href or tr.children[0].children[1].children[1].attribs?.href
						iso3: tr.children[2].children[0].children[0].data
						code: tr.children[3].children[0].children[0].data
					geoByName[geo[id].name] = id
			else if node.children
				node.children.forEach fn
		data.forEach fn
		parseLocation 'http://en.wikipedia.org/wiki/List_of_countries_by_continent_(data_file)', (err, data) ->
			fn = (node) ->
				if node.name is 'pre'
					node.children[0].data.split('\n').forEach (x) ->
						[cont, id] = x.split(' ').slice(0, 2)
						if id and geo[id]
							geo[id].cont = cont
						else if id
							console.error 'NO COUNTRY', id, cont
				else if node.children
					node.children.forEach fn
			data.forEach fn
			parseLocation 'http://en.wikipedia.org/wiki/List_of_time_zones_by_country', (err, data) ->
				#console.log data
				fn = (node) ->
					if node.name is 'table' and node.attribs?.class is 'wikitable sortable'
						#console.log 'NODE?'
						node.children.slice(1).forEach (tr) ->
							#console.log tr.children[2].children
							name = tr.children[0].children[1].attribs.title
							#############
							# FIXME: two kingdoms
							#
							if name.substring(0,11).toLowerCase() is 'kingdom of '
								name = name.split(' ').slice(-1)
							#
							#############
							id = geoByName[name]
							if not geo[id]
								console.error 'TZ FOR NO COUNTRY', name
								return
							geo[id].tz = []
							tr.children[2].children.forEach (x) ->
								if x.name is 'a' and x.attribs.title.substring(0,3) is 'UTC'
									geo[id].tz.push x.attribs.title
					else if node.children
						node.children.forEach fn
				data.forEach fn
				next null, geo

module.exports =
	fetchGeo: fetchGeo
	fetchCourses: fetchCourses
