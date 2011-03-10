'use strict';var __slice = Array.prototype.slice, __hasProp = Object.prototype.hasOwnProperty;
module.exports = function(config, model, callback) {
  var FacetForAdmin, FacetForAffiliate, FacetForGuest, FacetForMerchant, FacetForReseller, FacetForRoot, FacetForUser, PermissiveFacet, User, app, crypto, encryptPassword, facets, nonce, root, sha1;
  facets = {};
  crypto = require('crypto');
  nonce = function() {
    return (Date.now() & 0x7fff).toString(36) + Math.floor(Math.random() * 1e9).toString(36) + Math.floor(Math.random() * 1e9).toString(36) + Math.floor(Math.random() * 1e9).toString(36);
  };
  sha1 = function(data, key) {
    var hmac;
    hmac = crypto.createHmac('sha1', key);
    hmac.update(data);
    return hmac.digest('hex');
  };
  root = config.security.root || {};
  encryptPassword = function(password, salt) {
    return sha1(salt + password + config.security.secret);
  };
  root.salt = nonce();
  root.password = encryptPassword(root.password, root.salt);
  User = model.User;
  model.User = {
    get: function(context, id, next) {
      var isSelf, profile, user, _ref;
      if (!id) {
        return typeof next == "function" ? next(null) : void 0;
      }
      isSelf = id === (context != null ? (_ref = context.user) != null ? _ref.id : void 0 : void 0);
      if (root.id === id) {
        user = root;
        profile = _.extend({}, {
          id: user.id,
          type: user.type,
          email: user.email
        });
        if (typeof next == "function") {
          next(null, profile);
        }
      } else {
        if (isSelf) {
          User._get(model.UserSelf.schema, context, id, next);
        } else {
          User.get(context, id, next);
        }
      }
    },
    query: function(context, query, next) {
      return User.query(context, query, next);
    },
    add: function(context, data, next) {
      if (data == null) {
        data = {};
      }
      Next(context, function(err, result, step) {
        return step(null, (root.id === data.id ? root : null));
      }, function(err, user, step) {
        var password, salt;
        if (err) {
          return step(err);
        }
        if (user) {
          return step([
            {
              property: 'id',
              message: 'duplicated'
            }
          ]);
        }
        salt = nonce();
        if (!data.password) {
          data.password = nonce().substring(0, 7);
        }
        password = encryptPassword(data.password, salt);
        return User.add(context, {
          id: data.id,
          password: password,
          salt: salt,
          type: data.type
        }, step);
      }, function(err, user) {
        if (err) {
          return typeof next == "function" ? next(err) : void 0;
        }
        if (user.email) {
          console.log('PASSWORD SET TO', data.password);
        }
        return typeof next == "function" ? next(null, user) : void 0;
      });
    },
    update: function(context, query, changes, next) {
      var plainPassword;
      plainPassword = void 0;
      Next(context, function(err, result, step) {
        var profileChanges;
        profileChanges = _.clone(changes);
        if (profileChanges.password) {
          plainPassword = String(profileChanges.password);
          profileChanges.salt = nonce();
          profileChanges.password = encryptPassword(plainPassword, profileChanges.salt);
        }
        return User._update(model.UserSelf.schema, context, _.rql(query).eq('id', context.user.id), profileChanges, step);
        /*
        					if plainPassword and @user.email
        						console.log 'PASSWORD SET TO', plainPassword
        						#	mail context.user.email, 'Password set', plainPassword
        					*/
      }, function(err, result, step) {
        return User.update(context, _.rql(query).ne('id', context.user.id), changes, step);
      }, function(err) {
        return typeof next == "function" ? next(err) : void 0;
      });
    },
    remove: function(context, query, next) {
      User.remove(context, _.rql(query).ne('id', context.user.id), next);
    },
    "delete": function(context, query, next) {
      User["delete"](context, _.rql(query).ne('id', context.user.id), next);
    },
    undelete: function(context, query, next) {
      User.undelete(context, _.rql(query).ne('id', context.user.id), next);
    },
    purge: function(context, query, next) {
      User.purge(context, _.rql(query).ne('id', context.user.id), next);
    },
    getProfile: function(context, next) {
      var _ref;
      User._get(model.UserSelf.schema, context, (_ref = context.user) != null ? _ref.id : void 0, next);
    },
    setProfile: function(context, changes, next) {
      var _ref;
      User._update(model.UserSelf.schema, context, [(_ref = context.user) != null ? _ref.id : void 0], changes, function(err, result) {
        if (err) {
          return typeof next == "function" ? next(err) : void 0;
        }
        return model.User.getProfile(context, next);
      });
    },
    verify: function(data, next) {
      if (data == null) {
        data = {};
      }
      return Next(null, function(err, result, step) {
        return model.User.getContext(data.user, step);
      }, function(err, context, step) {
        var session, user;
        user = context.user;
        if (!user.id) {
          if (data.user) {
            return step('Invalid user');
          } else {
            return step();
          }
        } else {
          if (!user.password || user.blocked) {
            return step('Invalid user');
          } else if (user.password === encryptPassword(data.pass, user.salt)) {
            session = {
              uid: user.id
            };
            if (data.remember) {
              session.expires = new Date(15 * 24 * 60 * 60 * 1000 + Date.now());
            }
            return step(null, session);
          } else {
            return step('Invalid user');
          }
        }
      }, function(err, session, step) {
        return next(err, session);
      });
    },
    getContext: function(uid, next) {
      Next(null, function(err, result, step) {
        if (root.id === uid) {
          return step(null, _.clone(root));
        } else {
          return User._get(null, this, uid, step);
        }
      }, function(err, user, step) {
        var context, level;
        if (user == null) {
          user = {};
        }
        if (config.server.disabled && root.id !== user.id) {
          level = 'none';
        } else if (config.security.bypass || root.id === user.id) {
          level = 'root';
        } else if (user.id && user.type) {
          level = user.type;
        } else if (user.id) {
          level = 'user';
        } else {
          level = 'public';
        }
        if (!_.isArray(level)) {
          level = [level];
        }
        context = _.extend.apply(null, [{}].concat(level.map(function(x) {
          return facets[x];
        })));
        Object.defineProperty(context, 'user', {
          value: user
        });
        Object.defineProperty(context, 'verify', {
          value: model.User.verify
        });
        return typeof next == "function" ? next(null, context) : void 0;
      });
    }
  };
  _.each({
    affiliate: 'Affiliate',
    admin: 'Admin'
  }, function(name, type) {
    model[name] = {
      query: function(context, query, next) {
        return model.User.query(context, User.owned(context, query).eq('type', type), next);
      },
      get: function(context, id, next) {
        var query;
        query = User.owned(context, 'limit(1)').eq('type', type).eq('id', id);
        return model.User.query(context, query, function(err, result) {
          return typeof next == "function" ? next(err, result[0] || null) : void 0;
        });
      },
      add: function(context, data, next) {
        if (data == null) {
          data = {};
        }
        data.type = type;
        return model.User.add(context, data, next);
      },
      update: function(context, query, changes, next) {
        return model.User.update(context, User.owned(context, query).eq('type', type), changes, next);
      },
      remove: function(context, query, next) {
        return model.User.remove(context, User.owned(context, query).eq('type', type), next);
      },
      "delete": function(context, query, next) {
        return model.User["delete"](context, User.owned(context, query).eq('type', type), next);
      },
      undelete: function(context, query, next) {
        return model.User.undelete(context, User.owned(context, query).eq('type', type), next);
      },
      purge: function(context, query, next) {
        return model.User.purge(context, User.owned(context, query).eq('type', type), next);
      }
    };
    return Object.defineProperties(model[name], {
      id: {
        value: name
      },
      schema: {
        value: User.schema
      }
    });
  });
  model.Geo.fetch = function(context, callback) {
    context.Geo.remove(context, 'a!=b', function() {
      _.each(require('geoip')().countries, function(rec) {
        if (rec.iso3.length < 3) {
          return;
        }
        return context.Geo.add(context, rec, function(err, result) {
          if (err) {
            return console.log('GEOFAILED', rec.name, err);
          }
        });
      });
      return callback();
    });
  };
  model.Currency.getDefault = function(context, callback) {
    return context.Currency.query(context, 'default=true', function(err, result) {
      return typeof callback == "function" ? callback(err, result && result[0]) : void 0;
    });
  };
  model.Currency.setDefault = function(context, data, callback) {
    if (data == null) {
      data = {};
    }
    context.Currency.update(context, void 0, {
      "default": false
    }, function(err, result) {
      if (err) {
        return typeof callback == "function" ? callback(err) : void 0;
      }
      return context.Currency.update(context, [data.id], {
        "default": true,
        active: true
      }, callback);
    });
  };
  model.Currency.fetch = function(context, callback) {
    Next({}, function(err, result, next) {
      return context.Currency.getDefault(context, next);
    }, function(err, defaultCurrency, next) {
      return require('./currency').fetchExchangeRates(defaultCurrency, next);
    }, function(err, courses, next) {
      var date;
      date = Date.now();
      _.each(courses, function(rec) {
        if (_.isEmpty(rec.value)) {
          rec.value = void 0;
        } else {
          rec.value = _.reduce(rec.value, (function(s, y) {
            return s += y;
          }), 0) / _.size(rec.value);
        }
        rec.date = date;
        return context.Currency.add(context, rec, function(err, result) {
          var _ref;
          if ((err != null ? (_ref = err[0]) != null ? _ref.message : void 0 : void 0) === 'duplicated') {
            return context.Currency.update(context, [rec.id], rec, function(err, result) {});
          } else if (err) {
            if (err) {
              return console.log('CURFAILED2', rec.name, err);
            }
          }
        });
      });
      return callback();
    });
  };
  PermissiveFacet = function() {
    var expose, obj, plus;
    obj = arguments[0], plus = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    expose = ['schema', 'id', 'query', 'get', 'add', 'update', 'remove', 'delete', 'undelete', 'purge'];
    if (plus.length) {
      expose = expose.concat(plus);
    }
    return _.proxy(obj, expose);
  };
  FacetForGuest = _.freeze(_.extend({}, {
    getRoot: function(context, query, next) {
      var k, s, user, v;
      s = {};
      for (k in context) {
        if (!__hasProp.call(context, k)) continue;
        v = context[k];
        if (typeof v === 'function') {
          s[k] = true;
        } else if (v.schema) {
          s[k] = {
            schema: v.schema,
            methods: _.functions(v)
          };
        }
      }
      user = context.user;
      return next(null, {
        user: {
          id: user.id,
          email: user.email,
          type: user.type
        },
        schema: s
      });
    }
  }));
  FacetForUser = _.freeze(_.extend({}, FacetForGuest, {
    getProfile: model.User.getProfile,
    setProfile: model.User.setProfile
  }));
  FacetForRoot = _.freeze(_.extend({}, FacetForUser, {
    Affiliate: PermissiveFacet(model.Affiliate),
    Admin: PermissiveFacet(model.Admin),
    Role: PermissiveFacet(model.Role),
    Group: PermissiveFacet(model.Group),
    Language: PermissiveFacet(model.Language),
    Currency: PermissiveFacet(model.Currency, 'fetch', 'setDefault'),
    Geo: PermissiveFacet(model.Geo, 'fetch')
  }));
  FacetForAffiliate = _.freeze(_.extend({}, FacetForUser, {}));
  FacetForReseller = _.freeze(_.extend({}, FacetForAffiliate, {
    Affiliate: FacetForRoot.Affiliate
  }));
  FacetForMerchant = _.freeze(_.extend({}, FacetForUser, {}));
  FacetForAdmin = _.freeze(_.extend({}, FacetForUser, {
    Affiliate: FacetForRoot.Affiliate,
    Admin: FacetForRoot.Admin,
    Role: FacetForRoot.Role,
    Group: FacetForRoot.Group,
    Language: FacetForRoot.Language,
    Currency: FacetForRoot.Currency,
    Geo: FacetForRoot.Geo
  }));
  facets.public = FacetForGuest;
  facets.user = FacetForUser;
  facets.root = FacetForRoot;
  facets.affiliate = FacetForAffiliate;
  facets.merchant = FacetForMerchant;
  facets.admin = FacetForAdmin;
  app = global.app = {
    getContext: model.User.getContext
  };
  return typeof callback == "function" ? callback(null, app) : void 0;
};