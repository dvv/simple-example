require.paths.unshift __dirname + '/../lib/node'

global.util     = require 'util'
global.put      = (args...) -> util.print a for a in args
global.puts     = (args...) -> put args.join('\n') + '\n'
global.p        = (args...) -> puts util.inspect(a, true, null) for a in args
global.pl       = (args...) -> put args.join(', ') + '\n'
global.assert   = require 'assert'
global.ansi     = require './ansi'
global.runner   = require './runner'
global.Storage  = require '../lib/node/simple/store'

global.timeout  = (time, next) -> setTimeout next, time
global.interval = (time, next) -> setInterval next, time

process.on 'SIGINT', ->
  process.exit()
process.on 'exit', ->
  put ansi.off

runner.dir __dirname
runner.load 'region'
runner.next()
