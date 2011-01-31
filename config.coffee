'use strict'

module.exports =

	server:

		port: 3000
		workers: 0 #require('os').cpus().length
		#uid: 65534
		#gid: 65534
		#pwd: './secured-root'
		#sslKey: 'key.pem'
		#sslCert: 'cert.pem'
		repl: true
		static:
			dir: 'public'
			ttl: 3600
		stackTrace: true

	security:

		#bypass: true
		secret: 'change-me-on-production-server'
		roots:
			root:
				id: 'root'
				email: 'place-admin@here.com'
				password: '123'
				secret: '321'
				type: 'root'
				active: true

	database:

		url: 'mongodb://127.0.0.1/simple'
		filterBy: 'active'
		hardLimit: 100

	upload:

		dir: 'upload'

	defaults:

		nls: 'en'
		currency: 'usd'
