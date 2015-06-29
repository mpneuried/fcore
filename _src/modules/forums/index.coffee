_ = require "lodash"
app = module.exports = express()
forums = require "./forums"
threads = require "./threads"
messages = require "./messages"
worker = require "./worker"

# All responses in this app are application/json
# Set it as the default
app.use (req, res, next) ->
	res.header('Content-Type', "application/json; charset=utf-8")
	next()
	return

app.enable('trust proxy')

BASE = "/f"


_respond = ( res )->
	return ( err, resp) ->
		if err
			_handleError(err, res)
			return
		status = 200
		
		if _.isEmpty(resp) and not _.isArray(resp)
			status = 404
		res.status(status).send(resp)
		return

#  _____                              
# |  ___|__  _ __ _   _ _ __ ___  ___ 
# | |_ / _ \| '__| | | | '_ ` _ \/ __|
# |  _| (_) | |  | |_| | | | | | \__ \
# |_|  \___/|_|   \__,_|_| |_| |_|___/

# Get
app.get "#{BASE}/:fid", (req, res) ->
	forums.get req.params, _respond(res)
	return


# Delete
app.delete "#{BASE}/:fid", (req, res) ->
	forums.delete req.params, _respond(res)
	return


# Insert
app.post "#{BASE}", (req, res) ->
	forums.insert req.body, _respond(res)
	return


# Update
app.post "#{BASE}/:fid", (req, res) ->
	forums.update _.extend(req.body, req.params), _respond(res)
	return


# Get all communities of tpid
app.get "#{BASE}/query/tpid/:tpid", (req, res) ->
	forums.bytpid req.params, _respond(res)
	return


# Get all communities of tpid
app.get "#{BASE}/query/cid/:cid", (req, res) ->
	forums.bycid req.params, _respond(res)
	return


#  _____ _                        _     
# |_   _| |__  _ __ ___  __ _  __| |___ 
#   | | | '_ \| '__/ _ \/ _` |/ _` / __|
#   | | | | | | | |  __/ (_| | (_| \__ \
#   |_| |_| |_|_|  \___|\__,_|\__,_|___/


# Insert
app.post "#{BASE}/:fid/threads", (req, res) ->
	threads.insert _.extend(req.body, req.params), _respond(res)
	return

# Delete a single Thread by id
app.delete "#{BASE}/:fid/threads/:tid", (req, res) ->
	threads.delete req.params, _respond(res)

# Get a single Thread by id
app.get "#{BASE}/:fid/threads/:tid", (req, res) ->
	threads.get req.params, _respond(res)
	return

# Update
app.post "#{BASE}/:fid/threads/:tid", (req, res) ->
	threads.update _.extend(req.body, req.params), _respond(res)
	return

# Query by Forum id
app.get "#{BASE}/:fid/query", (req, res) ->
	threads.threadsByForum _.extend(req.query, req.params), _respond(res)
	return




#  __  __                                     
# |  \/  | ___  ___ ___  __ _  __ _  ___  ___ 
# | |\/| |/ _ \/ __/ __|/ _` |/ _` |/ _ \/ __|
# | |  | |  __/\__ \__ \ (_| | (_| |  __/\__ \
# |_|  |_|\___||___/___/\__,_|\__, |\___||___/
#                             |___/           


# Insert
app.post "#{BASE}/:fid/threads/:tid/messages", (req, res) ->
	messages.insert _.extend(req.body, req.params), _respond(res)
	return

# Get
app.get "#{BASE}/:fid/threads/:tid/messages/:mid", (req, res) ->
	messages.get req.params, _respond(res)
	return

# Update
app.post "#{BASE}/:fid/threads/:tid/messages/:mid", (req, res) ->
	messages.update _.extend(req.body, req.params), _respond(res)
	return


# Delete
app.delete "#{BASE}/:fid/threads/:tid/messages/:mid", (req, res) ->
	messages.delete req.params, _respond(res)
	return

# Messages by thread id
app.get "#{BASE}/:fid/threads/:tid/query", (req, res) ->
	messages.messagesByThread _.extend(req.query, req.params), _respond(res)
	return
