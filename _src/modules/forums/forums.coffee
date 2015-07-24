_ = require "lodash"
async = require "async"
communities = null
threads = null
mcprefix = "fc_f"

FIELDS = "id, cid, v, p, tt, tm"

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
			text: "SELECT #{FIELDS} FROM f WHERE cid = $1"
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
			text: "SELECT #{FIELDS} FROM f WHERE tpid = $1"
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
				text: "DELETE FROM f WHERE id = $1 RETURNING #{FIELDS};"
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
				# Delete the cache for this forum
				memcached.del _mckey(o), (err) -> 
					if err
						cb(err)
						return
					cb(null, utils.respPrepare(resp.rows[0]))
					return
				return
		return


	flush: (o, cb) ->
		memcached.del _mckey(o), (err) ->
			if err
				cb(err)
				return
			cb(null, true)
			return
		return


	get: (o, cb) ->
		if utils.validate(o, ["fid"], cb) is false
			return
		memcached.get _mckey({id: o.fid}), (err, resp) ->
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
				text: "SELECT #{FIELDS} FROM f WHERE id = $1"
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
				text: "INSERT INTO f (cid, tpid, p) VALUES ($1, $2, $3) RETURNING #{FIELDS};"
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
		@get o, (err, resp) ->
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
				text: "UPDATE f SET p = $1, v = base36_timestamp() WHERE id = $2 AND v = $3 RETURNING #{FIELDS};"
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


_cacheAndReturn = (data, cb) ->
	data = utils.respPrepare(data)
	if data.id
		memcached.set _mckey(data), data, 86400, (err,resp) ->
	cb(null, data)
	return

_mckey = (o) ->
	return "#{mcprefix}#{o.id}"

module.exports = new Forums()

communities = require "../communities/communities"
threads = require "./threads"
