#!/usr/bin/env coffee
#
# fetches ISO-3166-1 codes
#
require.paths.unshift __dirname + '/../lib/node'

###
http: require 'http'
#client: http.createClient 80, 'en.wikipedia.org'
client: http.request
	host: '127.0.0.1'
	port: 3128

getISO: (iso, parser) ->
#	req: client.request 'GET', '/w/index.php?title=' + iso + '&action=edit', {
	req: client.request 'GET', 'http://en.wikipedia.org/w/index.php?title=' + iso + '&action=edit', {
		host: 'en.wikipedia.org'
		'user-agent': 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; GTB6.5; .NET CLR 1.1.4322; .NET CLR 2.0.50727)'
	}
	req.end()
	req.on 'response', (res) ->
		res.setEncoding 'utf8'
		body: ''
		res.on 'data', (chunk) -> body += chunk
		res.on 'end', () -> parser body

geo: {
#	countries: promise.defer()
#	currencies: promise.defer()
}
###

###
getISO 'ISO_3166-1', (data) ->
	#console.log data
	#return
	arr: []
	countries: {}
	hash: {}
	#| {{flag|Afghanistan}}
	#| [[ISO 3166-1 alpha-2#AF|&lt;tt>AF&lt;/tt>]] || &lt;tt>AFG&lt;/tt> || &lt;tt>004&lt;/tt> || [[ISO 3166-2:AF]]
	data.split('\n').forEach (line) ->
		if m: line.match /(?:\{\{flag\|(.+)?\}\}|\{\{noflag\}\})/
			hash: {}
			hash.name: m[1]
		else if m: line.match /^\| .+\|\&lt\;tt\>(\w+)\&lt\;\/tt\>]] \|\| \&lt\;tt\>(\w+)\&lt\;\/tt\> \|\| \&lt\;tt\>(\d+)\&lt\;\/tt\>/
			hash.iso2: m[1]
			hash.iso3: m[2]
			hash.iso: m[3]
			# quirks:
			hash.name: 'Antarctica' if m[3] is '010'
			hash.name: 'Taiwan' if m[3] is '158'
			hash.name: 'Viet Nam' if m[3] is '704'
			hash.name: 'Western Sahara' if m[3] is '732'
			hash.name: 'Macedonia' if m[3] is '807'
			arr.push hash
			countries[hash.iso]: hash
	getISO 'ISO_4217', (data) ->
		arr: []
		data.split('\n').forEach (line) ->
			return unless line.substr(0,2) is '| '
			return false if line.substr(0,2) is '|}'
			m: line.substring(2).split ' || '
			return false unless m.length is 5
			hash: {}
			hash.code: m[0]
			hash.iso: m[1]
			hash.log: m[2]
			hash.name: m[3].replace(/^\[\[/, '').replace /\]\].*/, ''
			# quirks:
			# ???
			arr.push hash
			countries[hash.iso]: or {}
			countries[hash.iso].curr: hash
		console.log require('sys').inspect countries
###


#
# http://kurapov.name/rus/technology/web/databases/iso_countries_data/
#

geo: {
}
#raw: require('fs').readFileSync('111').toString 'utf8'
raw: require('fs').readFileSync('iso_data.sql').toString 'utf8'
raw.split('\n').forEach (line) ->
	if m: line.match /^insert  into `iso_countries`\(`id`,`eng_title`,`iso_nr`,`alpha2`,`alpha3`,`is_independent`,`currency_alpha3`,`currency_title`,`phone_code`,`internet_domain`,`eng_fulltitle`,`est_title`,`rus_title`,`rus_fulltitle`,`rus_location`,`rus_location_precise`\) values \('(?:.+)?','(.+)?','(.+)?','(.+)?','(.+)?','(.+)?','(.+)?','(.+)?','(.+)?','\.(\w+)?.*?','(.+)?','(.+)?','(.+)?','(.+)?','(.+)?','(.+)?'\);/
		m.shift()
		m: m.map (x) -> x?.replace /\\'/g, "'"
		hash: {
			name: {
				en: m[0]
				ru: m[11]
			}
			title: {
				en: m[9] or m[0]
				ru: m[12] or m[11]
			}
			code: m[1]
			iso2: m[2]
			iso3: m[3]
			curr: {
				#iso: m[5]
				name: m[6]
			}
			phone_code: m[7]
			domain: m[8]
			region: m[13]
		}
		geo[m[5]]: hash
		#console.log m
	else if m: line.match /^insert  into `iso_currency`\(`id`,`iso_nr`,`alpha3`,`sign`,`title`\) values \('.+?','(.+)?','(.+)?','.*?','(.+)?'\);/
		m.shift()
		m: m.map (x) -> x?.replace /\\'/g, "'"
		return unless geo[m[1]]
		geo[m[1]].curr.code: m[0]
		geo[m[1]].curr.iso: m[1]
		geo[m[1]].curr.title: m[2]
console.log JSON.stringify geo
r: {}
for k, v of geo
	r[v.iso3]: v
#console.log require('sys').inspect r
#console.log JSON.stringify r

#
# http://www.sil.org/iso639-3/download.asp
#
