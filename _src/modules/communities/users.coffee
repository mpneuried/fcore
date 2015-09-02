_ = require "lodash"
mcprefix = "fc_u"

forums = null
communities = null

FIELDS = "id, cid, c, v, p, extid"

class Users

	delete: (o, cb) ->
		if utils.validate(o, ["id", "cid"], cb) is false
			return
		@get o, (err, resp) ->
			if err
				cb(err)
				return
			query =
				name: "delete user"
				text: "DELETE FROM u WHERE cid = $1 AND id = $2 RETURNING #{FIELDS};"
				values: [o.cid, o.id]
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				# Delete the cache for this user
				memcached.del _mckey(o), (err) -> 
					if err
						cb(err)
						return
					cb(null, utils.respPrepare(resp.rows[0]))
					return
				return
			return
		return


	get: (o, cb) ->
		if utils.validate(o, ["id","cid"], cb) is false
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
				name: "get user by id"
				text: "SELECT #{FIELDS} FROM u WHERE cid = $1 and id = $2"
				values: [
					o.cid
					o.id
				]
			utils.pgqry query, (err, resp) ->
				if err
					cb(err)
					return
				# Make sure the supplied pid is the same
				if not resp.rows.length 
					utils.throwError(cb, "userNotFound")
					return

				_cacheAndReturn(resp.rows[0], cb)
				return
			return
		return 


	getUserIdFromExtId: (o, cb) ->
		if utils.validate(o, ["extid", "cid"], cb) is false
			return
		key = "#{mcprefix}#{o.cid}_extid_#{o.extid}"
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
				text: "SELECT #{FIELDS} FROM u WHERE cid = $2 AND extid = $1"
				values: [
					o.cid
					o.extid
				]
			utils.pgqry query, (err, data) ->
				if err
					cb(err)
					return
				if not data.rows.length 
					utils.throwError(cb, "externalIdNotFound")
					return

				_cacheAndReturn(data.rows[0], cb)
				return
			return
		return


	# Insert a new user
	#
	# Parameters:
	#
	# * `id` (String) UserID (optional) - will be autogenerated
	# * `p` (Object) Properties.
	#
	insert: (o, cb) ->
		that = @
		# if `id` is not supplied we generate an id.
		_preCheckUserId o, (err, o) =>
			if err
				cb(err)
				return
			keystocheck = ["cid","p","id"]
			if o.extid?
				keystocheck.push("extid")
			if utils.validate(o, keystocheck, cb) is false
				return
			@preCheckUserExtId o, (err, o) ->
				if err
					cb(err)
					return
				# Make sure this community exists
				communities.get {cid:o.cid}, (err, resp) ->
					if err
						cb(err)
						return

					query =
						name: "insert user"
						text: "INSERT INTO u (id, cid, p, extid) VALUES ($1, $2, $3, $4) RETURNING #{FIELDS};"
						values: [
							o.id,
							o.cid
							utils.storeProps(o.p)
							o.extid or null
						]
					utils.pgqry query, (err, resp) ->
						if err
							if err.detail?.indexOf("already exists") > -1
								utils.throwError(cb, "userExists")
								return
							cb(err)
							return
						if resp.rowCount isnt 1
							utils.throwError(cb, "insertFailed")
							return
						_cacheAndReturn(resp.rows[0], cb)
						return
					return
				return
			return
		return

	# Messages by User
	#
	# Returns a list of all messages written by the user
	#
	# Will return the newest `limit` Messages.  
	# Use the `esk` URL Parameter with the last id of the result to get the next messages.
	#
	# Parameters:
	#
	# * `id` (String) User Id
	# * `cid` (String) Community Id
	# * `limit` (Number) Default: 10 The max amount of messages to retrieve. Maximum: 50
	#
	# URL Parameters:
	#
	# * `esk` (String) Exclusive Start Key: 
	#
	messagesByUser: (o, cb) ->
		if utils.validate(o, ["cid", "id", "esk"], cb) is false
			return
		o = utils.limitCheck(o, 10, 50)
		esk = ""
		if o.esk
			esk = "AND mid < $4"
		query =
			name: "msgs by user#{Boolean(esk)}"
			text: "SELECT mid, fid, tid, (SELECT p FROM t WHERE fid = authors.fid and id = authors.tid) AS t_p FROM authors WHERE cid = $1 AND uid = $2 #{esk} ORDER BY mid DESC LIMIT $3"
			values: [
				o.cid
				o.id
				o.limit
			]
		if o.esk
			query.values.push(o.esk)
		utils.pgqry query, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.userQueryPrepare(resp.rows))
			return
		return


	# Messagecount
	#
	# Returns the number of messages a single user has created in a community
	#
	msgcount: (o, cb) ->
		if utils.validate(o, ["cid", "id"], cb) is false
			return
		query =
			name: "msgcount"
			text: "SELECT COUNT(*) AS msgcount FROM authors WHERE cid = $1 AND uid = $2"
			values: [
				o.cid
				o.id
			]
		utils.pgqry query, (err, resp) ->
			if err
				cb(err)
				return
			o = resp.rows[0]
			o.msgcount = parseInt(o.msgcount, 10)
			cb(null, o)
			return
		return

	# This will check an extid for a user object
	# If it does not exist it will return the object
	# If it does exist alrdy it throws an error
	#
	preCheckUserExtId: (o, cb) ->
		if not o.extid?
			cb(null, o)
			return
		@getUserIdFromExtId o, (err, resp) ->
			if err
				if err.name is "externalIdNotFound"
					cb(null, o)
				else
					cb(err)
				return
			utils.throwError(cb, "externalIdNotUnique")		
			return
		return


	# Update a user
	#
	# Parameters:
	#
	# * `id` (String) User Id
	# * `cid` (String) Community Id
	# * `p` (Object) Properties. Must include at least a `tpid` (String) key.
	# * `v` (Number) The current version number must be supplied for a successful update.
	#
	update: (o, cb) ->
		keystocheck = ["cid","id","p","v"]
		if o.extid?
			keystocheck.push("extid")
		if utils.validate(o, keystocheck, cb) is false
			return
		@get o, (err, user) =>
			if err
				cb(err)
				return
				
			if user.v isnt o.v
				utils.throwError(cb, "invalidVersion")
				return

			o.p = utils.cleanProps(user.p, o.p)
			if utils.validate(o, ["p"], cb) is false
				return

			# Nothing changed. Bail out and return the current item.
			if _.isEqual(user.p, o.p) and o.extid is user.extid
				cb(null, user)
				return

			# We need to call a check for extid and see if 
			#
			# * The extid changed
			# * If it changed if it is valid and does not exist yet for another user
			#

			@preCheckUserExtId o, (err, o) ->
				if err
					cb(err)
					return

				# Make sure this community exists
				communities.get {cid: o.cid}, (err, resp) ->
					if err
						cb(err)
						return
					
					query =
						name: "user update with extid"
						text: "UPDATE u SET p = $1, v = base36_timestamp(), extid = $2 WHERE cid = $3 and id = $4 and v = $5 RETURNING #{FIELDS};"
						values: [
							JSON.stringify(o.p)
							o.extid
							o.cid
							o.id
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
			return
		return

	
	# Get the Users of a community
	#
	# Parameters:
	# 
    # + cid (required, string, `123456_hxfu1234`) ... The id of the community.
    # + type (optional, string, `id`) ... Either `id`, `p` or `all` to return just the id, properties or all. Default: `id`
    # + esk (optional, string, `someusername`) ... Exclusive Start Key
    # + limit (optional, number, `10`) ... The amount of users to return. Default: 100 (min: 1, max: 500)
	#
	users: (o, cb) ->
		tovalidate = ["cid","type"]
		o.type = o.type or "id"
		# Turn the `esk` key into an user id
		o.id = o.esk or ""
		if o.id
			tovalidate.push("id")
		if utils.validate(o, tovalidate, cb) is false
			return
		o = utils.limitCheck(o, 100, 500)
		query =
			name: "users of community #{o.type.join(",")}"
			text: "SELECT #{o.type.join(",")} FROM u WHERE cid = $1 and id > $2 ORDER BY ID LIMIT $3"
			values: [
				o.cid
				o.id
				o.limit
			]
		utils.pgqry query, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.userQueryPrepare(resp.rows))
			return
		return


	verify: (o, cb) ->
		# If there is not user to check just return
		if not o.a?
			cb(null, {})
			return
		if utils.validate(o, ["fid", "a"], cb) is false
			return
		forums.get o, (err, forum) =>
			if err
				cb(err)
				return
			# The forum exists. Now check the user
			o.id = o.a
			o.cid = forum.cid
			@get o, cb
			return
		return


_cacheAndReturn = (data, cb) ->
	data = utils.respPrepare(data)
	memcached.set _mckey(data), data, 86400, ->
	cb(null, data)
	return


_mckey = (o) ->
	return "#{root.MCPREFIX}#{o.cid}_#{o.id}"

_preCheckUserId = (o, cb) ->
	if o.id?
		cb(null, o)
		return
	# generate a new userid
	o.id = "user#{utils.getRandomInt(12345678,99999999)}"
	cb(null, o)
	return


module.exports = new Users()

forums = require "../forums/forums"
communities = require "./communities"