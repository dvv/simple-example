'use strict';var config, simple;
config = require('./config');
simple = require('simple');
All({}, function(err, result, next) {
  return new simple.Database(config.database.url, require('./schema'), next);
}, function(err, exposed, next) {
  var model;
  model = exposed;
  return require('./app')(config, model, next);
}, function(err, app, next) {
  var getHandler;
  getHandler = function(server) {
    return simple.stack(simple.handlers.jsonBody({
      maxLength: 0
    }), simple.handlers.authCookie({
      cookie: 'uid',
      secret: config.security.secret,
      getContext: app.getContext
    }), simple.handlers.jsonrpc({
      maxBodyLength: 0
    }), simple.handlers.mount('GET', '/geo', function(req, res, next) {
      return res.send(require('fs').readFileSync('../node_modules/simple-geoip/geo.json'));
    }), simple.handlers.mount('GET', '/course', function(req, res, next) {
      return require('./currency').fetchExchangeRates(config.defaults.currency, function(err, data) {
        return res.send(err || data);
      });
    }), simple.handlers.dynamic({
      map: {
        '/': 'public/index.html'
      }
    }), simple.handlers.static({
      root: config.server.pub.dir,
      "default": 'index.html',
      cacheTTL: 1000
    }));
  };
  app = Object.freeze({
    getHandler: getHandler,
    messageHandler: function(broadcaster, message) {
      if (message.channel === 'bcast') {
        console.error('BCAST!', message);
        return typeof broadcaster == "function" ? broadcaster(message.data) : void 0;
      }
    }
  });
  if (process.argv[1] === 'test') {
    console.log('!!!TESTING MODE!!!');
    require('../test/000.basics')(app);
  }
  return simple.run(app, config.server);
}, function(err, result, next) {
  return console.log("OOPS, shouldn't have been here!", err);
});