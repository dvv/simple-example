'use strict';var app, config, context, simple, testCase;
var __hasProp = Object.prototype.hasOwnProperty;
require.paths.unshift(__dirname + '/../lib/node');
config = require('../config');
simple = require('jse');
app = require('../app');
testCase = require('nodeunit').testCase;
context = {};
module.exports = testCase({
  setUp: function(callback) {
    return app.getContext('nemo', function(err, result) {
      context = result;
      return callback();
    });
  },
  tearDown: function(callback) {
    return callback();
  },
  testEntities: function(test) {
    var authority, entity, facet;
    authority = [];
    for (entity in context) {
      if (!__hasProp.call(context, entity)) continue;
      facet = context[entity];
      if (entity.match(/^(get|set|login)/)) {
        continue;
      }
      authority.push(entity);
    }
    test.ok(authority.length === 1 && authority[0] === 'Hit', 'Right to register a hit');
    return test.done();
  },
  testHit: function(test) {
    var i, nonce, _results;
    _results = [];
    for (i = 999; i >= 0; i--) {
      nonce = String(Math.random()).substring(2);
      _results.push(context.Hit.add.call(context, {
        id: nonce,
        name: nonce
      }, function(err, result) {
        test.ok(!err && result.name);
        if (!i) {
          return test.done();
        }
      }));
    }
    return _results;
  }
});