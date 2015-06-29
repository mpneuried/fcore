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
		params =
			TableName: TABLENAME
			IndexName: "cid-index"
			KeyConditions:
				cid:
					ComparisonOperator: "EQ"
					AttributeValueList: [
						S: o.cid
					]
		utils.multiquery params, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.forumQueryPrepare(resp))
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
		params =
			TableName: TABLENAME
			IndexName: "tpid-index"
			KeyConditions:
				tpid:
					ComparisonOperator: "EQ"
					AttributeValueList: [
						S: o.tpid
					]
		utils.multiquery params, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.forumQueryPrepare(resp))
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
		params =
			TableName: TABLENAME
			Key:
				id:
					S: o.fid
			ReturnValues: "ALL_OLD"
		dynamodb.deleteItem params, (err, resp) ->
			if err
				cb(err)
				return
			if not resp.Attributes?
				utils.throwError(cb, "forumNotFound")
				return

			resp = utils.dynamoConvertItem(resp)
			# An item was found and deleted.
			#
			# There are threads in the forum. Take care of them.
			if resp.tt > 0
				rsmq.sendMessage {qname: QUEUENAME, message: JSON.stringify({action: "df", fid: o.fid})}, (err, resp) ->
					if err
						console.error( err ) 
					console.log "RSMQ DELETE FORUM", resp
					return
			# Delete the cache for this forum
			memcached.del "#{mcprefix}#{o.fid}", (err) -> 
				if err
					cb(err)
					return
				cb(null, utils.forumPrepare(resp))
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
			# Not cached
			params =
				TableName: TABLENAME
				Key:
					id:
						S: o.fid
			dynamodb.getItem params, (err, data) ->
				if err
					cb(err)
					return
				if _.isEmpty(data)
					utils.throwError(cb, "forumNotFound")
					return
				_cacheAndReturn(data, cb)
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
		if utils.validate(o, ["p","cid","ts"], cb) is false
			return

		# Make sure this community exists
		communities.get {cid: o.cid}, (err, resp) ->
			if err
				cb(err)
				return
			if not resp.id?
				cb(null,{})
				return
			# Get a new id
			utils.getTimestamp (err, ts) ->
				if err
					cb(err)
					return
				ts = o.ts or ts
				params =
					TableName: TABLENAME
					Item:
						id:
							S: "F" + ts
						p:
							S: utils.storeProps(o.p)
						cid:
							S: o.cid
						tpid:
							S: o.cid.split("_")[0] # We derive the tpid from the community id.
						v:
							S: ts
						tm:
							N: "0"
						tt:
							N: "0"
					Expected:
						id:
							ComparisonOperator: "NULL"
						
				dynamodb.putItem params, (err, data) ->
					if err
						cb(err)
						return
					_cacheAndReturn(params, cb)
					return
				return
			return
		return


	# Touch the ts of a forum
	# and flush the cache. Called by
	#
	# * threads.update
	#
	touch: (o, cb) ->
		# No need to validate. Should not be called by itself anyway.
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
						id:
							S: o.fid
					AttributeUpdates:
						p:
							Value:
								S: JSON.stringify(o.p)
						v:
							Value:
								S: ts
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
					#
					# Store the item in cache
					_cacheAndReturn(data, cb)
					return
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
	data = utils.dynamoConvertItem(data)
	key = "#{mcprefix}#{data.id}"
	data = utils.forumPrepare(data)
	if data.id
		memcached.set key, data, 86400, ->
	cb(null, data)
	return


module.exports = new Forums()

communities = require "../communities/communities"
threads = require "./threads"
