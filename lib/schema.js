'use strict';var UserEntity, config, cr, ro, schema, wo;
config = require('./config');
ro = function(attr) {
  return _.extend({}, attr, {
    veto: {
      update: true
    }
  });
};
wo = function(attr) {
  return _.extend({}, attr, {
    veto: {
      get: true
    }
  });
};
cr = function(attr) {
  return _.extend({}, attr, {
    veto: {
      get: true,
      update: true
    }
  });
};
schema = {};
schema.Language = {
  type: 'object',
  additionalProperties: false,
  properties: {
    id: {
      type: 'string',
      pattern: '^[a-zA-Z0-9_]+$',
      veto: {
        update: true
      }
    },
    name: {
      type: 'string'
    },
    localName: {
      type: 'string'
    }
  }
};
schema.Geo = {
  type: 'object',
  additionalProperties: false,
  properties: {
    id: {
      type: 'string',
      pattern: /^[A-Z]{2}$/,
      veto: {
        update: true
      }
    },
    name: {
      type: 'string'
    },
    iso3: {
      type: 'string',
      pattern: /^[A-Z]{3}$/
    },
    cont: {
      type: 'string',
      "default": 'EU',
      "enum": ['AF', 'AN', 'AS', 'EU', 'NA', 'OC', 'SA']
    },
    tz: {
      type: 'array',
      items: {
        type: 'string'
      },
      optional: true
    }
  }
};
schema.Currency = {
  type: 'object',
  additionalProperties: false,
  properties: {
    id: {
      type: 'string',
      pattern: /^[A-Z]{3}$/,
      veto: {
        update: true
      }
    },
    name: {
      type: 'string',
      optional: true
    },
    value: {
      type: 'number',
      "default": 1
    },
    date: {
      type: 'date'
    },
    "default": {
      type: 'boolean',
      "default": false
    },
    active: {
      type: 'boolean',
      "default": false
    }
  }
};
schema.Role = {
  type: 'object',
  additionalProperties: false,
  properties: {
    id: {
      type: 'string',
      veto: {
        update: true
      }
    },
    name: {
      type: 'string',
      optional: true
    },
    rights: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          entity: {
            type: 'string',
            "enum": function() {
              return _.keys(model);
            }
          },
          access: {
            type: 'integer',
            "enum": [0, 1, 2, 3]
          }
        }
      }
    }
  }
};
schema.Group = {
  type: 'object',
  additionalProperties: false,
  properties: {
    id: {
      type: 'string',
      veto: {
        update: true
      }
    },
    name: {
      type: 'string',
      optional: true
    },
    roles: {
      type: 'array',
      items: _.extend({}, schema.Role.properties.id, {
        "enum": function(value, next) {
          return this.Role.get(value, function(err, result) {
            return next(!result);
          });
        }
      })
    }
  }
};
UserEntity = {
  type: 'object',
  properties: {
    id: {
      type: 'string',
      pattern: '^[a-zA-Z0-9_]+$',
      veto: {
        update: true
      }
    },
    type: {
      type: 'string',
      "enum": ['affiliate', 'admin']
    },
    roles: {
      type: 'array',
      items: {
        type: 'string',
        "enum": function(value, callback) {
          return this.Role.get(value, function(err, result) {
            return callback(!result, result);
          });
        }
      },
      optional: true
    },
    blocked: {
      type: 'string',
      optional: true
    },
    status: {
      type: 'string',
      "enum": ['pending', 'approved', 'declined'],
      "default": 'pending'
    },
    password: {
      type: 'string'
    },
    salt: {
      type: 'string'
    },
    secret: {
      type: 'string',
      optional: true
    },
    tags: {
      type: 'array',
      items: {
        type: 'string'
      },
      optional: true
    },
    name: {
      type: 'string',
      optional: true
    },
    email: {
      type: 'string',
      pattern: /^([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+@((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$/i,
      optional: true
    },
    timezone: {
      type: 'string',
      "enum": ['UTC-11', 'UTC-10', 'UTC-09', 'UTC-08', 'UTC-07', 'UTC-06', 'UTC-05', 'UTC-04', 'UTC-03', 'UTC-02', 'UTC-01', 'UTC+00', 'UTC+01', 'UTC+02', 'UTC+03', 'UTC+04', 'UTC+05', 'UTC+06', 'UTC+07', 'UTC+08', 'UTC+09', 'UTC+10', 'UTC+11', 'UTC+12'],
      "default": 'UTC+04'
    },
    lang: _.extend({}, schema.Language.properties.id, {
      "enum": function(value, next) {
        return next(null);
      },
      "default": config.defaults.nls
    })
  }
};
schema.User = {
  type: 'object',
  properties: {
    id: UserEntity.properties.id,
    type: ro(UserEntity.properties.type),
    roles: UserEntity.properties.roles,
    blocked: UserEntity.properties.blocked,
    status: UserEntity.properties.status,
    password: cr(UserEntity.properties.password),
    salt: cr(UserEntity.properties.salt),
    tags: UserEntity.properties.tags,
    name: ro(UserEntity.properties.name),
    email: ro(UserEntity.properties.email),
    timezone: ro(UserEntity.properties.timezone),
    lang: ro(UserEntity.properties.lang)
  },
  prototype: {
    signup: function(uid) {
      return this.add({
        user: {
          id: 'trickey'
        }
      }, {
        id: uid
      }, console.log);
    }
  }
};
schema.UserSelf = {
  type: 'object',
  properties: {
    id: UserEntity.properties.id,
    type: ro(UserEntity.properties.type),
    roles: ro(UserEntity.properties.roles),
    password: wo(UserEntity.properties.password),
    salt: wo(UserEntity.properties.salt),
    name: UserEntity.properties.name,
    email: UserEntity.properties.email,
    timezone: UserEntity.properties.timezone,
    lang: UserEntity.properties.lang,
    secret: UserEntity.properties.secret
  }
};
module.exports = schema;