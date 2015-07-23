_ = require "lodash"

mcprefix = "fc_c"

FIELDS = "id, v, p"

class Communities
	# Get all communities of a ThirdPartyId
	#
	# Parameters:
	# 
	# * `tpid` (String)
	#
	bytpid: (o, cb) ->
		if utils.validate(o, ["tpid"], cb) is false
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
	# Only allowed when no forums are found.
	#
	delete: (o, cb) ->
		if utils.validate(o, ["cid"], cb) is false
			return
		params =
			TableName: TABLENAME_FORUM
			IndexName: "cid-index"
			Limit: 1
			AttributesToGet: ["id"]
			KeyConditions:
				cid:
					ComparisonOperator: "EQ"
					AttributeValueList: [
						S: o.cid
					]
		utils.singlequery params, (err, resp) =>
			if err
				cb(err)
				return
			if resp.length
				utils.throwError(cb, "communityHasForums")
				return
			params =
				TableName: TABLENAME
				Key:
					pid:
						S: o.cid.split("_")[0]
					id:
						S: o.cid.split("_")[1]
				ReturnValues: "ALL_OLD"
			dynamodb.deleteItem params, (err, resp) ->
				if err
					cb(err)
					return
				if not resp.Attributes?
					utils.throwError(cb, "communityNotFound")
					return
				resp = utils.dynamoConvertItem(resp)
				
				console.log "COMMUNITY DELETED", resp
				# An item was found and deleted.
				#
				# There might be users. Delete all of them.
				rsmq.sendMessage {qname: QUEUENAME, message: JSON.stringify({action: "dc", cid: o.cid})}, (err, resp) ->
					if err
						console.error( err ) 
					console.log "RSMQ DELETE COMMUNITY", resp
					return
				# Delete the cache for this community
				memcached.del "#{mcprefix}#{o.cid}", (err) -> 
					if err
						cb(err)
						return
					cb(null, utils.communityPrepare(resp))
					return
				return
			return
		return


	get: (o, cb) ->
		if utils.validate(o, ["cid"], cb) is false
			return
		key = "#{mcprefix}#{o.cid}"
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
		if utils.validate(o, ["tpid","p"], cb) is false
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
		if utils.validate(o, ["cid","p","v"], cb) is false
			return
		@get o, (err, data) ->
			if err
				cb(err)
				return
			if data.v isnt o.v
				utils.throwError(cb, "invalidVersion")
				return

			o.p = utils.cleanProps(data.p, o.p)
			if utils.validate(o, ["p"], cb) is false
				return

			# Nothing changed. Bail out and return the current item.
			if _.isEqual(data.p, o.p)
				cb(null, data)
				return
			query =
				name: "update community"
				text: "UPDATE c SET v = get_unique_ts(), p = $1 WHERE id = $2 and v = $3 RETURNING #{FIELDS}"
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
	key = "#{mcprefix}#{data.cid}"
	data = utils.respPrepare(data)
	memcached.set key, data, 86400, ->
	cb(null, data)
	return


module.exports = new Communities()
