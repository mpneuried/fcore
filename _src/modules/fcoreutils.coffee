_ = require "lodash"

LASTTIMESTAMP = 0

class Utils

	cleanProps: (current_props, new_props) ->
		nullkeys = for key of new_props when new_props[key] is null
			key
		# OK ready to set some data
		o = _.extend(_.clone(current_props), new_props)
		return _.omit(o, nullkeys)

	
	communityQueryPrepare: (items) ->
		for e in items
			@communityPrepare(e)
		
	
	# Merge the hash and range key into a single `id` field
	communityPrepare: (item) ->
		if not item.id or not item.pid
			return {}
		item.id = "#{item.pid}_#{item.id}"
		item.p = JSON.parse(item.p)
		return _.omit(item, "pid")


	# Convert a DynamoDB Item to a normal JS object.
	dynamoConvertItem: (item) ->
		o = {}
		if not item.Item? and not item.Attributes?
			return o
		item = if item.Item? then item.Item else item.Attributes
		for key of item
			if item[key].S?
				o[key] = item[key].S
			else if item[key].N?
				o[key] = Number(item[key].N)
		return o


	forumQueryPrepare: (items) ->
		for e in items
			@forumPrepare(e)

	
	forumPrepare: (item)->
		if not item.id
			return {}
		item.p = JSON.parse(item.p)
		return _.omit(item, "tpid")
	
	getRandomInt: (min, max) ->
		return Math.floor(Math.random() * (max - min)) + min

	# Return a unique timestamp string
	#
	# A timestamp is converted with `.toString(36)`
	#
	getTimestamp: (cb) ->
		ts = new Date().getTime()
		if ts is LASTTIMESTAMP
			LASTTIMESTAMP = LASTTIMESTAMP + 1
		else
			LASTTIMESTAMP = ts
		cb(null, LASTTIMESTAMP.toString(36))
		return


	isStringNumberBooleanNull: (item) ->
		if not _.isString(item) and not _.isNumber(item) and not _.isBoolean(item) and not _.isNull(item)
			return false
		return true


	isArrayStringNumberBooleanNull: (item) ->
		if not _.isString(item) and not _.isNumber(item) and not _.isBoolean(item) and not _.isNull(item) and not _.isArray(item)
			return false
		return true


	messageQueryPrepare: (items) ->
		for e in items
			@messagePrepare(e)


	messagePrepare: (item)->
		if not item.id
			return {}
		if item.p?
			item.p = JSON.parse(item.p)
		return _.omit(item, ["pid","fid","cid"])
	

	multiquery: (params, cb, result=[]) ->
		dynamodb.query params, (err, resp) =>
			if err
				cb(err)
				return

			result = result.concat(resp.Items)

			if resp.LastEvaluatedKey?
				params.ExclusiveStartKey = resp.LastEvaluatedKey
				@multiquery(params, cb, result)
			else
				o = for e in result
					@dynamoConvertItem({Item:e})
				cb(null, o)
			return
		return


	singlequery: (params, cb, result=[]) ->
		dynamodb.query params, (err, resp) =>
			if err
				cb(err)
				return
			o = for e in resp.Items
				@dynamoConvertItem({Item:e})
			cb(null, o)
			return
		return


	storeProps: (p) ->
		nullkeys = for key of p when p[key] is null
			key
		return JSON.stringify(_.omit(p, nullkeys))


	threadQueryPrepare: (items) ->
		for e in items
			@threadPrepare(e)


	threadPrepare: (item)->
		if not item.id
			return {}
		if item.p?
			item.p = JSON.parse(item.p)
		return _.omit(item, "pid")


	throwError: (cb, err, data={}) ->
		# try to create a error Object with humanized message
		if _.isString(err)
			_err = new Error()
			_err.name = err
			_err.message = _ERRORS?[err]?(data) or "unkown"
		else 
			_err = err
		cb(_err)
		return


	userQueryPrepare: (items) ->
		for e in items
			@userPrepare(e)


	# isolate the id
	userPrepare: (item)->
		if not item.id
			return {}
		if item.p?
			item.p = JSON.parse(item.p)
		if item.pid?
			item.cid = item.pid # needed to users.setAuthor
		return _.omit(item, "pid")


	# return just id and userid
	userExtIdPrepare: (item)->
		return _.omit(item, "pid")


	validate: (o, items, cb) ->
		for item in items
			switch item
				when "cid"
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string"})
						return false
					if not o[item]?
						@throwError(cb, "missingParameter", {item:item})
						return false
					if not _VALID.cid.test(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be in the format XXXX_abcd1234"})
						return false
				when "extid"
					if o[item]?
						if not _.isString(o[item])
							@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string."})
							return false
						if not _VALID.extid.test(o[item])
							@throwError(cb, "invalidValue", {msg:"`#{item}` must be between 1 and 256 chars"})
							return false
				when "fid", "v", "tid", "mid"
					if not o[item]?
						@throwError(cb, "missingParameter", {item:item})
						return false
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string"})
						return false
					o[item] = o[item][0...9]
				# User id
				when "id", "a", "la"
					if not o[item]?
						@throwError(cb, "missingParameter", {item:item})
						return false
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string"})
						return false
					if not _VALID.id.test(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must only contain [a-zA-Z0-9-_] and must be 3-24 characters long"})
						return false
					# User Ids should be lowercase
					if item is "id"
						o[item] = o[item].toLowerCase()
				when "p"
					o[item] = o[item] or {}
					if not _.isObject(o.p) or _.isArray(o.p)
						@throwError(cb, "invalidValue", {msg:"`p` must be an object"})
						return false
					if _.keys(o.p).length > 64
						@throwError(cb, "invalidValue", {msg:"`p` must not contain more than 64 keys."})
						return false
					# Check if every key is either a boolean, string or a number
					for e of o.p
						if not @isArrayStringNumberBooleanNull(o.p[e])
							@throwError(cb, "invalidValue", {msg:"`p.#{e}` has a forbidden type. Only arrays, strings, numbers, boolean and null are allowed."})
							return false
						# Make sure only strings, numbers, boolean or null are in the array
						if _.isArray(o.p[e])
							if o.p[e].length > 64
								@throwError(cb, "invalidValue", {msg:"An arrry inside `p` must not contain more than 64 elements."})
								return false
							for item in o.p[e]
								if not @isStringNumberBooleanNull(item)
									@throwError(cb, "invalidValue", {msg:"`p.#{e}` has a forbidden type. Arrays may only contain strings, numbers, boolean and null."})
									return false
				when "tpid"
					if not o[item]?
						@throwError(cb, "missingParameter", {item:item})
						return false
					if not _.isString(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must be a string."})
						return false
					if not _VALID.tpid.test(o[item])
						@throwError(cb, "invalidValue", {msg:"`#{item}` must only contain [a-zA-Z0-9-]"})
						return false
				when "top"
					if o[item]
						o[item] = 1
					else
						o[item] = null
				when "ts"
					if o[item]?
						if not _VALID.ts.test(o[item])
							@throwError(cb, "invalidValue", {msg:"`#{item}` must be a valid alpha-numeric timestamp."})
							return false
				when "type"
					if o[item] is "p"
						o[item] = ["id","p"]
					else if o[item] is "all"
						o[item] = ["id","c","p","v"]
					else
						o[item] = ["id"]		
		return o

# Error handling

ERRORS =
	"missingParameter": "No `<%= item %>` supplied"
	"invalidValue": "<%= msg %>"
	"invalidVersion": "Invalid version"
	"externalIdNotFound": "External Id not found"
	"userNotFound": "User not found"
	"threadExists": "Thread exists already"
	"messageExists": "Message exists already"
	"userExists": "User name exists already"
	"forumNotFound": "Forum not found"
	"communityNotFound": "Community not found"
	"messageNotFound": "Message not found"
	"threadNotFound": "Thread not found"
	"externalIdNotUnique": "External Id not unique"
	"communityHasForums": "Community still has forums"


_ERRORS = {}
	

_VALID =
	cid: /^[a-zA-Z0-9-]{3,32}[_][a-z0-9]{8}$/
	tpid: /^[a-zA-Z0-9-]{3,32}$/
	id: /^[a-zA-Z0-9-_]{3,32}$/
	extid: /^.{1,256}$/
	ts: /^[a-z0-9]{8}$/

_initErrors = ->
	for key, msg of ERRORS
		_ERRORS[key] = _.template(msg)
	return


_initErrors()


module.exports = new Utils()
