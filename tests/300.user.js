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
    return app.getContext('c', function(err, result) {
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
    test.ok(authority.length === 0, 'no rights at all');
    return test.done();
  },
  testProfile: function(test) {
    return Next(context, function(err, result, next) {
      return this.getProfile.call(this, next);
    }, function(err, result, next) {
      test.ok(!err && result && result.type === 'merchant' && result.lang && result.timezone, 'got profile');
      test.ok((!result.secret || result.secret === 'csecret') && !result.salt && !result.password, 'got no authentication info');
      return this.setProfile.call(this, {
        secret: 'csecret',
        'rights': 'trytoelevate',
        type: 'trytoescape',
        lang: 'en',
        timezone: 'UTC+04'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result, 'setProfile should return the profile');
      test.ok(result.secret === 'csecret' && !result.rights && result.type === 'merchant', 'got profile updated');
      return this.setProfile.call(this, {
        lang: 'dummylang',
        timezone: 'UTC+01'
      }, next);
    }, function(err, result, next) {
      test.ok(err && !result, 'setProfile should return the error');
      return this.setProfile.call(this, {
        lang: 'ru',
        timezone: 'UTC+05'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result, 'setProfile should return the profile');
      test.ok(result.lang === 'ru' && result.timezone === 'UTC+05', 'language and timezone updated');
      return this.setProfile.call(this, {
        id: 'lemmebeadminz',
        extrafoo: 'bar',
        blocked: true,
        active: false
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result, 'setProfile should return the profile');
      test.ok(result.id === 'c' && !result.extrafoo && !result.blocked, 'non-profile info intact');
      return test.done();
    });
  }
});