#!/usr/local/bin/coffee
'use strict'

sys = require 'util'
console.log = (args...) ->
	for a in args
		console.error sys.inspect a, false, 20

#fetchCourses = require('./geo').fetchCoursesXurrency
#fetchCourses = require('./geo').fetchCoursesForex
#fetchCourses = require('./geo').fetchCoursesCBR

#fetchCourses 'usd', console.log

ck = require './node_modules/coffeekup'

###
template = ->
  h1 @title
  form method: 'post', action: 'login', ->
    input id: 'username'
    input id: 'password'
    button @title

helpers =
  textbox: (attrs) ->
    attrs.type = 'text'
    attrs.name = attrs.id
    input attrs
###

###
template = """
doctype 5
html ->
  head ->
    meta charset: 'utf-8'
    title "#{@title or 'Untitled'} | My awesome website"
    meta(name: 'description', content: @desc) if @desc?
    link rel: 'stylesheet', href: '/stylesheets/app.css'
    style '''
      body {font-family: sans-serif}
      header, nav, section, footer {display: block}
    '''
    script src: '/javascripts/jquery.js'
    coffeescript ->
      $().ready ->
        alert 'Alerts are so annoying...'
  body ->
    header ->
      h1 @title or 'Untitled'
      nav ->
        ul ->
          (li -> a href: '/', -> 'Home') unless @path is '/'
          li -> a href: '/chunky', -> 'Bacon!'
          switch @user.role
            when 'owner', 'admin'
              li -> a href: '/admin', -> 'Secret Stuff'
            when 'vip'
              li -> a href: '/vip', -> 'Exclusive Stuff'
            else
              li -> a href: '/commoners', -> 'Just Stuff'
    section ->
      h2 "Let's count to #{@max}:"
      p i for i in [1..@max]
    footer ->
      p shoutify('bye')
"""

console.log ck.render template,
	context: {title: 'Foo', path: '/zig', user: {}, max: 12}

data = {
  "title": "Search for sedans",
  "cars": [
      {"make": "Honda", "model": "Accord"},
      {"make": "Ford", "model": "Taurus"},
    ]
}

template = '''/title {
    font-size: 24px;
}
/cars {
    border: 1px;
}
/cars/#/make {
    color: blue;
};'''

#jss = require './node_modules/jss'
#console.log jss.compile template
###

comp = require './node_modules/grain/examples/corn'

`
var template = 'Hello @planet, my name is @name() and I am @age() years old @a().';
var data = {
  // Value
  planet: "world",
  // Async getter
  name: function name(callback) {
    process.nextTick(function () {
      callback(null, "Tim Caswell");
    });
  },
  // sync getter
  age: function age() {
    return 28;
  }
};

`
fn = comp template
console.log fn + "" #data, (err, result) -> console.log arguments
