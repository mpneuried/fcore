mcprefix = "fc_m"

_ = require "lodash"
users = null
threads = null

TABLENAME = "fcore"

class Messages
	delete: (o, cb) ->
		# TODO: Make sure to update the `la` key of a thread if the last message is deleted.
		if utils.validate(o, ["fid","tid","mid"], cb) is false
			return
		params =
			TableName: TABLENAME
			Key:
				pid:
					S: o.tid
				id:
					S: o.mid
			ReturnValues: "ALL_OLD"
		# Delete this message
		dynamodb.deleteItem params, (err, msg) ->
			if err
				utils.throwError(cb, "messageNotFound")
				return
			# Remove Author
			msg = utils.dynamoConvertItem(msg)
			
			users.removeAuthor msg, (err, resp) ->
				if err
					cb(err)
					return
				# Delete Memcached Entry
				memcached.del "#{mcprefix}#{o.mid}", ->
				if not o.noupdate
					# Update the thread counter
					threads.updateCounter _.extend(o, {tm: -1}), (err, resp) ->
						if err
							cb(err)
							return
						cb(null, {thread:resp, message: utils.messagePrepare(msg)})
						return
				else
					cb(null, {})
					
				return
			return
		return

	get: (o, cb) ->
		if utils.validate(o, ["fid","tid","mid"], cb) is false
			return
		key = "#{mcprefix}#{o.mid}"
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
						S: o.tid
					id:
						S: o.mid
			dynamodb.getItem params, (err, data) ->
				if err
					cb(err)
					return
				if _.isEmpty(data)
					utils.throwError(cb, "messageNotFound")
					return
				_cacheAndReturn(data, cb)
				return
			return
		return 


	# Insert a new mesage
	#
	# Parameters:
	#
	# * `fid` (String) Forum Id
	# * `tid` (String) Thread Id.
	# * `p` (Object) Properties
	#
	insert: (o, cb) ->
		if utils.validate(o, ["fid","a","p","tid","ts"], cb) is false
			return
		users.verify o, (err, user) ->
			if err
				cb(err)
				return
			# Save the message
			utils.getTimestamp (err, ts) ->
				if err
					cb(err)
					return
				ts = o.ts or ts
				o.mid = "M" + ts
				threads.get o, (err, resp) ->
					if err
						cb(err)
						return
					
					
					params =
						TableName: TABLENAME
						Item:
							pid:
								S: resp.id
							id:
								S: o.mid
							a:
								S: o.a
							p:
								S: utils.storeProps(o.p)
							v:
								S: ts
							fid:
								S: o.fid
							cid:
								S: user.cid
						Expected:
							pid:
								ComparisonOperator: "NULL"
							id:
								ComparisonOperator: "NULL"
					dynamodb.putItem params, (err, data) ->
						if err
							if err.message is "The conditional request failed"
								# Message insert failed. Deduct the message from thread `tm` again.
								threads.updateCounter _.extend(o, {tm: -1}), (err, resp) ->
									utils.throwError(cb, "messageExists")
									return
								return
							cb(err)
							return

						threads.updateCounter _.extend(o, {tm: 1}), (err, resp) ->
							if err
								if err.message is "The conditional request failed"
									utils.throwError(cb, "threadNotFound")
									return
								cb(err)
								return
							# We return the thread and the message
							result = 
								thread: resp




							o.tid = result.thread.id
							o.cid = user.cid
							o.id = user.id
							users.setAuthor o, (err, resp) ->
								if err
									cb(err)
									return

								result.message = params

								_cacheAndReturn params, (err, resp) ->
									if err
										cb(err)
										return
									result.message = resp
									# For an insert we return the message AND the thread.
									cb(null, result)
									return
								return
							return
						return
					return
				return
			return
		return


	# Messages by thread
	#
	# Parameters:
	# 
	# * `fid` (String) Forum Id
	# * `tid` (String) Thread Id.
	# * `forward` (String) Scan direction. Default: true
	# * `esk` (String) Message Id (as Exclusive Start Key)
	# * `limit` (String) Number of messages to return (Default: 50)
	#
	messagesByThread: (o, cb) ->
		o.limit = parseInt(o.limit or 50, 10)
		if o.limit > 50
			o.limit = 50

		if utils.validate(o, ["fid","tid"], cb) is false
			return
		params = 
			TableName: TABLENAME
			Limit: o.limit
			ConsistentRead: o.limit is 1
			AttributesToGet: ["id", "a", "b", "v", "la", "p"]
			KeyConditions:
				pid:
					ComparisonOperator: "EQ"
					AttributeValueList: [
						S: o.tid
					]
			QueryFilter:
				fid:
					ComparisonOperator: "EQ"
					AttributeValueList: [
						S: o.fid
					]
			ScanIndexForward: o.forward is "true"
		if o.esk
			params.ExclusiveStartKey =
				"id":
					S: o.esk
				"pid":
					S: o.tid
		utils.singlequery params, (err, resp) ->
			if err
				cb(err)
				return
			cb(null, utils.messageQueryPrepare(resp))
			return
		return

	# Update a message
	update: (o, cb) ->
		if utils.validate(o, ["fid","tid","mid","a","p","v"], cb) is false
			return
		# Make sure this user exists
		users.verify o, (err, resp) =>
			if err
				cb(err)
				return
			@get o, (err, resp) ->
				if err
					cb(err)
					return
				o.p = utils.cleanProps(resp.p, o.p)
				if utils.validate(o, ["p"], cb) is false
					return

				# Nothing changed. Bail out and return the current item.
				if _.isEqual(resp.p, o.p) and resp.a is o.a
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
								S: o.tid
							id:
								S: o.mid
						AttributeUpdates:
							p:
								Value:
									S: JSON.stringify(o.p)
								Action: "PUT"
							v:
								Value:
									S: ts
								Action: "PUT"
							la:
								Value:
									S: o.a
								Action: "PUT"
						Expected:
							v:
								ComparisonOperator: "EQ"
								AttributeValueList: [{"S": o.v}]
						ReturnValues: "ALL_NEW"
						
					if resp.a.toLowerCase() is o.a.toLowerCase()
						params.AttributeUpdates.la = 
							Action: "DELETE"

					dynamodb.updateItem params, (err, data) ->
						if err
							if err.message is "The conditional request failed"
								utils.throwError(cb, "invalidVersion")
								return
							cb(err)
							return
						threads.touch o, (err, resp) ->
							if err
								cb(err)
								return
							_cacheAndReturn(data, cb)
							return
						return
					return	
				return
			return
		return


_cacheAndReturn = (msg, cb) ->
	msg = utils.dynamoConvertItem(msg)
	key = "#{mcprefix}#{msg.id}"
	msg = utils.messagePrepare(msg)
	memcached.set key, msg, 86400, ->
	cb(null, msg)
	return


module.exports = new Messages()

users = require "../communities/users"
threads = require "./threads"
