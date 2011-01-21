'use strict'

Database = require('mongo').Database
ObjectID = require('mongo').ObjectID

#
# RQL
#
parseRQL = require('rql/parser').parseGently
Query = require('rql/query').Query

# valid funcs
valid_funcs = ['lt', 'lte', 'gt', 'gte', 'ne', 'in', 'nin', 'not', 'mod', 'all', 'size', 'exists', 'type', 'elemMatch']
# funcs which definitely require array arguments
requires_array = ['in', 'nin', 'all', 'mod']
# funcs acting as operators
valid_operators = ['or', 'and', 'not'] #, 'xor']

parse = (query) ->

	options = {}
	search = {}

	walk = (name, terms) ->
		search = {} # compiled search conditions
		# iterate over terms
		(terms or []).forEach (term) ->
			term ?= {}
			func = term.name
			args = term.args
			# ignore bad terms
			# N.B. this filters quirky terms such as for ?or(1,2) -- term here is a plain value
			return if not func or not args
			# http://www.mongodb.org/display/DOCS/Querying
			# nested terms? -> recurse
			if args[0] instanceof Query
				if 0 <= valid_operators.indexOf func
					search['$'+func] = walk func, args
				# N.B. here we encountered a custom function
				# ...
			# http://www.mongodb.org/display/DOCS/Advanced+Queries
			# structured query syntax
			else
				if func is 'le'
					func = 'lte'
				else if func is 'ge'
					func = 'gte'
				# args[0] is the name of the property
				key = args.shift()
				key = key.join('.') if key instanceof Array
				# the rest args are parameters to func()
				if 0 <= requires_array.indexOf func
					args = args[0]
				# match on regexp means equality
				else if func is 'match'
					func = 'eq'
					regex = new RegExp
					regex.compile.apply regex, args
					args = regex
				else
					# FIXME: do we really need to .join()?!
					args = if args.length is 1 then args[0] else args.join()
				# regexp inequality means negation of equality
				func = 'not' if func is 'ne' and args instanceof RegExp
				# valid functions are prepended with $
				func = '$'+func if 0 <= valid_funcs.indexOf func
				# $or requires an array of conditions
				if name is 'or'
					search = [] unless search instanceof Array
					x = {}
					x[if func is 'eq' then key else func] = args
					search.push x
				# other functions pack conditions into object
				else
					# several conditions on the same property are merged into the single object condition
					search[key] = {} if search[key] is undefined
					search[key][func] = args if search[key] instanceof Object and search[key] not instanceof Array
					# equality cancels all other conditions
					search[key] = args if func is 'eq'
		# TODO: add support for query expressions as Javascript
		# TODO: add support for server-side functions
		search

	# FIXME: parseRQL of normalized query should be idempotent!!!
	# TODO: more robustly determine already normal query!
	# TODO: RQL as executor: Query().le(a,1).fetch() <== real action
	query = parseRQL(query).normalize({primaryKey: '_id'}) unless query?.sortObj
	search = walk query.search.name, query.search.args
	options.sort = query.sortObj if query.sortObj
	options.fields = query.selectObj if query.selectObj
	if query.limit
		options.limit = query.limit[0]
		options.skip = query.limit[1]
	#console.log meta: options, search: search, terms: query
	meta: options, search: search, terms: query

#
# Storage
#
class Storage extends Database
	constructor: (url, options) ->
		options ?= {}
		options.hex ?= true
		super url, options
	add: (collection, document) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		deferred = defer()
		#console.log 'ADD?', document
		Storage.__super__.insert.call @, collection, document, (err, result) ->
			#console.log 'ADD!', arguments
			if err
				return deferred.reject SyntaxError 'Duplicated' if err.code is 11000
				return deferred.reject URIError err.message if err.code
			result.id = result._id
			delete result._id
			deferred.resolve result
		deferred.promise
	put: (collection, document) ->
		document ?= {}
		if document.id
			document._id = document.id
			delete document.id
		deferred = defer()
		#console.log 'PUT?', document
		# TODO: _deleted: true --> means remove?
		Storage.__super__.modify.call @, collection, {query: {_id: document._id}, update: document, 'new': true}, (err, result) ->
			#console.log 'PUT!', arguments
			return deferred.reject null if err
			# TODO: why new: true is noop???
			#result = document
			result.id = result._id
			delete result._id
			deferred.resolve result
		deferred.promise
	remove: (collection, query) ->
		query = parse query
		deferred = defer()
		# fuser
		#console.log 'REM', query
		throw TypeError 'Use drop() instead to remove the whole collection' unless Object.keys(query.search).length
		super collection, query.search, (err, result) ->
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise
	drop: (collection) ->
		deferred = defer()
		super collection, (err, result) ->
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise
	find: (collection, query) ->
		#console.log 'FIND?', query
		query = parse query
		#console.log 'FIND!', query.search
		return URIError query.terms.search.error if query.terms.search.error
		# limit the limit
		query.meta.limit = 1 if query.terms.pk
		#query.meta.limit = @limit if @limit < query.meta.limit
		deferred = defer()
		super collection, query.search, query.meta, (err, result) ->
			#console.log 'FOUND', arguments
			return deferred.reject URIError err.message if err
			result.forEach (doc) ->
				doc.id = doc._id
				delete doc._id
			#if query.terms.pk
			#	result = result[0] or null
			#@emit 'find', result
			deferred.resolve result
		deferred.promise
	get: (collection, id) ->
		return null unless id
		deferred = defer()
		Storage.__super__.get_one.call @, collection, {_id: id}, (err, result) ->
			#console.log 'GOT', arguments
			return deferred.reject URIError err.message if err
			result ?= null
			if result
				result.id = result._id
				delete result._id
			#@emit 'get', result
			deferred.resolve result
		deferred.promise
	update: (collection, query, changes) ->
		changes ?= {}
		query = parse query
		search = query.search
		search.$atomic = 1
		deferred = defer()
		#console.log 'PATCH?', query, search, changes
		# FIXME: how to $unset?!
		# wrap changes into $set key
		unless changes.$set or changes.$unset
			changes = $set: changes
		#console.log 'PATCH???', changes
		super collection, search, changes, (err, result) ->
			#console.log 'PATCH!', arguments
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise
	eval: (code) ->
		deferred = defer()
		super code, (err, result) ->
			return deferred.reject URIError err.message if err
			deferred.resolve result
		deferred.promise

#########################################

db = new Storage settings.database.url

#
# Store -- set of DB accessor methods bound to the db and the collection
#
Store = (entity) ->
	add: db.add.bind db, entity
	remove: db.remove.bind db, entity
	update: db.update.bind db, entity
	all: db.find.bind db, entity
	#one: db.get.bind db, entity

#########################################

#
# Model -- set of overloaded Store methods plus business logic
#
Model = (entity, store, overrides) ->
	bundle = Compose.create store or Store(entity), {id: entity}, overrides
	model =
		add: bundle.add
		#all: bundle.all
		q: (query) ->
			x = parseQuery query
			Object.defineProperty x, 'model', value: model
		where: (query) -> Compose.create null,
			query: parseQuery query
			where: (query) ->
				#console.log 'OLD', @query
				@query.where query
				#console.log 'NEW', @query
				@
			all: () ->
				bundle.find @query
			one: () ->
				wait bundle.find(@query), (result) ->
					result = result[0] or null
			update: (changes) ->
				bundle.update @query, changes
			remove: () ->
				bundle.remove @query

#
# validating and reporting CRUD for given model
#
SecuredModel = (model, options) ->
	options ?= {}
	schemaForGet = options.schema?.get or options.schema
	schemaForAdd = options.schema?.add or options.schema?.put or options.schema
	schemaForUpdate = options.schema?.update or options.schema?.put or options.schema
	Compose.create model,
		find: Compose.around (base) ->
			(query) ->
				#console.log 'BEFOREFIND', arguments
				wait base.call(@, query), (result) ->
					if schemaForGet
						if result instanceof Array
							result = result.map (doc) ->
								validate doc, schemaForGet, vetoReadOnly: true, flavor: 'get'
								doc
						else
							if result
								validate result, schemaForGet, vetoReadOnly: true, flavor: 'get'
					#console.log 'AFTERFIND', result
					result
		get: Compose.around (base) ->
			(id) ->
				#console.log 'BEFOREGET', arguments
				wait base.call(@, id), (result) ->
					if schemaForGet and result
						validate result, schemaForGet, vetoReadOnly: true, flavor: 'get'
					#console.log 'AFTERGET', result
					result
		add: Compose.around (base) ->
			(document) ->
				#console.log 'BEFOREADD', arguments
				if schemaForAdd
					validation = validate document or {}, schemaForAdd, vetoReadOnly: true, flavor: 'add'
				wait base.call(@, document), (result) ->
					if schemaForGet and result
						validate result, schemaForGet, vetoReadOnly: true, flavor: 'get'
					#console.log 'AFTERADD', result
					result
		update: Compose.around (base) ->
			(query, changes) ->
				#console.log 'BEFOREUPDATE', arguments
				if schemaForUpdate
					validation = validate changes or {}, schemaForUpdate, vetoReadOnly: true, existingOnly: true, flavor: 'update'
					#if not validation.valid
					#	return SyntaxError JSON.stringify validation.errors
				wait base.call(@, query, changes), (result) ->
					#console.log 'AFTERUPDATE', result
					result
		remove: Compose.around (base) ->
			(query) ->
				#console.log 'BEFOREREMOVE', arguments
				wait base.call(@, query), (result) ->
					#console.log 'AFTERREMOVE', result
					result

#########################################

#
# Facet -- exposed flat list of SecuredModel methods
#

# expose enlisted model methods
Facet = (model, options, expose) ->
	options ?= {}
	wrapped = SecuredModel model, options
	facet = {}
	expose and expose.forEach (def) ->
		if def instanceof Array
			name = def[1]
			method = def[0]
			method = wrapped[method] if typeof method is 'string'
		else
			name = def
			method = wrapped[name]
		#
		fn = method
		#facet[name] = fn.bind wrapped if fn
		facet[name] = fn if fn
		#facet[name] = Compose.from(wrapped, name).bind wrapped
	# FIXME: options should also be frozen, deeeep frozen!
	Object.freeze Compose.create options, facet

# expose collection accessors plus enlisted model methods
PermissiveFacet = (model, options, expose...) ->
	Facet model, options, ['get', 'add', 'update', 'find', 'remove'].concat(expose or [])

PermissiveFacet1 = (model, options, expose...) ->
	Facet model, options, [['get', 'get' + model.id], ['add', 'create' + model.id], ['update', 'update' + model.id], ['find', 'get' + model.id + 'List'], ['remove', 'remove' + model.id]].concat(expose or [])

# expose only collection _getters_ plus enlisted model methods
RestrictiveFacet = (model, options, expose...) ->
	Facet model, options, ['get', 'find'].concat(expose or [])

#########################################

module.exports =
	Store: Store
	Model: Model
	Facet: Facet
	RestrictiveFacet: RestrictiveFacet
	PermissiveFacet: PermissiveFacet
