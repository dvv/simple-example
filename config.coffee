'use strict'

fs = require 'fs'

module.exports =
	development:
		debug: true
		server:
			port: 3000
			workers: 0
			uid: 65534
			#sslKey: './config/key.pem'
			#sslCert: './config/cert.pem'
			repl: true
			views: 'app/views'
			static:
				dir: 'public'
				ttl: 3600
			#websocket: true
		security:
			#bypass: true
			secret: 'change-me-on-production-server'
			signupConfirmation: true
			recaptcha:
				pubkey: '6LcYML4SAAAAAMrP_hiwsXJo3FtI21gKiZ1Jun7U'
				privkey: '6LcYML4SAAAAAPby-ghBSDpi97JP1LYI71O-J6kx'
			roots:
				root:
					id: 'root'
					email: 'dronnikov@gmail.com'
					password: '123'
					type: 'root'
					active: true
		database:
			url: 'mongodb://127.0.0.1/ko'
			url2: 'mongodb://dvv:dvv@flame.mongohq.com:27068/irc'
			hardLimit: 100
		upload:
			dir: `(function(){var path='upload';try{fs.mkdirSync(path,0750);}catch(err){};return path;})()`
		mail:
			host: '127.0.0.1'
			port: 25
			domain: 'archonsoftware.com'
			from: 'dvv@archonsoftware.com'
			support: 'support@archonsoftware.com'
		defaults:
			nls: 'en'
			currency: 'usd'
