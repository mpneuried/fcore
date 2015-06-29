_ = require "lodash"
async = require "async"
forums = null
users = null
messages = null
TABLENAME = "fcore"

mcprefix = "fc_t"


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

	# Delete a thread
	# 
	# * Delete the thread
	# * Update Forum Counters
	# * Queue this thread for deletion
	#
	delete: (o, cb) ->
		if utils.validate(o, ["tid","fid"], cb) is false
			return
		params =
			TableName: TABLENAME
			Key:
				pid:
					S: o.fid
				id:
					S: o.tid
			ReturnValues: "ALL_OLD"
		dynamodb.deleteItem params, (err, resp) ->
			if err
				cb(err)
				return
			if not resp.Attributes?
				utils.throwError(cb, "threadNotFound")
				return
			

			resp = utils.dynamoConvertItem(resp)
			
			# An item was found and deleted.
			#
			# There are messages in the thread. Delete them too.

			if resp.tm > 0
				rsmq.sendMessage {qname: QUEUENAME, message: JSON.stringify({action: "dt", tid: o.tid, fid: o.fid})}, (err) ->
					if err
						cb(err)
					return
			# Delete the cache for this thread
			memcached.del "#{mcprefix}#{o.tid}"
			
			if o.noupdate
				# No need to update the forum counters
				cb(null, resp)
				return

			# Update the forum
			forums.updateCounter {tm: -resp.tm, tt: -1, fid: resp.pid}, (err, respC) ->
				if err
					cb( err )
					return
					
				cb(null, utils.threadPrepare(resp))
				return
			return
		return

	get: (o, cb) ->
		if utils.validate(o, ["tid","fid"], cb) is false
			return
		key = "#{mcprefix}#{o.tid}"
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
						S: o.fid
					id:
						S: o.tid
			dynamodb.getItem params, (err, data) ->
				if err
					cb(err)
					return
				if _.isEmpty(data)
					utils.throwError(cb, "threadNotFound")
					return
				_cacheAndReturn(data, cb)
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
		if utils.validate(o, ["fid","a","p","ts"], cb) is false
			return
		# We verify the user for this forums community and return his name and community id.
		users.verify o, (err, user) ->
			if err
				cb(err)
				return
			utils.getTimestamp (err, ts) ->
				if err
					cb(err)
					return
				ts = o.ts or ts
				params =
					TableName: TABLENAME
					Item:
						pid:
							S: o.fid
						id:
							S: "T" + ts
						p:
							S: utils.storeProps(o.p)
						a:
							S: o.a
						v:
							S: o.ts or ts
						tm:
							N: "0"
					Expected:
						pid:
							ComparisonOperator: "NULL"
						id:
							ComparisonOperator: "NULL"
				
				dynamodb.putItem params, (err, data) ->
					if err
						if err.message is "The conditional request failed"
							utils.throwError(cb, "threadExists")
							return
						cb(err)
						return
					o.tm = 0
					o.tt = 1
					forums.updateCounter o, (err, resp) ->
						if err
							cb(err)
							return
						_cacheAndReturn(params, cb)
						return
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
		if utils.validate(o, ["fid"], cb) is false
			return
		params =
			TableName: TABLENAME
			Limit: 50
			AttributesToGet: ["id", "a", "t", "v", "la", "lm", "tm", "p"]
			KeyConditions:
				pid:
					ComparisonOperator: "EQ"
					AttributeValueList: [
						S: o.fid
					]
			ScanIndexForward: o.forward is "true"
		if o.bylm is "true"
			params.IndexName = "lastmsgdate"
		if o.esk
			params.ExclusiveStartKey =
				"pid":
					S: o.fid
			if o.bylm is "true"
				[eskid,esklm] = o.esk.split(":")
				params.ExclusiveStartKey.id =
					S: eskid
				params.ExclusiveStartKey.lm =
					S: esklm
			else
				params.ExclusiveStartKey.id =
					S: o.esk
		
		utils.singlequery params, (err, resp) =>
			if err
				cb(err)
				return
			if resp.length
				lastitem = _.last(resp)
				lastitem.lek = lastitem.id
				if o.bylm is "true"
					lastitem.lek = lastitem.lek + ":#{lastitem.lm}"
				

			cb(null, utils.threadQueryPrepare(resp))
			return
		return


	# Touch the ts of a thread
	# and flush the cache. Called by
	#
	# * messages.update
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
					pid:
						S: o.fid
					id:
						S: o.tid
				AttributeUpdates:
					v:
						Value:
							S: ts
				ReturnValues: "ALL_NEW"
				Expected:
					pid:
						ComparisonOperator: "NOT_NULL"
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

	# Update a thread
	#
	update: (o, cb) ->
		if utils.validate(o, ["tid","fid","p","v"], cb) is false
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
						pid:
							S: o.fid
						id:
							S: o.tid
					AttributeUpdates:
						p:
							Value:
								S: JSON.stringify(o.p)
							Action: "PUT"
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
					forums.touch o, (err, resp) ->
						if err
							cb(err)
						_cacheAndReturn(data, cb)
						return
					return
				return
			return
		return


	# This will be called by
	#
	# * messages.delete
	# * messages.insert
	#
	updateCounter: (o, cb) ->
		if utils.validate(o, ["fid","tid","tm"], cb) is false
			return
		# Get the last Author (will not be there on delete)
		@_lastAuthor o, (err, lastMsg) ->
			utils.getTimestamp (err, ts) ->
				if err
					cb(err)
					return
				params =
					TableName: TABLENAME
					Key:
						pid:
							S: o.fid
						id:
							S: o.tid
					AttributeUpdates:
						tm:
							Action: "ADD"
							Value:
								N: "#{o.tm}"
						v:
							Value:
								S: ts
						la:
							Value:
								S: lastMsg.a
					ReturnValues: "ALL_NEW"
					Expected:
						pid:
							ComparisonOperator: "NOT_NULL"
						id:
							ComparisonOperator: "NOT_NULL"
				# Message was deleted 
				if o.tm is -1
					# This was the last msg in the thread.
					# Delete `la` and the `lm` key with the last message date.
					if lastMsg.a is ""
						params.AttributeUpdates.lm =
							Action: "DELETE"
						params.AttributeUpdates.la =
							Action: "DELETE"
					# There are other messages.
					# Update `la` and `lm` to the data of the latest msg.
					else
						params.AttributeUpdates.lm =
							Action: "PUT"
							Value:
								S: lastMsg.id
						params.AttributeUpdates.la =
							Action: "PUT"
							Value:
								S: lastMsg.a
				# Message was inserted
				else
					params.AttributeUpdates.lm =
						Action: "PUT"
						Value:
							S: o.mid
					params.AttributeUpdates.la =
						Action: "PUT"
						Value:
							S: o.a
				dynamodb.updateItem params, (err, data) ->
					if err
						cb(err)
						return
					o.tt = 0
					thread = utils.dynamoConvertItem(data)
					# Update the forum
					forums.updateCounter o, (err, fdata) ->
						if err
							cb(err)
							return
						# Cache the new thread data
						else
							_cacheAndReturn(data, cb)
						return
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


_cacheAndReturn = (data, cb) ->
	data = utils.dynamoConvertItem(data)
	key = "#{mcprefix}#{data.id}"
	data = utils.threadPrepare(data)
	if data.id
		memcached.set key, data, 86400, ->
	cb(null, data)
	return



module.exports = new Threads()

forums = require "./forums"
users = require "../communities/users"
messages = require "./messages"
