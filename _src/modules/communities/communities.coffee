_ = require "lodash"

FIELDS = "id, v, p"

class Communities
	# Get all communities of a ThirdPartyId
	#
	# Parameters:
	# 
	# * `tpid` (String)
	#
	bytpid: (o, cb) ->
		if root.utils.validate(o, ["tpid"], cb) is false
			return
		query = 
			name: "communities by tpid"
			text: "SELECT #{FIELDS} FROM c WHERE pid = $1"
			values: [
				o.tpid
			]
		utils.pgqry query, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.communityQueryPrepare(resp.rows))
			return
		return


	# Delete a community.
	#
	delete: (o, cb) ->
		if root.utils.validate(o, ["cid"], cb) is false
			return
		@get o, (err, resp) ->
			if err
				cb(err)
				return
			query =
				name: "delete community"
				text: "DELETE FROM c WHERE id = $1 RETURNING #{FIELDS};"
				values: [o.cid]
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				# Delete the cache for this community
				memcached.del _mckey(o), (err) -> 
					if err
						cb(err)
						return
					root.utils.sendMessage {action:"d", type:"c", cid: o.cid}, (err) ->
						if err
							cb(err)
							return
						cb(null, utils.respPrepare(resp.rows[0]))
						return
					return
				return
			return
		return


	get: (o, cb) ->
		if root.utils.validate(o, ["cid"], cb) is false
			return
		memcached.get _mckey(o), (err, resp) ->
			if err
				cb(err)
				return
			if resp isnt undefined
				# Cache hit
				cb(null, resp)
				return
			# Get the item from DB
			query = 
				name: "get community by cid"
				text: "SELECT #{FIELDS} FROM c WHERE id = $1"
				values: [
					o.cid
				]
			utils.pgqry query, (err, data) ->
				if err
					cb(err)
					return
				# Make sure the supplied pid is the same
				if not data.rows.length
					utils.throwError(cb, "communityNotFound")
					return
				_cacheAndReturn(data.rows[0], cb)
				return
			return
		return 


	# Insert a new community
	#
	# Parameters:
	#
	# * `tpid` (String) Third Party Id
	# * `p` (Object) Properties.
	#
	insert: (o, cb) ->
		that = @
		if root.utils.validate(o, ["tpid","p"], cb) is false
			return
		query =
			name: "insert community"
			text: "INSERT INTO c (pid, p) VALUES ($1, $2) RETURNING #{FIELDS};"
			values: [
				o.tpid
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


	# Update a community
	#
	# Parameters:
	#
	# * `cid` (String) The id of the community
	# * `p` (Object) Properties.
	# * `v` (Number) The current version number must be supplied for a successful update.
	#
	update: (o, cb) ->
		that = @
		if root.utils.validate(o, ["cid","p","v"], cb) is false
			return
		@get o, (err, data) ->
			if err
				cb(err)
				return
			if data.v isnt o.v
				utils.throwError(cb, "invalidVersion")
				return

			o.p = utils.cleanProps(data.p, o.p)
			if root.utils.validate(o, ["p"], cb) is false
				return

			# Nothing changed. Bail out and return the current item.
			if _.isEqual(data.p, o.p)
				cb(null, data)
				return
			query =
				name: "update community"
				text: "UPDATE c SET v = base36_timestamp(), p = $1 WHERE id = $2 and v = $3 RETURNING #{FIELDS}"
				values: [
					JSON.stringify(o.p)
					o.cid
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
	memcached.set _mckey({cid: data.id}), data, 86400, ->
	cb(null, data)
	return

_mckey = (o) ->
	return "#{root.MCPREFIX}#{o.cid}"

module.exports = new Communities()
