'use strict'

#
# uses dvv/simple/remote helper
#
parseLocation = require('simple/remote').parseLocation

#
# fetch currency courses from http://xurrency.com
#
module.exports.fetchCoursesXurrency = (referenceCurrency = 'usd', next) ->
	parseLocation "http://xurrency.com/#{referenceCurrency.toLowerCase()}/feed", (err, dom) ->
		course = dom[1].children.map (rec) ->
			id: rec.children[9]?.children[0].data
			value: +rec.children[10]?.children[0].data
			#date: Date rec.children[4]?.children[0].data
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
# fetch currency courses from http://www.forexrate.co.uk/ExchangeRates
#
module.exports.fetchCoursesForex = (referenceCurrency = 'usd', next) ->
	parseLocation "http://www.forexrate.co.uk/ExchangeRates/#{referenceCurrency.toUpperCase()}.html", (err, dom) ->
		trs = dom[1].children[1].children[0].children[2].children[5].children
		course = {}
		trs.slice(2).forEach (rec) ->
			if rec.type is 'tag' and rec.name is 'tr'
				id = rec.children[1].children[0].attribs?.href.substr(15,3)
				date = rec.children[3].children[0].data.trim()
				# FIXME: ILS -- noname?
				course[id] =
					id: id
					name: rec.children[1].children?[0].children?[0].data
					value: +rec.children[2].children[0].data.trim().replace(/,/g,'')
					#date: new Date(date.substr(6,4) + '-' + date.substr(3,2) + '-' + date.substr(0,2))
		next null, course

#
# fetch currency courses from http://cbr.ru/currency_base/daily.aspx
#
module.exports.fetchCoursesCBR = (referenceCurrency = 'usd', next) ->
	date = (new Date()).toJSON().substr(0,10)
	mreq = date.substr(5,2)
	yreq = date.substr(0,4)
	dreq = date.substr(8,2) + '%2E' + mreq + '%2E' + yreq
	parseLocation "http://cbr.ru/currency_base/D_print.aspx?date_req=#{dreq}", (err, dom) ->
		fn = (node) ->
			if node.name is 'table' and node.attribs?.class is 'CBRTBL'
				course = {}
				node.children.slice(1).forEach (tr) ->
					value = +tr.children[4].children[0].data.replace(/,/g,'.') / +tr.children[2].children[0].data
					course[tr.children[1].children[0].data.trim().replace(/&nbsp;/g,'')] = value
				base = course[referenceCurrency.toUpperCase()]
				for own k, v of course
					course[k] =
						id: k
						value: +((v / base).toFixed(4))
				#console.log course
				next null, course
			else if node.children
				node.children.forEach fn
		dom.forEach fn

#
# fetch world countries with some ISO info from various WIKI pages
#
module.exports.fetchGeo = (next) ->
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
