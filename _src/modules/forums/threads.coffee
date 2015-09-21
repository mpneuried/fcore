_ = require "lodash"
forums = null
users = null
messages = null

FIELDS = "id, fid, a, v, la, lm, tm, p, top"

class Threads


	delete: (o, cb) ->
		if root.utils.validate(o, ["tid","fid"], cb) is false
			return
		@get o, (err, resp) ->
			if err
				cb(err)
				return
			query =
				name: "delete thread"
				text: "DELETE FROM t WHERE fid = $1 AND id = $2 RETURNING #{FIELDS};"
				values: [
					o.fid
					o.tid
				]
			root.utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					root.utils.throwError(cb, "threadNotFound")
					return
				
				# Delete the cache for this thread
				memcached.del _mckey(o), (err) ->
					if err
						cb(err)
						return
					root.utils.mcFlush o.fid, (err) ->
						if err
							cb(err)
							return
						root.utils.sendMessage {action:"d", type:"t", fid: o.fid, tid: o.tid}, (err) ->
							if err
								cb(err)
								return
							cb(null, root.utils.respPrepare(resp.rows[0]))
							return
						return
					return
				return
			return
		return


	get: (o, cb) ->
		if root.utils.validate(o, ["tid","fid"], cb) is false
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
				text: "SELECT #{FIELDS} FROM t where fid = $1 AND id = $2"
				values: [
					o.fid
					o.tid
				]
				
			root.utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					root.utils.throwError(cb, "threadNotFound")
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
		if root.utils.validate(o, ["fid","a","p","ts","top"], cb) is false
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
						root.utils.storeProps(o.p)
					]
			else
				query =
					name: "insert thread without ts"
					text: "INSERT INTO t (fid, a, top, p) VALUES ($1, $2, $3, $4) RETURNING #{FIELDS};"
					values: [
						o.fid
						o.a
						o.top
						root.utils.storeProps(o.p)
					]


			root.utils.pgqry query, (err, resp) ->
				if err
					if err.detail?.indexOf("already exists") > -1
						root.utils.throwError(cb, "threadExists")
						return
					cb(err)
					return

				if resp.rowCount isnt 1
					root.utils.throwError(cb, "insertFailed")
					return
				root.utils.mcFlush o.fid, (err) ->
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
		if root.utils.validate(o, ["fid", "esk", "bylm", "forward"], cb) is false
			return
		o = root.utils.limitCheck(o, 50, 50)
		
		order = "ORDER BY id"
		orderitem = "id"
		if o.bylm
			order = "ORDER BY lm"
			orderitem = "lm"
		if o.forward
			order = order + " ASC"
			comparer = ">"
			esk = "#{orderitem} > ''"
		else
			order = order + " DESC"
			comparer = "<"
			esk = "#{orderitem} < 'Z'"

		if o.esk
			if o.bylm 
				esk = "lm #{comparer} $2"
			else
				esk = "id #{comparer} $2"

		query =
			name: "threads by forum #{o.bylm}#{o.forward}#{Boolean(o.esk)}"
			text: "SELECT #{FIELDS} FROM t WHERE fid = $1 AND #{esk} #{order} LIMIT 50"
			values: [
				o.fid
			]
		if o.esk
			query.values.push(esk)
		root.utils.pgqry query, (err, resp) =>
			if err
				cb(err)
				return
			if resp.rowCount > 0
				lastitem = _.last(resp.rows)
				lastitem.lek = lastitem.id

			cb(null, root.utils.threadQueryPrepare(resp.rows))
			return
		return


	update: (o, cb) ->
		if root.utils.validate(o, ["tid","fid","p","v","top"], cb) is false
			return
		@get o, (err, resp) ->
			if err
				cb(err)
				return
		
			o.p = root.utils.cleanProps(resp.p, o.p)
			if root.utils.validate(o, ["p"], cb) is false
				return

			# Nothing changed. Bail out and return the current item.
			if _.isEqual(resp.p, o.p) and _stickyUnchanged(resp, o)
				cb(null, resp)
				return

			if resp.v isnt o.v
				root.utils.throwError(cb, "invalidVersion")
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
			root.utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				if resp.rowCount is 0
					root.utils.throwError(cb, "invalidVersion")
					return

				root.utils.mcFlush o.fid, (err) ->
					if err
						cb(err)
						return
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
	data = root.utils.threadPrepare(data)
	if data.id
		memcached.set _mckey(data), data, 86400, ->
	cb(null, data)
	return


_mckey = (o) ->
	return "#{root.MCPREFIX}#{o.id}"

module.exports = new Threads()

users = require "../communities/users"
messages = require "./messages"
