operatorMap =
	'=': 'eq'
	'==': 'eq'
	'>': 'gt'
	'>=': 'ge'
	'<': 'lt'
	'<=': 'le'
	'!=': 'ne'

class Query

	constructor: (query, parameters) ->

		query = '' unless query?

		term = @
		term.name = 'and'
		term.args = []

		topTerm = term

		if typeof query is 'object'
			if Array.isArray query
				query = topTerm.in 'id', query
			else if query not instanceof Query
				for k, v of query
					term = new Query()
					topTerm.args.push term
					term.name = 'eq'
					term.args = [k, v]
			return

		query = query.substring(1) if query.charAt(0) is '?'
		if query.indexOf('/') >= 0 # performance guard
			# convert slash delimited text to arrays
			query = query.replace /[\+\*\$\-:\w%\._]*\/[\+\*\$\-:\w%\._\/]*/g, (slashed) ->
				'(' + slashed.replace(/\//g, ',') + ')'

		# convert FIQL to normalized call syntax form
		query = query.replace /(\([\+\*\$\-:\w%\._,]+\)|[\+\*\$\-:\w%\._]*|)([<>!]?=(?:[\w]*=)?|>|<)(\([\+\*\$\-:\w%\._,]+\)|[\+\*\$\-:\w%\._]*|)/g, (t, property, operator, value) ->
			if operator.length < 3
				throw new URIError 'Illegal operator ' + operator unless operatorMap[operator]
				operator = operatorMap[operator]
			else
				operator = operator.substring 1, operator.length - 1
			operator + '(' + property + ',' + value + ')'

		query = query.substring(1) if query.charAt(0) is '?'
		call = (newTerm) ->
			term.args.push newTerm
			term = newTerm
		setConjunction = (operator) ->
			if not term.name
				term.name = operator
			else if term.name isnt operator
				throw new Error('Can not mix conjunctions within a group, use parenthesis around each set of same conjuctions (& and |)')
		leftoverCharacters = query.replace /(\))|([&\|,])?([\+\*\$\-:\w%\._]*)(\(?)/g, (t, closedParen, delim, propertyOrValue, openParen) ->
			if delim
				if delim is '&'
					setConjunction 'and'
				else if delim is '|'
					setConjunction 'or'
			if openParen
				newTerm = new Query()
				newTerm.name = propertyOrValue
				newTerm.parent = term
				call newTerm
			else if closedParen
				isArray = not term.name
				term = term.parent
				throw new URIError 'Closing parenthesis without an opening parenthesis' unless term
				if isArray
					term.args.push term.args.pop().args
			else if propertyOrValue or delim is ','
				term.args.push stringToValue propertyOrValue, parameters
			''

		throw new URIError 'Opening parenthesis without a closing parenthesis' if term.parent
		# any extra characters left over from the replace indicates invalid syntax
		throw new URIError 'Illegal character in query string encountered ' + leftoverCharacters if leftoverCharacters

		removeParentProperty = (obj) ->
			if obj?.args
				delete obj.parent
				if obj.args.forEach
					obj.args.forEach removeParentProperty
				else
					for v, i in obj.args
						removeParentProperty obj.args[i]
			obj

		removeParentProperty topTerm
		topTerm

	toString: () ->
		console.log 'TOSTR'
		if @name is 'and' then @args.map(queryToString).join('&') else queryToString @

	where: (query) ->
		@args = @args.concat(new Query(query).args)
		@

stringToValue = (string, parameters) ->
	converter = converters.default
	if string.charAt(0) is '$'
		param_index = parseInt(string.substring(1), 10) - 1
		return if param_index >= 0 and parameters then parameters[param_index] else undefined
	if string.indexOf(':') >= 0
		parts = string.split ':', 2
		converter = converters[parts[0]]
		throw new URIError 'Unknown converter ' + parts[0] unless converter
		string = parts[1]
	converter string

queryToString = (part) ->
	if Array.isArray part
		mapped = part.map (arg) -> queryToString arg
		'(' + mapped.join(',') + ')'
	else if part and part.name and part.args
		mapped = part.args.map (arg) -> queryToString arg
		part.name + '(' + mapped.join(',') + ')'
	else
		encodeValue part

encodeString = (s) ->
	if typeof s is 'string'
		s = encodeURIComponent s
		s = s.replace('(','%28').replace(')','%29') if s.match /[\(\)]/
	s

encodeValue = (val) ->
	if val is null
		return 'null'
	else if typeof val is 'undefined'
		return val
	if val isnt converters.default('' + (val.toISOString and val.toISOString() or val.toString()))
		type = typeof val
		# TODO: UNDERSCORE!!!
		if val instanceof RegExp
			# TODO: control whether to we want simpler glob() style
			val = val.toString()
			i = val.lastIndexOf '/'
			type = if val.substring(i).indexOf('i') >= 0 then 're' else 'RE'
			val = encodeString val.substring(1, i)
			encoded = true
		else if val instanceof Date
			type = 'epoch'
			val = val.getTime()
			encoded = true
		else if type is 'string'
			val = encodeString val
			encoded = true
		val = [type, val].join ':'
	val = encodeString val if not encoded and typeof val is 'string'
	val

autoConverted =
	'true': true
	'false': false
	'null': null
	'undefined': undefined
	'Infinity': Infinity
	'-Infinity': -Infinity

converters =
	auto: (string) ->
		if autoConverted.hasOwnProperty string
			return autoConverted[string]
		number = +string
		if isNaN(number) or number.toString() isnt string
			string = decodeURIComponent string
			return string
		number
	number: (x) ->
		number = +x
		throw new URIError 'Invalid number ' + x if isNaN number
		number
	epoch: (x) ->
		date = new Date +x
		throw new URIError 'Invalid date ' + x if isNaN date.getTime()
		date
	isodate: (x) ->
		# four-digit year
		date = '0000'.substr(0, 4-x.length) + x
		# pattern for partial dates
		date += '0000-01-01T00:00:00Z'.substring date.length
		converters.date date
	date: (x) ->
		isoDate = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2}(?:\.\d*)?)Z$/.exec x
		if isoDate
			date = new Date(Date.UTC(+isoDate[1], +isoDate[2] - 1, +isoDate[3], +isoDate[4], +isoDate[5], +isoDate[6]))
		else
			date = new Date x
		throw new URIError 'Invalid date ' + x if isNaN date.getTime()
		date
	boolean: (x) ->
		x is 'true'
	string: (string) ->
		decodeURIComponent string
	re: (x) ->
		new RegExp decodeURIComponent(x), 'i'
	RE: (x) ->
		new RegExp decodeURIComponent(x)
	glob: (x) ->
		s = decodeURIComponent(x).replace(/([\\|\||\(|\)|\[|\{|\^|\$|\*|\+|\?|\.|\<|\>])/g, (x) -> '\\'+x
		s = s.replace(/\\\*/g,'.*').replace(/\\\?/g,'.?')
		s = if s.substring(0,2) isnt '.*' then '^'+s else s.substring(2)
		s = if s.substring(s.length-2) isnt '.*' then s+'$' else s.substring(0, s.length-2)
		new RegExp s, 'i'

converters.default = converters.auto

#
#
#
operators = ['in', 'nin', 'contains', 'ncontains', 'or', 'and', 'between', 'eq', 'ne', 'le', 'ge', 'lt', 'gt']
# Q.le('a','b') --> Q.where('')
for op in operators
	Query.prototype[op] = () -> where

			var newQuery = new Query();
			newQuery.executor = this.executor;
			var newTerm = new Query(name);
			newTerm.args = Array.prototype.slice.call(arguments);
			newQuery.args = this.args.concat([newTerm]);
			return newQuery;

#
# tests
#
inspect = require('./lib/node/eyes.js').inspector stream: null
consoleLog = console.log
console.log = () ->
	for arg in arguments
		#sys.debug inspect arg
		consoleLog inspect arg

q1 = new Query 'id=123&call(p1,p2/p3),sort(-n),id=date:2010'
q1.where 'u!=false'
#q2 = new Query()
console.log q1, ''+q1 #.toString()
