/*
 * TODO:
 * RQL as _ plugin
 * form from schema
 * i18n switch -- reload
 * make chrome model attribute user also model
 * navigation should honor model.schema
 * centralized error showing
 * 3/5 !!!filters again!!!
 * 3/5 !!!pager!!!
 */

var model;

var currentLocale = 'en'; // FIXME: force locale here. cookie?
require({
	locale: currentLocale
}, [
	'js/bundle.js',
	'rql',
	'i18n!nls/forms' // i18n
], function(x1, RQL, i18nForms){

window.RQL = RQL;

// improve _
_.mixin({
	coerce: function(instance, type){
		var date, t;
		t = type;
		if (t === 'string') {
			instance = instance != null ? ''+instance : '';
		} else if (t === 'number' || t === 'integer') {
			if (!_.isNaN(instance)) {
				instance = +instance;
				if (t === 'integer') {
					instance = Math.floor(instance);
				}
			}
		} else if (t === 'boolean') {
			instance = instance === 'false' ? false : !!instance;
		} else if (t === 'null') {
			instance = null;
		} else if (t === 'object') {
			// FIXME: any better?
			if (JSON && JSON.parse) try {instance = JSON.parse(instance);} catch (x){}
		} else if (t === 'array') {
			instance = _.toArray(instance);
		} else if (t === 'date') {
			date = new Date(instance);
			if (!_.isNaN(date.getTime())) {
				instance = date;
			}
		}
		return instance;
	},
	partial: function(templateIds, data){
		if (!_.isArray(templateIds)) {
			templateIds = [templateIds, 'notfound'];
		}
		var text = null;
		_.each(templateIds, function(tid){
			//console.log('PART?', tid);
			var t = $('#tmpl-'+tid);
			if (t && !text) {
				text = t.text();
				//console.log('PART!', text);
			}
		});
		return text ? _.template(text, data) : '';
	},
	// i18n-aware strings
	T: function(id){
		var text = i18nForms[id] || id;
		if (arguments.length > 1) {
			var args = Array.prototype.slice.call(arguments);
			args[0] = text;
			text = _.sprintf.apply(null, args);
		}
		return text;
	}
});

function RPC0(url, data, options){
	Backbone.sync('create', {
		url: url,
		toJSON: function(){return data;}
	}, {
		success: options.success || function(){
			model.set({flash: _.T('OK')});
		},
		error: function(xhr){
			console.log('ERR', arguments, model);
			var err = xhr.responseText;
			try {
				err = JSON.parse(err);
			} catch (x) {
				if (err && err.message) err = err.message;
			}
			options.error && options.error(err) || model.set(_.isArray(err) ? {errors: err} : {error: err});
		}
	});
}

function RPC(url, method, data, options){
	Backbone.sync('create', {
		url: url,
		toJSON: function(){return {jsonrpc: '2.0', id: 1, method: method, params: data};}
	}, {
		success: options.success || function(){
			model.set({flash: _.T('OK')});
		},
		error: function(xhr){
			console.log('ERR', arguments, model);
			var err = xhr.responseText;
			try {
				err = JSON.parse(err);
			} catch (x) {
				if (err && err.message) err = err.message;
			}
			options.error && options.error(err) || model.set(_.isArray(err) ? {errors: err} : {error: err});
		}
	});
}

// extended Collection
var Entity = Backbone.Collection.extend({
	dispose: function(){
		delete this.name;
		delete this.url;
		delete this.query;
		this.refresh();
	},
	create: function(data, options){
		RPC(this.name, 'add', data, {
			success: function(){
				console.log('CREATED');
				Backbone.history.loadUrl();
			}
		});
	},
	updateSelected: function(ids, props){
		RPC(this.name, 'update', [ids, props], {
			success: function(){
				console.log('UPDATED');
				Backbone.history.loadUrl();
			}
		});
	},
	destroySelected: function(ids){
		RPC(this.name, 'remove', [ids], {
			success: function(){
				console.log('REMOVED');
				Backbone.history.loadUrl();
			}
		});
	},
	initialize: function(){
	},
	schema: function(){
		var schema = model.get('schema');
		var name = this.name;
		schema = schema && schema[name] && schema[name].schema && schema[name].schema.properties || {};
		return schema;
	},
	methods: function(){
		var schema = model.get('schema');
		var name = this.name;
		var methods = schema && schema[name] && schema[name].methods || [];
		return methods;
	}
});

// DOM is loaded
require.ready(function(){ //

var ErrorApp = Backbone.View.extend({
	el: $('#errors'),
	render: function(){
		this.el.html(_.partial('errors', {model: model})).show().delay(5000).hide(0, function(){
			_.each(['flash', 'error', 'errors'], function(x){
				model.unset(x, {silent: true});
			});
		});
		return this;
	},
	events: {
	},
	initialize: function(){
		_.bindAll(this, 'render');
		model.bind('change:flash', this.render);
		model.bind('change:error', this.render);
		model.bind('change:errors', this.render);
	}
});

var HeaderApp = Backbone.View.extend({
	el: $('#header'),
	render: function(){
		this.el.html(_.partial('header', model.toJSON()));
		return this;
	},
	events: {
		'submit #login': 'login',
		'click a[href=#logout]': 'logout',
		'submit #signup': 'signup'
	},
	initialize: function(){
		_.bindAll(this, 'render');
		model.bind('change', this.render);
	},
	//
	// user authorization
	//
	login: function(e){
		var data = $(e.target).serializeObject();
		RPC('/', 'login', data, {
			success: function(){
				location.href = '/';
			},
			error: function(){
				alert(_.T('loginInvalid'));
			}
		});
		return false;
	},
	logout: function(e){
		RPC('/', 'login', {}, {
			success: function(){
				location.href = '/';
			},
			error: function(){
				alert('Could not log off... Try once more');
			}
		});
		return false;
	},
	signup: function(e){
		var data = $(e.target).serializeObject();
		RPC('/', 'signup', {
				id: data.user,
				password: data.pass
		}, {
			success: function(){
				location.href = '/';
			},
			error: function(){
				alert('Sorry... Try once more');
			}
		});
		return false;
	}
});

var FooterApp = Backbone.View.extend({
	el: $('#footer'),
	render: function(){
		this.el.html(_.partial('footer', {
			// 4-digit year as string -- to be used in copyright (c) 2010-XXXX
			year: (new Date()).toISOString().substring(0, 4)
		}));
		return this;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		model.bind('change', this.render);
	}
});

var NavApp = Backbone.View.extend({
	el: $('#nav'),
	render: function(){
		this.el.html(_.partial('navigation', model.toJSON()));
		return this;
	},
	events: {
		'submit #search': 'search'
	},
	initialize: function(){
		_.bindAll(this, 'render');
		model.bind('change', this.render);
	},
	search: function(e){
		var text = $(e.target).find('input').val();
		if (!text) return false;
		alert('TODO SEARCH FOR ' + text);
		return false;
	}
});

var AdminApp = Backbone.View.extend({
	_lastClickedRow: 0,
	selected: [],
	render: function(){
		var entity = model.get('entity');
		var name = entity.name;
		var schema = entity.schema();
		var methods = entity.methods();
		//console.log('VIEWRENDER', this, name, entity.query+'', schema, methods);
		var query = this.query = RQL.Query(entity.query+'').normalize({clear: _.pluck(schema, 'name')});
		var props = schema;
		if (query.selectArr.length) {
			var selectedProps = _.map(query.selectObj, function(show, name){if (show) return _.detect(props, function(x){return x.name === name});});
			props = selectedProps;
		}
		// leave only properties that are non-vetoed
		var visibleProps = _.clone(props);
		_.each(props, function(prop, name){if (prop.readonly === true || typeof prop.readonly == 'object' && prop.readonly.get) delete visibleProps[name]});
		props = visibleProps;
		//console.log('RENDER ENTITY', items);

		this.selected = [];

		// render list
		$(this.el).html(name ? _.partial([name+'-list', 'list'], {
			name: name,
			items: entity,
			selected: this.selected,
			query: query,
			props: props,
			methods: methods
		}) : 'XXX');

		// render inspector
		if (methods.indexOf('update') >= 0 || methods.indexOf('remove') >= 0 || methods.indexOf('add') >= 0) {
			this.renderEditor();
		}

		// don't forget to redelegate
		this.delegateEvents();

		// N.B. workaround: textchange event can not be delegated...
		// reload the View after a 1 sec timeout elapsed after the last textchange event on filters
		var self = this;
		var timeout;
		$(this.el).find(':input.filter').bind('textchange', function(){
			clearTimeout(timeout);
			var $this = $(this);
			var name = $this.attr('name');
			timeout = setTimeout(function(){
				self.reload();
			}, 500);
			return false;
		});

		/*this.$('.filter').each(function(i, x){
			$(x).tokenInput(function(query){
				return '/'+name + '?' + RQL.Query().match($(x).attr('name'), query, 'i');
			}, {
			});
		});*/

		return this;
	},
	renderEditor: function(ids){
		var entity = model.get('entity');
		var name = entity.name;
		var schema = entity.schema();
		var methods = entity.methods();
		var props = schema;
		if (methods.indexOf('update') >= 0 || methods.indexOf('remove') >= 0 || methods.indexOf('add') >= 0) {
			var ids = this.selected;
			//ids = ids || this.selected;
			var m;
			//console.log('INSPECT', this, ids);
			if (ids.length === 1) {
				m = entity.get(ids[0]);
			}
			if (!m) {
				m = new Backbone.Model;
				m.collection = entity;
			}
			var html = _.partial([name+'-form', 'form'], {
				ids: ids,
				data: m,
				name: name,
				props: props,
				methods: methods
			})
			//return html;
			this.$('#inspector').html(html);
		}
		return this;
	},
	events: {
		'change .action-select:enabled': 'selectRow',
		'click .action-select:enabled': 'selectSequence',
		'change .action-select-all': 'selectAll',
		'change .actions': 'command',
		//'textchange .filter': 'filter',
		'change select.filter': 'reload',
		'click .action-sort': 'sort',
		'change .action-limit': 'setPageSize',
		'click .pager a': 'gotoPage',
		'click .action-open': 'open',
		'dblclick .action-select-row': 'open',
		'submit form': 'updateSelectedOrCreate',
		'click .action-remove': 'removeSelected'
	},
	initialize: function(){
		_.bindAll(this, 'render', 'renderEditor');
		// re-render upon model changes
		var entity = model.get('entity');
		entity.bind('change', this.render);
		entity.bind('add', this.render);
		entity.bind('remove', this.render);
		entity.bind('refresh', this.render);
		entity.bind('selection', this.renderEditor);
		entity.bind('all', function(){
			console.log('ENTITYEVENT', arguments);
		});
	},
	open: function(e){
		var id = $(e.target).attr('rel');
		$.modal(this.$('#inspector').html());
		return false;
	},
	open1: function(e){
		var id = $(e.target).attr('rel');
		var html = this.renderEditor();//[id]);
		console.log('OPEN', id, html, this.el);
		if (html && typeof html == 'string') $.colorbox({html: html, transition: 'none'});
		return false;
	},
	removeSelected: function(e){
		var entity = model.get('entity');
		entity.destroySelected(this.selected);
		return false;
	},
	updateSelectedOrCreate: function(e){
		var entity = model.get('entity');
		var ids = this.selected;
		var props = $(e.target).serializeObject({filterEmpty: true});
		if (props.data) props = props.data; // N.B. schema2form uses data
		console.log('TOSAVE?', ids, props);
		try {
			// multi update
			if (ids.length > 0) {
				entity.updateSelected(ids, props);
			// create new
			} else {
				entity.create(props);
			}
		} catch (x) {
			console.log('EXC', x, props);
		}
		return false;
	},
	reload: function(){
		var query = this.query;
		var filters = $(this.el).find(':input.filter');
		filters.each(function(i, x){
			var name = $(x).attr('name');
			var type = $(x).attr('data-type') || 'string';
			var val = $(x).val();
			// remove all search conditions on 'name'
			query.search.args = _.reject(query.search.args, function(x){return x.args[0] === name});
			// TODO: treat val as RQL?!
			console.log('FILTER', name, val);
			if (val) {
				if (type === 'string') {
					query.filter(RQL.Query().match(name, val, 'i'));
				} else {
					query.filter(RQL.Query().eq(name, _.coerce(val, type)));
				}
			}
		});
		console.log('FILTER', query, query+'');
		// FIXME: location is bad, consider manually calling controller + saveLocation
		location.href = location.href.split('?')[0] + '?' + query;
	},
	filter: function(e){
		this.reload();
	},
	selectBulk: function(){
		// get ids from selected containers
		var ids = []; $(this.el).find('.action-select-row.selected').each(function(i, row){ids.push($(row).attr('rel'))});
		var entity = model.get('entity');
		this.selected = ids;
		//console.log('SELECTED', ids);
		entity.trigger('selection', ids, entity);
	},
	// mark checked checkbox container as selected
	selectRow: function(e){
		e.preventDefault();
		var fn = $(e.target).attr('checked');
		// TODO: reflect "all selected" status in master checkbox
		var id = $(e.target).parents('.action-select-row:first').toggleClass('selected', fn).attr('rel');
		//
		if (!this._inBulkSelect) {
			this.selectBulk();
		}
	},
	// gmail-style selection, shift-click selects the sequence
	selectSequence: function(e){
		var t = e.target;
		var parent = $(t).parents('.action-select-list:first');
		var all = parent.find('.action-select:enabled');
		var first = all.index(t);
		if (e.shiftKey) {
			var last = this._lastClickedRow;
			var start = Math.min(first, last);
			var end = Math.max(first, last);
			var fn = $(t).attr('checked');
			try {
				this._inBulkSelect = true;
				all.slice(start, end+1).attr('checked', fn).change();
			} finally {
				this._inBulkSelect = false;
				this.selectBulk();
			}
		}
		this._lastClickedRow = first;
	},
	// master checkbox checks/unchecks all siblings
	selectAll: function(e){
		try {
			this._inBulkSelect = true;
			$(this.el).find('.action-select:enabled').attr('checked', $(e.target).attr('checked')).change();
		} finally {
			this._inBulkSelect = false;
			this.selectBulk();
		}
	},
	// execute a command from commands combo
	command: function(e){
		e.preventDefault();
		var cmd = $(e.target).val();
		//console.log('COMMAND', cmd, this);
		switch (cmd) {
			case 'all':
			case 'none':
			case 'toggle':
				var fn = cmd === 'all' ? true : cmd === 'none' ? false : function(){return !this.checked;};
				try {
					this._inBulkSelect = true;
					$(this.el).find('.action-select:enabled').attr('checked', fn).change();
				} finally {
					this._inBulkSelect = false;
					this.selectBulk();
				}
				break;
		}
		$(e.target).val(null);
	},
	// handle multi-column sort
	sort: function(e){
		var prop = $(e.target).attr('rel');
		var query = this.query;
		var sortOrder = query.sort;
		var state = query.sortObj[prop];
		var multi = sortOrder.length > 1;
		if (!state) {
			if (!e.shiftKey) sortOrder = [];
			sortOrder.push(prop);
		} else {
			var p = state > 0 ? '-'+prop : prop;
			if (!e.shiftKey) {
				sortOrder = [multi ? prop : p];
			} else {
				var i = _.keys(query.sortObj).indexOf(prop);
				if (state < 0)
					sortOrder.splice(i, 1);
				else
					sortOrder[i] = p;
			}
		}
		// re-sort
		query.sort = sortOrder;
		this.reload();
		return false;
	},
	// handle pagination
	setPageSize: function(e){
		this.query.limit[0] = +($(e.target).val());
		this.query.limit[1] = 0;
		this.reload();
		return false;
	},
	gotoPage: function(e){
		var entity = model.get('entity');
		var items = entity;//.toJSON();
		var query = this.query;
		var lastSkip = query.limit[1];
		var delta = query.limit[0]; if (delta === Infinity) delta = 100;
		var el = $(e.target);
		if (el.is('.page-prev')) delta = -delta;
		else if (el.is('.page-next')) {
			//if (items.length < delta) delta = 0;
			if (!items.length) delta = 0;
		}
		// goto new page
		query.limit[1] += delta; if (query.limit[1] < 0) query.limit[1] = 0;
		if (query.limit[1] !== lastSkip) {
			this.reload();
		}
		return false;
	}
});

var HomeApp = Backbone.View.extend({
	render: function(){
		$(this.el).html(_.partial('home', model.toJSON()));
		try {
		this.delegateEvents();
		} catch (x) {
			console.log('EXCCC', x);
		}
		console.log('DELEGATED');
		return this;
	},
	events: {
		'submit #action-support-post-request': 'postRequest'
	},
	initialize: function(){
		_.bindAll(this, 'render');
		model.bind('change:user', this.render);
	},
	postRequest: function(e){
		console.log('PR');
		return false;
		try {
		//var props = $(e.target).serializeObject();
		//$.post('/request', props, function(data){
		//	console.log('REQPOSTED', data, props);
		//});
		} catch (x) {
			console.log('EXCCC', x);
		}
		return false;
	}
});

var ProfileApp = Backbone.View.extend({
	render: function(){
		var user = model.get('user');
		this.user = new Backbone.Model(user);
		delete this.user.id;
		this.user.url = '/profile';
		$(this.el).html(_.partial('profile', {
			user: this.user
		}));
		this.delegateEvents();
		return this;
	},
	events: {
		'submit #action-profile-change-name': 'changeProfile',
		'submit #action-profile-change-email': 'changeProfile',
		'submit #action-profile-change-password': 'changePassword'
	},
	initialize: function(){
		_.bindAll(this, 'render');
		model.bind('change:user', this.render);
	},
	changeProfile: function(e){
		var props = $(e.target).serializeObject({filterEmpty: true});
		if (_.size(props) > 0) {
			RPC('/', 'setProfile', props, {
				success1: function(){
					location.reload();
				}
			});
		}
		return false;
	},
	changePassword: function(e){
		var props = $(e.target).serializeObject({filterEmpty: true});
		if (_.size(props) > 0) {
			RPC('/', 'setPassword', props, {
				success: function(){
					model.set({flash: _.T('Password set OK')})
				},
				error: function(){
					model.set({error: _.T('Password NOT set')})
				}
			});
		}
		return false;
	}
});

//
// #content application
//
var App = Backbone.View.extend({
	el: $('#content'),
	render: function(){
		var page = model.get('page');
		console.log('APPRENDER', model, page);
		switch (page) {
			case 'admin':
				// render entity explorer
				$(this.el).unbind();
				if (!this.admin) this.admin = new AdminApp({el: this.el});
				this.admin.render();
				break;
			case 'profile':
				// render profile inspector
				$(this.el).unbind();
				if (!this.profile) this.profile = new ProfileApp({el: this.el});
				this.profile.render();
				break;
			default:
				// render welcome page
				$(this.el).unbind();
				if (!this.home) this.home = new HomeApp({el: this.el});
				this.home.render();
				break;
		}
		return this;
	},
	initialize: function(){
		_.bindAll(this, 'render');
		// re-render upon model change
		model.bind('change:user', this.render);
		model.bind('change:page', this.render);
		//model.bind('change:entity', this.render);
		model.bind('all', function(){
			console.log('CHROME', arguments);
		});
	}
});

//
// controller listens to the route and sets chrome model attributes
//
var Controller = Backbone.Controller.extend({
	routes: {
		// url --> handler
		'admin': 'admin',
		'profile': 'profile'
	},
	initialize: function(){
		// entity viewer
		this.route(/^admin\/([^/?]+)(?:\?(.*))?$/, 'entity', function(name, query){
			model.set({page: 'admin'});
			var entity = model.get('entity');
			entity.name = name;
			entity.url = name;
			entity.query = RQL.Query(query);
			console.log('ROUTE', arguments, entity);
			//console.log('QUERY', name, query, entity);
			entity.fetch({
				url: entity.url + (query ? '?' + query : ''),
				error: function(x, xhr, y){
					entity.dispose();
					model.set({error: xhr.responseText});
				},
				success: function(data){
					model.set({errors: []});
					console.log('FETCHED', data);
				}
			});
		});
		// root
		this.route(/^$/, 'root', function(){
			model.set({page: 'home'});
		});
	},
	admin: function(){
		model.set({page: 'admin'});
		var entity = model.get('entity');
		entity.dispose();
	},
	profile: function(){
		model.set({page: 'profile'});
	}
});

/////////////////////

Backbone.emulateHTTP = true;
Backbone.emulateJSON = true;

// central model -- global scope
model = new Backbone.Model({
	errors: [],
	page: '',
	entity: new Entity()
});
RPC('/', 'getRoot', {}, {success: function(session){
model.set(session);

//
new ErrorApp;
new HeaderApp;
new NavApp;
new FooterApp;
new App;

// let the history begin
var controller = new Controller();
Backbone.history.start();

// a.toggle toggles the next element visibility
$(document)
.delegate('a.toggle', 'click', function(){
	$(this).next().toggle(0, function(){
		// autofocus the first input
		if ($(this).is(':visible')) $(this).find('input:enabled:first').focus();
	});
	return false;
})
// a.button-close hides parent form
.delegate('a.button-close, button[type=reset]', 'click', function(){
	$(this).parents('form').hide();
	return false;
})
// actions just make requests
.delegate('.list-actions a', 'click', function(){
	console.log('ACTION', $(this).attr('href').replace('#', '/'));
	return false;
});

// power up dynamic form arrays
initFormArrays();

/////////////////////

}}); // model.fetch

}); // require.ready

}); // require
