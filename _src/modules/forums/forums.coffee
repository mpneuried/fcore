_ = require "lodash"
async = require "async"
communities = null
threads = null
mcprefix = "fc_f"

TABLENAME = "fcore_f"

class Forums



	# Get all forums by Community id
	#
	# Parameters:
	# 
	# * `cid` (String)
	#
	bycid: (o, cb) ->
		if utils.validate(o, ["cid"], cb) is false
			return
		query =
			name: "forums by cid"
			text: "SELECT id, cid, v, p, tt, tm FROM f WHERE cid = $1"
			values: [
				o.cid
			]


		utils.pgqry query, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.forumQueryPrepare(resp.rows))
			return
		return

	# Get all forums by ThirdPartyId
	#
	# Parameters:
	# 
	# * `tpid` (String)
	#
	bytpid: (o, cb) ->
		if utils.validate(o, ["tpid"], cb) is false
			return
		query =
			name: "forums by tpid"
			text: "SELECT id, cid, v, p, tt, tm FROM f WHERE tpid = $1"
			values: [
				o.tpid
			]


		utils.pgqry query, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.forumQueryPrepare(resp.rows))
			return
		return


	# Try to find threads for this forum and delete them
	#
	cleanup: (o, cb) ->
		threads.threadsByForum o, (err, resp) ->
			if err
				cb(err)
				return
			if not resp.length
				cb(null, 0)
				return
			jobs = []
			_.each resp, (e) ->
				m =
					noupdate: true
					fid: o.fid
					tid: e.id

				jobs.push (callback) ->
					threads.delete(m, callback)
					return
				return
			async.parallelLimit jobs, 2, (err, results) ->
				if results.length < 100
					cb(null, 0) # No more threads. Can delete this message.
				else
					cb(null, true) # More threads. Keep the queued message.
				return
			return
		return

	# Delete a forum
	# 
	# * Queue the forum for deletion
	#
	delete: (o, cb) ->
		if utils.validate(o, ["fid"], cb) is false
			return
		@get o, (err, forum) ->
			if err
				cb(err)
				return
			query =
				name: "delete Forum"
				text: "DELETE FROM f WHERE id = $1"
				values: [
					o.fid
				]
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					utils.throwError(cb, "forumNotFound")
					return
				# An item was found and deleted.
				#
				# There are threads in the forum. Take care of them.
				if forum.tt > 0
					rsmq.sendMessage {qname: QUEUENAME, message: JSON.stringify({action: "df", fid: o.fid})}, (err, resp) ->
						if err
							console.error "ERROR trying to send RSMQ message", err
						console.log "RSMQ DELETE FORUM", resp
						return
				# Delete the cache for this forum
				memcached.del "#{mcprefix}#{o.fid}", (err) -> 
					if err
						cb(err)
						return
					cb(null, utils.respPrepare(forum))
					return
				return
		return

	get: (o, cb) ->
		if utils.validate(o, ["fid"], cb) is false
			return
		key = "#{mcprefix}#{o.fid}"
		memcached.get key, (err, resp) ->
			if err
				cb(err)
				return
			if resp isnt undefined
				# Cache hit
				cb(null, resp)
				return
			# Get the item from DB
			query = 
				name: "get forum by id"
				text: "SELECT id, cid, v, p, tt, tm FROM f WHERE id = $1"
				values: [
					o.fid
				]
			utils.pgqry query, (err, data) ->
				if err
					cb(err)
					return
				if not data.rows.length 
					utils.throwError(cb, "forumNotFound")
					return

				_cacheAndReturn(data.rows[0], cb)
				return
			return
		return 





	# Insert a new forum
	#
	# Parameters:
	#
	# * `p` (Object) Properties. Must include at least a `tpid` (String) key.
	# * `cid` (String) Community Id
	#
	insert: (o, cb) ->
		that = @
		if utils.validate(o, ["p","cid"], cb) is false
			return

		# Make sure this community exists
		communities.get {cid: o.cid}, (err, resp) ->
			if err
				cb(err)
				return
			query =
				name: "insert forum"
				text: "INSERT INTO f (cid, tpid, p) VALUES ($1, $2, $3) RETURNING id, cid, v, p, tt, tm;"
				values: [
					o.cid
					o.cid.split("_")[0]
					utils.storeProps(o.p)
				]

			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount isnt 1
					utils.throwError(cb, "insertFailed")
					return
				_cacheAndReturn(resp.rows[0], cb)
				return
			return
		return


	# Update a forum
	#
	# Parameters:
	#
	# * `id` (String) The id of the community
	# * `n` (String) Name
	# * `p` (Object) Properties. Must include at least a `tpid` (String) key.
	# * `v` (Number) The current version number must be supplied for a successful update.
	#
	update: (o, cb) ->
		if utils.validate(o, ["fid","p","v"], cb) is false
			return
		console.log "upd", o
		@get o, (err, resp) ->
			console.log "..sd.", err, resp
			if err
				cb(err)
				return
			if resp.v isnt o.v
				utils.throwError(cb, "invalidVersion")
				return

			o.p = utils.cleanProps(resp.p, o.p)
			if utils.validate(o, ["p"], cb) is false
				return

			# Nothing changed. Bail out and return the current item.
			if _.isEqual(resp.p, o.p)
				cb(null, resp)
				return
			
			query =
				name: "update forum"
				text: "UPDATE f SET p = $1, v = base36_timestamp() WHERE id = $2 AND v = $3 RETURNING id, cid, v, p, tt, tm;"
				values: [
					JSON.stringify(o.p)
					o.fid
					o.v
				]
			
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					utils.throwError(cb, "invalidVersion")
					return
				_cacheAndReturn(resp.rows[0], cb)
				return
			return
		return

	# Update the counters of a forum
	#
	# Parameters:
	#
	# * `fid` (String) The id of the forum
	# * `tt` (Number) The number to modify tt (Total Threads) with.
	# * `tm` (Number) The number to modify tt (Total Messages) with.
	#
	updateCounter: (o, cb) ->
		if utils.validate(o, ["fid","tm", "tt"], cb) is false
			return

		# Make sure the forum exists
		@get o, (err, resp) ->
			if err
				cb(null, {})
				return

			utils.getTimestamp (err, ts) ->
				if err
					cb(err)
					return
				params =
					TableName: TABLENAME
					Key:
						id:
							S: o.fid
					AttributeUpdates:
						tm:
							Action: "ADD"
							Value:
								N: "#{o.tm}"
						tt:
							Action: "ADD"
							Value:
								N: "#{o.tt}"
						v:
							Value:
								S: ts
					ReturnValues: "ALL_NEW"
					Expected:
						id:
							ComparisonOperator: "NOT_NULL"
				dynamodb.updateItem params, (err, data) ->		
					if err
						cb(err)
						return
					_cacheAndReturn(data, cb)
					return
				return
			return
		return

_cacheAndReturn = (data, cb) ->
	key = "#{mcprefix}#{data.id}"
	data = utils.respPrepare(data)
	if data.id
		memcached.set key, data, 86400, ->
	cb(null, data)
	return


module.exports = new Forums()

communities = require "../communities/communities"
threads = require "./threads"
