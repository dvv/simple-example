_ = require './node_modules/underscore'

http = require 'http'
parseUrl = require('url').parse

geo = {}

geoByName = {}

htmlparser = require './node-htmlparser/lib/htmlparser'
parseHTML = (data, next) ->
	handler = new htmlparser.DefaultHandler (err, dom) ->
		next err, dom
	,
		ignoreWhitespace: true
		verbose: false
	parser = new htmlparser.Parser handler
	parser.parseComplete data

parseWIKI = (url, next) ->
	req = parseUrl url
	req =
		host: req.hostname
		port: req.port or 80
		path: req.pathname
		headers: {}
	if proxy = parseUrl process.env.http_proxy
		req.headers.host = req.host
		req.port = proxy.port or 80
		req.host = proxy.hostname
		req.path = url
	handler = new htmlparser.DefaultHandler (err, dom) ->
		next err, dom
	,
		ignoreWhitespace: true
		verbose: false
	parser = new htmlparser.Parser handler
	wget = http.get req, (res) ->
		if res.statusCode > 299
			return next res.statusCode
		res.on 'data', (data) -> parser.parseChunk data
		res.on 'end', -> parser.done()
		res.on 'error', (err) -> parser.done()

parseWIKI 'http://en.wikipedia.org/wiki/ISO_3166-1', (err, data) ->
	fn = (node) ->
		if node.name is 'table' and node.attribs?.class is 'wikitable sortable'
			#console.log 'NODE?'
			node.children.slice(1).forEach (tr) ->
				#console.log tr.children[0].children[1]
				id = tr.children[1].children[0].children[0].children[0].data
				geo[id] =
					id: id
					name: tr.children[0].children[1].attribs?.title or tr.children[0].children[1].children[1].attribs?.title
					wiki: tr.children[0].children[1].attribs?.href or tr.children[0].children[1].children[1].attribs?.href
					iso3: tr.children[2].children[0].children[0].data
					code: tr.children[3].children[0].children[0].data
				geoByName[geo[id].name] = id
		else if node.children
			node.children.forEach fn
	data.forEach fn
	parseWIKI 'http://en.wikipedia.org/wiki/List_of_countries_by_continent_(data_file)', (err, data) ->
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
		parseWIKI 'http://en.wikipedia.org/wiki/List_of_time_zones_by_country', (err, data) ->
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
			console.log _.toArray geo
			console.log _.size geo
		#console.log JSON.stringify geo

###
#parseWIKI 'http://en.wikipedia.org/wiki/%C3%85land_Islands', (err, data) ->
parseWIKI 'http://en.wikipedia.org/wiki/Bosnia_and_Herzegovina', (err, data) ->
	#console.log err, data
	fn = (node) ->
		#console.log 'NODE', node
		if node.name is 'table' and node.attribs?.class is 'infobox geography vcard'
			try
				console.log 'CAPITAL', node.children[5].children[1].children[0].attribs.title
				console.log 'LANG', node.children[6].children[1].children[0].children[0].data
				console.log 'TZ', node.children[21].children[1].children[0].children[0].data
			catch err
		else if node.children
			node.children.forEach fn
	data.forEach fn
###
