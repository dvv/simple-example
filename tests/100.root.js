'use strict';var app, config, context, simple, testCase;
require.paths.unshift(__dirname + '/../lib/node');
config = require('../config');
simple = require('jse');
app = require('../app');
testCase = require('nodeunit').testCase;
context = {};
module.exports = testCase({
  setUp: function(callback) {
    return app.getContext('root', function(err, result) {
      context = result;
      return callback();
    });
  },
  tearDown: function(callback) {
    return callback();
  },
  testMerchant: function(test) {
    context.entity = 'Merchant';
    return Next(context, function(err, result, next) {
      return this[this.entity]["delete"].call(this, 'dummyfield!=dummyvalue', next);
    }, function(err, result, next) {
      test.ok(!err && !result, 'deleted ok');
      return this[this.entity].query.call(this, '', next);
    }, function(err, result, next) {
      test.ok(!err, 'query ok');
      test.deepEqual(result, [], 'empty recordset');
      return this[this.entity].add.call(this, {
        id: 'a',
        name: 'Foo1'
      }, next);
    }, function(err, result, next) {
      test.ok(!err, 'added ok');
      test.ok(result.id === 'a' && !result.name, 'added ok');
      return this[this.entity].add.call(this, {
        id: 'a',
        name: 'Foo2'
      }, next);
    }, function(err, result, next) {
      test.equal(err, 'Duplicated', 'duplicated nak');
      return this[this.entity].add.call(this, {
        id: 'b',
        name: 'Foo2'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result.id === 'b' && !result.name, 'added ok');
      return this[this.entity].add.call(this, {
        id: 'c',
        name: 'Foo3'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result.id === 'c' && !result.name, 'added ok');
      return this[this.entity].query.call(this, ['a', 'b', 'c'], next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents');
      return this[this.entity].query.call(this, '(id=a|id=c)', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 2, 'queried 2 documents of ids a and c');
      test.ok(result[0].id === 'a' && result[1].id === 'c');
      return this[this.entity].update.call(this, 'in(id,(a,b))', {
        blocked: 'true',
        rights: 'whatever',
        type: 'admin',
        name: 'nonauthorized',
        email: 'fake',
        password: 'takeover'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && !result);
      return this[this.entity].query.call(this, 'select(type)', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents, only type attribute');
      test.ok(_.all(result, function(x) {
        return x.type === 'merchant';
      }));
      return this[this.entity].query.call(this, 'select(-type)', next);
    }, function(err, result, next) {
      console.log('Q3', arguments);
      test.ok(!err && result.length === 3, 'queried 3 documents, kick out type attribute');
      test.ok(_.all(result, function(x) {
        var _ref;
        if ((_ref = x.id) === 'a' || _ref === 'b') {
          return x.rights === 'whatever' && x.blocked;
        } else {
          return !x.rights;
        }
      }));
      test.ok(_.all(result, function(x) {
        return !x.name && !x.email;
      }));
      return this[this.entity].remove.call(this, 'in(id,(a)),rights=whatever', next);
    }, function(err, result, next) {
      test.ok(!err && !result);
      return this[this.entity].query.call(this, 'select(rights)', next);
    }, function(err, result, next) {
      var _ref, _ref2;
      console.log('LAAAAST', arguments);
      test.ok(!err && result.length === 2, 'queried 2 documents');
      test.ok(((_ref = result[0].id) === 'b' || _ref === 'c') && ((_ref2 = result[1].id) === 'b' || _ref2 === 'c'));
      return test.done();
    });
  },
  testAdmin: function(test) {
    context.entity = 'Admin';
    return Next(context, function(err, result, next) {
      return this[this.entity]["delete"].call(this, 'dummyfield!=dummyvalue', next);
    }, function(err, result, next) {
      test.ok(!err && !result, 'deleted ok');
      return this[this.entity].query.call(this, '', next);
    }, function(err, result, next) {
      test.ok(!err, 'query ok');
      test.deepEqual(result, [], 'empty recordset');
      return this[this.entity].add.call(this, {
        id: 'x',
        name: 'Foo1'
      }, next);
    }, function(err, result, next) {
      test.ok(!err, 'added ok');
      test.ok(result.id === 'x' && !result.name, 'added ok');
      return this[this.entity].add.call(this, {
        id: 'a',
        name: 'Foo2'
      }, next);
    }, function(err, result, next) {
      test.equal(err, 'Duplicated', 'duplicated nak');
      return this[this.entity].add.call(this, {
        id: 'y',
        name: 'Foo2'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result.id === 'y' && !result.name, 'added ok');
      return this[this.entity].add.call(this, {
        id: 'z',
        name: 'Foo3'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result.id === 'z' && !result.name, 'added ok');
      return this[this.entity].query.call(this, ['x', 'y', 'z'], next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents');
      return this[this.entity].query.call(this, '(id=x|id=c)', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 1, 'queried 2 admins of ids x and c -- only x is admin');
      test.ok(result[0].id === 'x');
      return this[this.entity].update.call(this, 'in(id,(x,b))', {
        blocked: 'false',
        rights: 'whatever',
        type: 'admin',
        name: 'nonauthorized',
        email: 'fake',
        password: 'takeover'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && !result);
      return this[this.entity].query.call(this, 'select(type)', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents, only type attribute');
      test.ok(_.all(result, function(x) {
        return x.type === 'admin';
      }));
      return this[this.entity].query.call(this, 'select(-type)', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents, kick out type attribute');
      test.ok(_.all(result, function(x) {
        var _ref;
        if ((_ref = x.id) === 'x' || _ref === 'b') {
          return x.rights === 'whatever' && !x.blocked;
        } else {
          return !x.rights;
        }
      }));
      test.ok(_.all(result, function(x) {
        return !x.name && !x.email;
      }));
      return this[this.entity].remove.call(this, 'in(id,(x)),rights=whatever', next);
    }, function(err, result, next) {
      test.ok(!err && !result);
      return this[this.entity].query.call(this, 'select(rights)', next);
    }, function(err, result, next) {
      var _ref, _ref2;
      test.ok(!err && result.length === 2);
      test.ok(((_ref = result[0].id) === 'y' || _ref === 'z') && ((_ref2 = result[1].id) === 'y' || _ref2 === 'z'));
      return test.done();
    });
  },
  testAffiliate: function(test) {
    context.entity = 'Affiliate';
    return Next(context, function(err, result, next) {
      return this[this.entity]["delete"].call(this, 'dummyfield!=dummyvalue', next);
    }, function(err, result, next) {
      test.ok(!err && !result, 'deleted ok');
      return this[this.entity].query.call(this, '', next);
    }, function(err, result, next) {
      test.ok(!err, 'query ok');
      test.deepEqual(result, [], 'empty recordset');
      return this[this.entity].add.call(this, {
        id: 'f',
        name: 'Foo1'
      }, next);
    }, function(err, result, next) {
      test.ok(!err, 'added ok');
      test.ok(result.id === 'f' && !result.name, 'added ok');
      return this[this.entity].add.call(this, {
        id: 'a',
        name: 'Foo2'
      }, next);
    }, function(err, result, next) {
      test.equal(err, 'Duplicated', 'duplicated nak');
      return this[this.entity].add.call(this, {
        id: 'y',
        name: 'Foo2'
      }, next);
    }, function(err, result, next) {
      test.equal(err, 'Duplicated', 'duplicated nak');
      return this[this.entity].add.call(this, {
        id: 'g',
        name: 'Foo3'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result.id === 'g' && !result.name, 'added ok');
      return this[this.entity].add.call(this, {
        id: 'h',
        name: 'Foo3'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result.id === 'h' && !result.name, 'added ok');
      return this[this.entity].query.call(this, ['f', 'g', 'h'], next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents');
      return this[this.entity].query.call(this, '(id=x|id=c|id=f|id=g)', next);
    }, function(err, result, next) {
      var _ref, _ref2;
      test.ok(!err && result.length === 2, 'queried 4 users, 2 should be');
      test.ok(((_ref = result[0].id) === 'f' || _ref === 'g') && ((_ref2 = result[1].id) === 'f' || _ref2 === 'g'));
      return this[this.entity].update.call(this, 'in(id,(x,b,f))', {
        blocked: 'true',
        rights: 'whatever',
        type: 'affiliate',
        name: 'nonauthorized',
        email: 'fake',
        password: 'takeover'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && !result);
      return this[this.entity].query.call(this, 'select(type)', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents, only type attribute');
      test.ok(_.all(result, function(x) {
        return x.type === 'affiliate';
      }));
      return this[this.entity].query.call(this, 'select(-type)&blocked=false', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 2, 'queried 2 documents, kick out type attribute');
      test.ok(_.all(result, function(x) {
        return !x.rights && !x.blocked;
      }));
      test.ok(_.all(result, function(x) {
        return !x.name && !x.email;
      }));
      return this[this.entity].remove.call(this, 'in(id,(g)),rights=whatever', next);
    }, function(err, result, next) {
      test.ok(!err && !result);
      return this[this.entity].query.call(this, 'select(rights)&blocked=false', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 2, 'nothing was removed');
      return test.done();
    });
  },
  testRegion: function(test) {
    context.entity = 'Region';
    return Next(context, function(err, result, next) {
      return this[this.entity]["delete"].call(this, 'dummyfield!=dummyvalue', next);
    }, function(err, result, next) {
      test.ok(!err && !result, 'deleted ok');
      return this[this.entity].query.call(this, '', next);
    }, function(err, result, next) {
      test.ok(!err, 'query ok');
      test.deepEqual(result, [], 'empty recordset');
      return this[this.entity].add.call(this, {
        id: 'AAA'
      }, next);
    }, function(err, result, next) {
      test.deepEqual(err, [
        {
          property: 'name',
          message: 'required'
        }
      ], 'validation nak');
      return this[this.entity].add.call(this, {
        id: 'AAA',
        name: 'Foo'
      }, next);
    }, function(err, result, next) {
      test.ok(!err, 'added ok');
      test.ok(result.id === 'AAA' && result.name === 'Foo', 'added ok');
      return this[this.entity].add.call(this, {
        id: 'AAA',
        name: 'Foo1'
      }, next);
    }, function(err, result, next) {
      test.equal(err, 'Duplicated', 'duplicated nak');
      return this[this.entity].add.call(this, {
        id: 'AAB',
        name: 'Foo2'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result.id === 'AAB' && result.name === 'Foo2', 'added ok');
      return this[this.entity].add.call(this, {
        id: 'ABA',
        name: 'Foo3'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && result.id === 'ABA' && result.name === 'Foo3', 'added ok');
      return this[this.entity].query.call(this, '', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents');
      return this[this.entity].query.call(this, 'id=re:aa', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 2, 'queried 2 documents of ids matching /aa/i');
      return this[this.entity].query.call(this, 'id!=re:aa', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 1, 'queried 1 document of ids not matching /aa/i');
      return this[this.entity].update.call(this, 'id=re:aa', {
        foo: 'bar',
        _meta: 'tainted',
        name: 'Foos',
        id: 'ZZZ'
      }, next);
    }, function(err, result, next) {
      test.ok(!err && !result, 'updated 2 documents of ids matching /aa/i, name set to Foos');
      return this[this.entity].query.call(this, 'foo=null', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 3, 'queried 3 documents, foo attribute not set');
      return this[this.entity].remove.call(this, 'id!=re:aa', next);
    }, function(err, result, next) {
      test.ok(!err && !result, 'removed 1 document of ids not matching /aa/i');
      return this[this.entity].query.call(this, 'values(id)', next);
    }, function(err, result, next) {
      test.ok(!err && result.length === 2, 'queried 2 remaining documents');
      test.deepEqual(result, [['AAA'], ['AAB']], 'documents have expected ids');
      return this[this.entity].undelete.call(this, '', next);
    }, function(err, result, next) {
      test.ok(!err && !result, 'undelete documents');
      return this[this.entity].get.call(this, 'ABA', next);
    }, function(err, result, next) {
      test.ok(!err && (result != null ? result.id : void 0) === 'ABA', 'undeleted document ok');
      return test.done();
    });
  }
});