'use strict'

#
# HTML parser
#
parseLocation = require('simple/remote').parseLocation

sources = {}

#
# fetch currency courses from http://whoyougle.com/money/list
#
sources.who = (referenceCurrency = 'usd', next) ->
	parseLocation 'http://whoyougle.com/money/list', (err, dom) ->
		fn = (node) ->
			course = {}
			if node.name is 'table' and node.attribs?.id is 'DataTable'
				node.children[1].children.forEach (tr) ->
					rec =
						id: tr.children[3].children[0].data
						name: tr.children[0].children[0].children?[0].data or tr.children[0].children[0].data
					if tr.children[5].children?[0].data
						rec.value = +tr.children[5].children[0].data
					course[rec.id] = rec
				# normalize
				course.GBP.value = 1
				base = course[referenceCurrency.toUpperCase()]?.value or 1
				for own k, v of course
					course[k] =
						id: k
						name: v.name
					if v.value
						course[k].value = base / v.value
				next null, course
			else if node.children
				node.children.forEach fn
		dom.forEach fn

#
# fetch currency courses from http://xurrency.com
#
sources.xur = (referenceCurrency = 'usd', next) ->
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
		next null, course

#
# fetch currency courses from http://www.forexrate.co.uk/ExchangeRates
#
sources.for = (referenceCurrency = 'usd', next) ->
	parseLocation "http://www.forexrate.co.uk/ExchangeRates/#{referenceCurrency.toUpperCase()}.html", (err, dom) ->
		course = {}
		dom[1].children[1].children[0].children[2].children[5].children.slice(2).forEach (rec) ->
			if rec.type is 'tag' and rec.name is 'tr'
				id = rec.children[1].children[0].attribs?.href.substr(15,3)
				date = rec.children[3].children[0].data.trim()
				course[id] =
					id: id
					value: +rec.children[2].children[0].data.trim().replace(/,/g,'')
		next null, course

#
# fetch currency courses from http://cbr.ru/currency_base/daily.aspx
#
sources.cbr = (referenceCurrency = 'usd', next) ->
	date = (new Date()).toJSON().substr(0,10)
	mreq = date.substr(5,2)
	yreq = date.substr(0,4)
	dreq = date.substr(8,2) + '%2E' + mreq + '%2E' + yreq
	parseLocation "http://cbr.ru/currency_base/D_print.aspx?date_req=#{dreq}", (err, dom) ->
		fn = (node) ->
			if node.name is 'table' and node.attribs?.class is 'CBRTBL'
				course =
					RUB: 1
				node.children.slice(1).forEach (tr) ->
					value = +tr.children[2].children[0].data / +tr.children[4].children[0].data.replace(/,/g,'.')
					course[tr.children[1].children[0].data.trim().replace(/&nbsp;/g,'')] = value
				# normalize
				base = course[referenceCurrency.toUpperCase()] or 1
				for own k, v of course
					course[k] =
						id: k
						value: v / base
				next null, course
			else if node.children
				node.children.forEach fn
		dom.forEach fn

#
# fetch currency courses from http://www.ecb.int/stats/eurofxref/eurofxref-daily.xml
#
sources.ecb = (referenceCurrency = 'usd', next) ->
	parseLocation "http://www.ecb.int/stats/eurofxref/eurofxref-daily.xml", (err, dom) ->
		course =
			EUR: 1
		dom[1].children[2].children[0].children.forEach (tr) ->
			course[tr.attribs.currency] = +tr.attribs.rate
		# normalize
		base = course[referenceCurrency.toUpperCase()] or 1
		for own k, v of course
			course[k] =
				id: k
				value: v / base
		next err, course

#
# compile data from defined above sources
#
fetchExchangeRates = (referenceCurrency = 'usd', next) ->
	course = {}
	arr = Object.keys sources
	narr = arr.length
	arr.forEach (source) ->
		sources[source] referenceCurrency, (err, data) ->
			#console.log 'GET', source, err, data
			unless err
				for own k, v of data
					if not course[k]
						course[k] =
							id: k
							#name: '---'
							value: {}
					course[k].name = v.name if v.name
					course[k].value[source] = v.value if v.value
			narr -= 1
			next null, course unless narr
		return

module.exports =
	fetchExchangeRates: fetchExchangeRates
