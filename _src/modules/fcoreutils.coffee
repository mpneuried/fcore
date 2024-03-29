_ = require "lodash"
pg = require "pg"
conString = "postgres://#{process.env.POSTGRESQL_USER or config.db.user}:#{process.env.POSTGRESQL_PW or config.db.pw}@#{process.env.POSTGRESQL_HOST or config.db.host}/#{process.env.POSTGRESQL_DBNAME or config.db.name}"

if root.config.rsmq?
	RedisSMQ = require("rsmq")
	rsmq = new RedisSMQ( root.config.rsmq )
	rsmq.createQueue root.config.messages.queue, (err, resp) ->
		if err
			if err.message? and err.message is "Queue exists"
				console.log "OK: RSMQ Queue exists."
			else
				console.log err
			return
		if resp
			console.log "OK: RSMQ Queue created."
			return


LASTTIMESTAMP = 0

class Utils

	cleanProps: (current_props, new_props) ->
		nullkeys = for key of new_props when new_props[key] is null
			key
		# OK ready to set some data
		o = _.extend(_.clone(current_props), new_props)
		return _.omit(o, nullkeys)

	
	communityQueryPrepare: (items) ->
		for e in items
			@respPrepare(e)
		

	forumQueryPrepare: (items) ->
		for e in items
			@respPrepare(e)


	mcFlush : (id, cb) ->
		memcached.del "#{root.MCPREFIX}#{id}", (err) ->
			if err
				cb(err)
				return
			cb(null, true)
			return
		return


	getRandomInt: (min, max) ->
		return Math.floor(Math.random() * (max - min)) + min


	isStringNumberBooleanNull: (item) ->
		if not _.isString(item) and not _.isNumber(item) and not _.isBoolean(item) and not _.isNull(item)
			return false
		return true


	isArrayStringNumberBooleanNull: (item) ->
		if not _.isString(item) and not _.isNumber(item) and not _.isBoolean(item) and not _.isNull(item) and not _.isArray(item)
			return false
		return true


	# limitCheck
	#
	# Check an o.limit value
	#
	# Parameters:
	#
	# * o (Object): The object of which an o.limit value should be checked
	# * d (Number): The default value if o.limit is undefined of falsy
	# * m: The max value to which o.limit will be reduced if bigger
	#
	limitCheck: (o, d, m) ->
		o.limit = parseInt(o.limit or d, 10)
		if _.isNaN(o.limit) or o.limit > m or o.limit < 1
			o.limit = m
		return o


	messageQueryPrepare: (items) ->
		for e in items
			@messagePrepare(e)


	messagePrepare: (item)->
		if _.isString(item.p)
			item.p = JSON.parse(item.p)
		return _.omit(item, ["pid","fid","cid"])


	pgqry: (options, cb) ->
		pg.connect conString, (err, client, done) ->
			handleError = (err) ->
				if not err
					return false
				done(client)
				cb(err)
				return true

			client.query options, (err, result) ->
				if handleError(err)
					return
				done()
				cb(null, result)
				return
			return
		return


	respPrepare: (item)->
		if _.isString(item.p)
			item.p = JSON.parse(item.p)
		return item


	# Send a message to a queue to further work on it
	# for example to index it in Elasticsearch
	sendMessage: (message, cb) ->
		if _.isObject(message)
			message = JSON.stringify(message)
		rsmq.sendMessage {qname: root.config.messages.queue.qname, message}, cb
		return


	storeProps: (p) ->
		nullkeys = for key of p when p[key] is null
			key
		JSON.stringify(_.omit(p, nullkeys))


	threadPrepare: (item)->
		if _.isString(item.p)
			item.p = JSON.parse(item.p)
		if item.lm
			item.lm = "M#{item.lm[-8..]}"
		return item


	threadQueryPrepare: (items) ->
		for e in items
			@threadPrepare(e)


	throwError: (cb, err, data={}) ->
		# try to create a error Object with humanized message
		if _.isString(err)
			_err = new Error()
			_err.name = err
			_err.message = _ERRORS?[err]?(data) or "unkown"
		else 
			_err = err
		cb(_err)
		return


	userQueryPrepare: (items) ->
		for e in items
			@respPrepare(e)


	validate: (o, items, cb) ->
		for item in items
			switch item
				when "cid"
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string"})
						return false
					if not o[item]?
						@throwError(cb, "missingParameter", {item:item})
						return false
					if not _VALID.cid.test(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be in the format XXXX_abcd1234"})
						return false
				when "extid"
					if o[item]?
						if not _.isString(o[item])
							@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string."})
							return false
						if not _VALID.extid.test(o[item])
							@throwError(cb, "invalidValue", {msg:"`#{item}` must be between 1 and 256 chars"})
							return false
				when "fid", "v", "tid", "mid"
					if not o[item]?
						@throwError(cb, "missingParameter", {item:item})
						return false
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string"})
						return false
					o[item] = o[item][0...9]
				# User id
				when "id", "a", "la"
					if not o[item]?
						@throwError(cb, "missingParameter", {item:item})
						return false
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string"})
						return false
					if not _VALID.id.test(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must only contain [a-zA-Z0-9-_] and must be 3-32 characters long"})
						return false
					# User Ids should be lowercase
					if item is "id"
						o[item] = o[item].toLowerCase()
				when "p"
					o[item] = o[item] or {}
					if not _.isObject(o.p) or _.isArray(o.p)
						@throwError(cb, "invalidValue", {msg:"`p` must be an object"})
						return false
					if _.keys(o.p).length > 64
						@throwError(cb, "invalidValue", {msg:"`p` must not contain more than 64 keys."})
						return false
					# Check if every key is either a boolean, string or a number
					for e of o.p
						if not @isArrayStringNumberBooleanNull(o.p[e])
							@throwError(cb, "invalidValue", {msg:"`p.#{e}` has a forbidden type. Only arrays, strings, numbers, boolean and null are allowed."})
							return false
						# Make sure only strings, numbers, boolean or null are in the array
						if _.isArray(o.p[e])
							if o.p[e].length > 64
								@throwError(cb, "invalidValue", {msg:"An arrry inside `p` must not contain more than 64 elements."})
								return false
							for item in o.p[e]
								if not @isStringNumberBooleanNull(item)
									@throwError(cb, "invalidValue", {msg:"`p.#{e}` has a forbidden type. Arrays may only contain strings, numbers, boolean and null."})
									return false
				when "esk"
					if not o[item]?
						return true
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string."})
						return false
					if not o[item].length is 9
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be 9 characters long"})
						return false
					if not _VALID.ts.test(o[item][1...])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must only contain [a-zA-Z0-9]"})
						return false
				when "tpid"
					if not o[item]?
						@throwError(cb, "missingParameter", {item:item})
						return false
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string."})
						return false
					if not _VALID.tpid.test(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must only contain [a-zA-Z0-9-]"})
						return false
				when "top"
					if o[item] and parseInt(o[item],2)
						o[item] = 1
					else
						o[item] = 0
				when "ts"
					if o[item]?
						if not _VALID.ts.test(o[item])
							@throwError(cb, "invalidValue", {msg:"`#{item}` must be a valid alpha-numeric timestamp."})
							return false
				when "type"
					if o[item] is "p"
						o[item] = ["id","p"]
					else if o[item] is "all"
						o[item] = ["id","c","p","v"]
					else
						o[item] = ["id"]
				when "bylm", "forward"
					if o[item] is "true"
						o[item] = 1
					else
						o[item] = 0	
		return o

# Error handling
ERRORS =
	"missingParameter": "No `<%= item %>` supplied"
	"invalidValue": "<%= msg %>"
	"invalidVersion": "Invalid version"
	"externalIdNotFound": "External Id not found"
	"userNotFound": "User not found"
	"threadExists": "Thread exists already"
	"messageExists": "Message exists already"
	"userExists": "User name exists already"
	"forumNotFound": "Forum not found"
	"communityNotFound": "Community not found"
	"messageNotFound": "Message not found"
	"threadNotFound": "Thread not found"
	"externalIdNotUnique": "External Id not unique"
	"communityHasForums": "Community still has forums"
	"insertFailed": "DB insert failed"


_ERRORS = {}
	

_VALID =
	cid: /^[a-zA-Z0-9-]{3,32}[_][a-z0-9]{8}$/
	tpid: /^[a-zA-Z0-9-]{3,32}$/
	id: /^[a-zA-Z0-9-_]{3,32}$/
	extid: /^.{1,256}$/
	ts: /^[a-z0-9]{8}$/


_initErrors = ->
	for key, msg of ERRORS
		_ERRORS[key] = _.template(msg)
	return


_initErrors()

module.exports = new Utils()
