# Temporary fix for https://github.com/awssum/awssum/issues/164
process.env.NODE_TLS_REJECT_UNAUTHORIZED = 0

if process.argv[2]? and process.argv[2] is "dev" or process.env.DEV
	console.log "LOADING DEV Settings"
	config = require "./config_dev.json"
	devmode = true
else
	config = require "./config.json"
	devmode = false

morgan = require "morgan"
compress = require "compression"
favicon = require "serve-favicon"
bodyParser = require "body-parser"
# server.js
# root.crypto = require "crypto"
root.utils = require "./modules/fcoreutils"
root.express = require "express"

Memcached = require "memcached"
root.memcached = new Memcached(config.memcached)

root.memcached.on 'issue', (details) ->
	console.log "Memcached issue", details
	return
root.memcached.on 'failure', (details) ->
	console.log "Memcached failure", details
	return

long_cache = 24 * 3600 * 1000 * 90 # 90 days

app = express()
app.enable('trust proxy')
app.use(bodyParser.json({limit:60000}))
app.use(compress({threshold: 512}))
app.use(favicon(__dirname + '/favicon.ico', {maxAge: long_cache}))
app.use(morgan('dev'))

root._handleError = (err, res, statuscode=403) ->
	if err.name in ["threadNotFound", "messageNotFound", "forumNotFound", "userNotFound","communityNotFound"]
		statuscode = 404
	console.log "-> ERROR: [#{err.toString()}]"
	if devmode
		console.log "--> STACK", err.stack
	res.status(statuscode).send(JSON.stringify(err))
	return

Communities = require "./modules/communities"
Forums = require "./modules/forums"

# add ping route to be able to check if the server is active
app.get "/ping", ( req, res )->
	res.status( 200 ).send( "OK" )
	return

app.use(Communities)
app.use(Forums)

app.use (err, req, res, next) ->
	# This will be called when for example an invalid JSON was supplied.
	console.log "server.js app error: ", err
	if devmode
		console.log "--> STACK", err.stack
	
	res.writeHead(500)
	# res.end('{"error":"Invalid format. Syntax error."}')
	res.end(JSON.stringify(err))
	return

_port = process.env.PORT or config.port or 3000
app.listen( _port )

console.log "Listening on Port #{_port}"
