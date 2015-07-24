_ = require "lodash"
async = require "async"
forums = null
users = null
messages = null
TABLENAME = "fcore"

mcprefix = "fc_t"

FIELDS = "id, fid, a, v, la, lm, tm, p, top"

class Threads
	# Try to grab messages of a deleted thread 
	#
	# If there are messages, delete them.
	cleanup: (o, cb) ->
		console.log "RUNNING THREADS.cleanup"
		messages.messagesByThread o, (err, resp) ->
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
					tid: o.tid
					mid: e.id

				jobs.push (callback) ->
					messages.delete(m, callback)
					return
				return
			async.parallelLimit jobs, 2, (err, results) ->
				if err
					console.log "Error: cleanup async", err
					cb(err)
					return
				if results.length < 50
					cb(null, 0) # No more threads. Can delete this message.
				else
					cb(null, true) # More threads. Keep the queued message.
				return
			return
		return


	delete: (o, cb) ->
		if utils.validate(o, ["tid","fid"], cb) is false
			return
		@get o, (err, resp) ->
			if err
				cb(err)
				return
			query =
				name: "delete thread"
				text: "DELETE FROM t WHERE id = $1 and fid = $2 RETURNING #{FIELDS};"
				values: [
					o.tid
					o.fid
				]
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					utils.throwError(cb, "threadNotFound")
					return
				
				# Delete the cache for this thread
				memcached.del _mckey(o), (err) ->
					if err
						cb(err)
						return
					forums.flush o, (err) ->
						if err
							cb(err)
							return
						cb(null, utils.respPrepare(resp.rows[0]))
						return
					return
				return
			return
		return


	flush: (o, cb) ->
		console.log "flush threads",_mckey(o)
		memcached.del _mckey(o), (err) ->
			if err
				cb(err)
				return
			cb(null, true)
			return
		return


	get: (o, cb) ->
		if utils.validate(o, ["tid","fid"], cb) is false
			return
		memcached.get _mckey(o), (err, resp) ->
			if err
				cb(err)
				return
			if resp isnt undefined
				# Cache hit
				cb(null, resp)
				return
			
			query =
				name: "get thread"
				text: "SELECT #{FIELDS} FROM t where id = $1 and fid = $2"
				values: [
					o.tid
					o.fid
				]
				
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					utils.throwError(cb, "threadNotFound")
					return
				_cacheAndReturn(resp.rows[0], cb)
				return
			return
		return


	# Insert a new thread
	#
	# Parameters:
	#
	# * `fid` (String) Forum Id
	# * `a` (String) Author
	# * `p` (Object) Properties object
	#
	insert: (o, cb) ->
		if utils.validate(o, ["fid","a","p","ts","top"], cb) is false
			return
		# We verify the user for this forums community and return his name and community id.
		users.verify o, (err, user) ->
			if err
				cb(err)
				return

			if o.ts
				query =
					name: "insert thread with ts"
					text: "INSERT INTO t (id, fid, a, top, p) VALUES ($1, $2, $3, $4, $5) RETURNING #{FIELDS};"
					values: [
						"T#{o.ts}"
						o.fid
						o.a
						o.top
						utils.storeProps(o.p)
					]
			else
				query =
					name: "insert thread without ts"
					text: "INSERT INTO t (fid, a, top, p) VALUES ($1, $2, $3, $4) RETURNING #{FIELDS};"
					values: [
						o.fid
						o.a
						o.top
						utils.storeProps(o.p)
					]


			utils.pgqry query, (err, resp) ->
				if err
					if err.detail.indexOf("already exists") > -1
						utils.throwError(cb, "threadExists")
						return
					cb(err)
					return

				if resp.rowCount isnt 1
					utils.throwError(cb, "insertFailed")
					return
				forums.flush {id: o.fid}, (err) ->
					if err
						cb(err)
						return
					_cacheAndReturn(resp.rows[0], cb)
					return
				return
			return
		return


	# Threads by forum
	#
	# Parameters:
	# 
	# * `fid` (String) Forum Id
	#
	threadsByForum: (o, cb) ->
		if utils.validate(o, ["fid","esk"], cb) is false
			return

		esk = ""
		order = "ORDER BY lm"

		if o.bylm isnt "true"
			order = "ORDER BY id"

		if o.forward is "true"
			order = order + " ASC"
			comparer = ">"
		else
			order = order + " DESC"
			comparer = "<"

		if o.esk
			if o.bylm is "true" 
				esk = "AND lm #{comparer} $2"
			else
				esk = "AND id #{comparer} $2"

		query =
			text: "SELECT #{FIELDS} FROM t WHERE fid = $1 #{order} LIMIT 50"
			values: [
				o.fid
			]
		
		if o.esk
			query.values.push(esk)

		utils.pgqry query, (err, resp) =>
			if err
				cb(err)
				return
			if resp.rowCount > 0
				lastitem = _.last(resp.rows)
				lastitem.lek = lastitem.id
								

			cb(null, utils.threadQueryPrepare(resp.rows))
			return
		return


	update: (o, cb) ->
		if utils.validate(o, ["tid","fid","p","v","top"], cb) is false
			return
		@get o, (err, resp) ->
			if err
				cb(err)
				return
		
			o.p = utils.cleanProps(resp.p, o.p)
			if utils.validate(o, ["p"], cb) is false
				return

			# Nothing changed. Bail out and return the current item.
			if _.isEqual(resp.p, o.p) and _stickyUnchanged(resp, o)
				cb(null, resp)
				return

			if resp.v isnt o.v
				utils.throwError(cb, "invalidVersion")
				return

			lm = _.capitalize(resp.lm)

			if resp.top
				lm = resp.lm.toLowerCase()
			
			query =
				name: "update thread"
				text: "UPDATE t SET p = $1, v = base36_timestamp(), top = $2, lm = $3 WHERE fid = $4 AND id = $5 RETURNING #{FIELDS};"
				values: [
					JSON.stringify(o.p)
					o.top
					lm
					o.fid
					o.tid
				]
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					utils.throwError(cb, "invalidVersion")
					return

				forums.flush o, (err) ->
					if err
						cb(err)
						return
					console.log resp.rows[0]
					_cacheAndReturn(resp.rows[0], cb)
					return
				return
			return
		return


	_lastAuthor: (o, cb) ->
		if o.a
			cb(null, {a:o.a})
			return

		messages.messagesByThread _.extend(o, {limit: 1}), (err, resp) ->
			if err
				cb(err)
				return
			if resp.length
				cb(null, resp[0])
			else
				cb(null, {a:""})
			return
		return


_stickyUnchanged = (resp, o) ->
	if resp.top is o.top or (not resp.top? and o.top is null)
		return true
	return false


_cacheAndReturn = (data, cb) ->
	data = utils.threadPrepare(data)
	if data.id
		memcached.set _mckey(data), data, 86400, ->
	cb(null, data)
	return

_mckey = (o) ->
	cachebuster = ""
	if o.nocache
		cachebuster = Math.random()
	return "#{mcprefix}#{o.fid}_#{o.id}#{cachebuster}"

module.exports = new Threads()

forums = require "./forums"
users = require "../communities/users"
messages = require "./messages"
