app = module.exports = express()

_ = require "lodash"

communities = require "./communities"
users = require "./users"

# All responses in this app are application/json
# Set it as the default
app.use (req, res, next) ->
	res.header('Content-Type', "application/json; charset=utf-8")
	next()
	return

app.enable('trust proxy')

BASE = "/c"


_respond = ( res )->
	return (err, resp) ->
		if err
			if err.name in ["communityNotFound", "userNotFound"]
				_handleError(err, res, 404)
			else
				_handleError(err, res)
			return
		status = 200
		if _.isEmpty(resp) and not _.isArray(resp)
			status = 404
		res.status(status).send(resp)
		return

#   ____                                      _ _   _           
#  / ___|___  _ __ ___  _ __ ___  _   _ _ __ (_) |_(_) ___  ___ 
# | |   / _ \| '_ ` _ \| '_ ` _ \| | | | '_ \| | __| |/ _ \/ __|
# | |__| (_) | | | | | | | | | | | |_| | | | | | |_| |  __/\__ \
#  \____\___/|_| |_| |_|_| |_| |_|\__,_|_| |_|_|\__|_|\___||___/

# Get
app.get "#{BASE}/:cid", (req, res) ->
	communities.get req.params, _respond(res)
	return


# Delete
app.delete "#{BASE}/:cid", (req, res) ->
	communities.delete _.extend(req.query, req.params), _respond(res)
	return


# Get all communities of tpid
app.get "#{BASE}/query/tpid/:tpid", (req, res) ->
	communities.bytpid req.params, _respond(res)
	return


# Insert
app.post "#{BASE}", (req, res) ->
	communities.insert req.body, _respond(res)
	return


# Update
app.post "#{BASE}/:cid", (req, res) ->
	communities.update _.extend(req.body, req.params), _respond(res)
	return


#  _   _                   
# | | | |___  ___ _ __ ___ 
# | | | / __|/ _ \ '__/ __|
# | |_| \__ \  __/ |  \__ \
#  \___/|___/\___|_|  |___/

# Get
app.get "#{BASE}/:cid/users/:id", (req, res) ->
	users.get req.params, _respond(res)
	return
 

# Delete
app.delete "#{BASE}/:cid/users/:id", (req, res) ->
	users.delete req.params, _respond(res)
	return


# get users
app.get "#{BASE}/:cid/users", (req, res) ->
	users.users _.extend(req.params, req.query), _respond(res)
	return


# Insert
app.post "#{BASE}/:cid/users", (req, res) ->
	users.insert _.extend(req.body, req.params), _respond(res)
	return


# Update
app.post "#{BASE}/:cid/users/:id", (req, res) ->
	users.update _.extend(req.body, req.params), _respond(res)
	return


# Messages by User
app.get "#{BASE}/:cid/users/:id/msgcount", (req, res) ->
	users.msgcount req.params, _respond(res)
	return


# Messages by User
app.get "#{BASE}/:cid/users/:id/query", (req, res) ->
	users.messagesByUser _.extend(req.query, req.params), _respond(res)
	return
