'use strict';module.exports = {
  server: {
    port: 3000,
    shutdownTimeout: 10000,
    repl: true,
    pub: {
      dir: '../public',
      ttl: 3600
    },
    stackTrace: true
  },
  security: {
    bypass: true,
    secret: 'change-me-on-production-server',
    root: {
      id: 'root',
      email: 'place-admin@here.com',
      password: '123',
      secret: '321',
      type: 'root'
    }
  },
  database: {
    url: ''
  },
  upload: {
    dir: 'upload'
  },
  defaults: {
    nls: 'en',
    currency: 'usd'
  }
};