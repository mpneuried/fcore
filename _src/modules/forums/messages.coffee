mcprefix = "fc_m"

_ = require "lodash"
users = null
threads = null

FIELDS = ["id, tid, fid, a, p, v, cid"]

class Messages
	delete: (o, cb) ->
		if utils.validate(o, ["fid","tid","mid"], cb) is false
			return
		query =
			name: "delete msg"
			text: "DELETE FROM m WHERE fid = $1 AND tid = $2 AND id = $3 RETURNING #{FIELDS};"
			values: [
				o.fid
				o.tid
				o.mid
			]
		utils.pgqry query, (err, msg) ->
			if err
				cb(err)
				return
			if msg.rowCount is 0
				utils.throwError(cb, "messageNotFound")
				return

			# Delete Memcached Entry
			memcached.del _mckey(o), ->
			threads.get o, (err, thread) ->
				if err
					cb(err)
					return
				cb(null, {thread: thread, message: utils.messagePrepare(msg.rows[0])})
				return			
			return
		return

	get: (o, cb) ->
		if utils.validate(o, ["fid","tid","mid"], cb) is false
			return
		key = "#{mcprefix}#{o.mid}"
		memcached.get key, (err, resp) ->
			if err
				cb(err)
				return
			if resp isnt undefined
				# Cache hit
				cb(null, resp)
				return
			query =
				name: "get msg"
				text: "SELECT #{FIELDS} FROM m WHERE fid = $1 AND tid = $2 AND id = $3"
				values: [
					o.fid
					o.tid
					o.mid
				]
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					utils.throwError(cb, "messageNotFound")
					return
				_cacheAndReturn(resp.rows[0], cb)
				return
			return
		return 


	# Insert a new mesage
	#
	# Parameters:
	#
	# * `fid` (String) Forum Id
	# * `tid` (String) Thread Id.
	# * `p` (Object) Properties
	#
	insert: (o, cb) ->
		if utils.validate(o, ["fid","a","p","tid","ts"], cb) is false
			return
		users.verify o, (err, user) ->
			if err
				cb(err)
				return
			threads.get o, (err) ->
				if err
					cb(err)
					return
				
				if o.ts
					query =
						name: "insert msg with ts"
						text: "INSERT INTO m (id, tid, fid, a, p, cid) VALUES ($1, $2, $3, $4, $5, $6) RETURNING #{FIELDS};"
						values: [
							"M#{o.ts}"
							o.tid
							o.fid
							o.a
							utils.storeProps(o.p)
							user.cid
						]
				else
					query =
						name: "insert msg without ts"
						text: "INSERT INTO m (tid, fid, a, p, cid) VALUES ($1, $2, $3, $4, $5) RETURNING #{FIELDS};"
						values: [
							o.tid
							o.fid
							o.a
							utils.storeProps(o.p)
							user.cid
						]

				utils.pgqry query, (err, data) ->
					if err
						if err.detail.indexOf("already exists") > -1
							utils.throwError(cb, "messageExists")
							return
						cb(err)
						return
					msg = data.rows[0]
					threads.get _.extend(o, {nocache:1}), (err, thread) ->
						if err
							cb(err)
							return
						# We return the thread and the message
						result = 
							thread: thread

						_cacheAndReturn msg, (err, resp) ->
							if err
								cb(err)
								return
							result.message = resp							
							cb(null, result)
							return
						return
					return
				return
			return
		return


	# Messages by thread
	#
	# Parameters:
	# 
	# * `fid` (String) Forum Id
	# * `tid` (String) Thread Id.
	# * `forward` (String) Scan direction. Default: true
	# * `esk` (String) Message Id (as Exclusive Start Key)
	# * `limit` (String) Number of messages to return (Default: 50)
	#
	messagesByThread: (o, cb) ->
		o.limit = parseInt(o.limit or 50, 10)
		if o.limit > 50
			o.limit = 50

		if utils.validate(o, ["fid","tid","esk"], cb) is false
			return

		esk = ""
		order = "DESC"
		comparer = "<"

		if o.forward is "true"
			 order = "ASC"
			 comparer = ">"

		if o.esk
			esk = "AND id #{comparer} $4"

		query =
			name: "messages by thread#{o.forward}#{Boolean(o.esk)}"
			text: "SELECT #{FIELDS} FROM m WHERE fid = $1 and tid = $2 #{esk} ORDER BY ID #{order} LIMIT $3"
			values: [
				o.fid
				o.tid
				o.limit
			]
		if o.esk
			query.values.push(esk)
		console.log "QUERY", query.text, query.values
		utils.pgqry query, (err, resp) ->
			if err
				cb(err)
				return

			
			cb(null, utils.messageQueryPrepare(resp.rows))
			return
		return

	# Update a message
	update: (o, cb) ->
		if utils.validate(o, ["fid","tid","mid","a","p","v"], cb) is false
			return
		# Make sure this user exists
		users.verify o, (err, resp) =>
			if err
				cb(err)
				return
			@get o, (err, resp) ->
				if err
					cb(err)
					return

				o.p = utils.cleanProps(resp.p, o.p)
				if utils.validate(o, ["p"], cb) is false
					return

				# Nothing changed. Bail out and return the current item.
				if _.isEqual(resp.p, o.p) and resp.a is o.a
					cb(null, resp)
					return
				
				if resp.v isnt o.v
					utils.throwError(cb, "invalidVersion")
					return


				query =
					name: "update msg"
					text: "UPDATE m SET p = $1, la = $2, v = base36_timestamp() WHERE fid = $3 AND tid = $4 AND id = $5 AND v = $6 RETURNING #{FIELDS};" 
					values: [
						JSON.stringify(o.p)
						o.a
						o.fid
						o.tid
						o.mid
						o.v
					]					

				utils.pgqry query, (err, resp) ->
					if err
						cb(err)
						return
					if resp.rowCount is 0
						utils.throwError(cb, "invalidVersion")
						return
					threads.flush {fid: o.fid, id: o.tid}, (err) ->
						if err
							cb(err)
							return
						_cacheAndReturn(resp.rows[0], cb)
						return
					return	
				return
			return
		return


_cacheAndReturn = (msg, cb) ->
	msg = utils.messagePrepare(msg)
	memcached.set _mckey(msg), msg, 86400, ->
	cb(null, msg)
	return

_mckey = (o) ->
	return "#{mcprefix}#{o.id}"

module.exports = new Messages()

users = require "../communities/users"
threads = require "./threads"
