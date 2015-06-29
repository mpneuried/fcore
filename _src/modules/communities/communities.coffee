_ = require "lodash"

mcprefix = "fc_c"

TABLENAME = "fcore"
TABLENAME_FORUM = "fcore_f"

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
		params =
			TableName: TABLENAME
			KeyConditions:
				pid:
					ComparisonOperator: "EQ"
					AttributeValueList: [
						S: o.tpid
					]
		utils.multiquery params, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.communityQueryPrepare(resp))
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
			
			# Not cached
			params = 
				TableName: TABLENAME
				Key:
					pid:
						S: o.cid.split("_")[0]
					id:
						S: o.cid.split("_")[1]
			dynamodb.getItem params, (err, data) ->
				if err
					cb(err)
					return
				if _.isEmpty(data)
					utils.throwError(cb, "communityNotFound")
					return
				_cacheAndReturn(data, cb)
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
		if utils.validate(o, ["tpid","p"], cb) is false
			return
		# Get a new id
		utils.getTimestamp (err, ts) ->
			if err
				cb(err)
				return
			params =
				TableName: TABLENAME
				Item:
					pid:
						S: o.tpid
					id:
						S: ts
					p:
						S: utils.storeProps(o.p)
					v:
						S: ts
				Expected:
					pid:
						ComparisonOperator: "NULL"
					id:
						ComparisonOperator: "NULL"
			dynamodb.putItem params, (err, data) ->
				if err
					cb(err)
					return
				# Saved the item
				_cacheAndReturn(params, cb)
				return
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
		if utils.validate(o, ["cid","p","v"], cb) is false
			return
		@get o, (err, resp) ->
			if err
				cb(err)
				return

			if not resp.id?
				cb(null, {})
				return
			o.p = utils.cleanProps(resp.p, o.p)
			if utils.validate(o, ["p"], cb) is false
				return

			# Nothing changed. Bail out and return the current item.
			if _.isEqual(resp.p, o.p)
				cb(null, resp)
				return

			utils.getTimestamp (err, ts) ->
				if err
					cb(err)
					return
				params =
					TableName: TABLENAME
					Key:
						pid:
							S: o.cid.split("_")[0]
						id:
							S: o.cid.split("_")[1]
					AttributeUpdates:
						p:
							Value:
								S: JSON.stringify(o.p)
							Action: "PUT"
						v:
							Value:
								S: ts
							Action: "PUT"
					Expected:
						v:
							ComparisonOperator: "EQ"
							AttributeValueList: [{"S": o.v}]
					ReturnValues: "ALL_NEW"

				dynamodb.updateItem params, (err, data) ->
					if err
						if err.message is "The conditional request failed"
							utils.throwError(cb, "invalidVersion")
							return
						cb(err)
						return
					# Saved the item
					_cacheAndReturn(data, cb)
					return
				return
			return
		return


_cacheAndReturn = (data, cb) ->
	data = utils.dynamoConvertItem(data)
	key = "#{mcprefix}#{data.pid}_#{data.id}"
	data = utils.communityPrepare(data)
	memcached.set key, data, 86400, ->
	cb(null, data)
	return

module.exports = new Communities()
