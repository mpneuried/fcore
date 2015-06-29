forums = null
threads = null
users = null

class Worker

	constructor: () ->
		# Make sure the queue exists
		rsmq.getQueueAttributes {qname: QUEUENAME}, (err, resp) ->
			if err and err.name is "queueNotFound"
				# Create the queue
				rsmq.createQueue
					qname: QUEUENAME
				, (err, resp) ->
					return
			return
		setInterval(_check, 5 * 1000)

	# Wake up the worker and check the queue
	nudge: () ->

		return


_work = (msg) ->
	console.log "MSG", msg
	try
		if msg.rc > 100
			# delete messages if they are failed 25 times.
			# TODO: put them in a failed queue
			console.log "RSMQ MESSAGE EXCEEDED", msg
			#rsmq.deleteMessage {qname: QUEUENAME, id: msg.id}, ( err )->
			#	if err
			##		console.log "RSMQ MESSAGE DELETE - ERROR", err
			#	return
				
			return
		
		switch msg.message.action

			# Delete a thread
			# Thread is alrdy gone. Delete the messages and cleanup
			#
			#
			when "dt"
				console.log "THREAD DELETE", msg
				threads.cleanup msg.message, (err, resp) ->
					if err
						console.log "Error: Worker _work dt:", err
						return
					if resp is 0
						console.log "Deleting THREAD delete message"
						# That was the last message
						rsmq.deleteMessage {qname: QUEUENAME, id: msg.id}, ( err )->
							if err
								console.log "RSMQ MESSAGE DELETE - ERROR", err
							return
					return
			when "df"
				console.log "FORUM DELETE", msg
				forums.cleanup msg.message, (err, resp) ->
					if err
						console.log "Error: Worker _work df:", err
						return
					if resp is 0
						console.log "Deleting Forum delete message"
						# That was the last thread
						rsmq.deleteMessage {qname: QUEUENAME, id: msg.id}, ( err )->
							if err
								console.log "RSMQ MESSAGE DELETE - ERROR", err
							return
					return
			when "dc"
				console.log "COMMUNITY DELETE", msg
				users.cleanup msg.message, (err, resp) ->
					if err
						console.log "Error: Worker _work dc:", err
						return
					if resp is 0
						console.log "Deleting Community delete message"
						# That was the last user
						rsmq.deleteMessage {qname: QUEUENAME, id: msg.id}, ( err )->
							if err
								console.log "RSMQ MESSAGE DELETE - ERROR", err
							return
					return
	catch _err
		console.log "Worker Exception", _err
		if root.devmode
			console.log "--> STACK", _err.stack
		return
	  
	return


# TODO: change to rsmq-worker
_check = () ->
	rsmq.receiveMessage {qname: QUEUENAME, vt: 4}, (err, msg) ->
		if err
			console.log "Error: Worker _check:", err
			return
		if msg.id?
			msg.message = JSON.parse(msg.message)
			_work(msg)
		return
	return

module.exports = new Worker()

forums = require "./forums"
threads = require "./threads"
users = require "../communities/users"