AWS = require "aws-sdk"
config = require "./config.json"
dynamodb = new AWS.DynamoDB(config.awsconfig)


# Check if the tables exist
checkTables = (cb) ->
	dynamodb.describeTable {TableName: "fcore"}, (err, resp) ->
		if err
			# Create the table
			create_fcore (err, resp) ->
				if err
					console.log "ERROR", err
				return
		dynamodb.describeTable {TableName: "fcore_f"}, (err, resp) ->
			console.log "FCORE_F", err, JSON.stringify(resp,true,2)
			if err
				# Create the table

				create_fcore_f (err, resp) ->
					if err
						console.log "ERROR", err
					cb(err, true)
					return
				return
		return
	return

create_fcore = (cb) ->
	params =
		TableName: "fcore"
		AttributeDefinitions: [
			AttributeName: "id"
			AttributeType: "S"
		,
			AttributeName: "pid"
			AttributeType: "S"
		,
			AttributeName: "lm"
			AttributeType: "S"
		]
		KeySchema: [
			AttributeName: "pid"
			KeyType: "HASH"
		,
			AttributeName: "id"
			KeyType: "RANGE"
		]
		ProvisionedThroughput:
			ReadCapacityUnits: 5
			WriteCapacityUnits: 5
		GlobalSecondaryIndexes: [
				IndexName: "lastmsgdate"
				KeySchema: [
					AttributeName: "pid"
					KeyType: "HASH"
				,
					AttributeName: "lm"
					KeyType: "RANGE"
				]
				Projection:
					ProjectionType: "ALL"
				ProvisionedThroughput:
					ReadCapacityUnits: 15
					WriteCapacityUnits: 20

		]

	dynamodb.createTable params, (err, resp) ->
		console.log "TABLE fcore CREATED", err, resp
	return

create_fcore_f = (cb) ->
	params =
		TableName: "fcore_f"
		AttributeDefinitions: [
			AttributeName: "id"
			AttributeType: "S"
		,
			AttributeName: "tpid"
			AttributeType: "S"
		,
			AttributeName: "cid"
			AttributeType: "S"
		]
		KeySchema: [
			AttributeName: "id"
			KeyType: "HASH"
		]
		GlobalSecondaryIndexes: [
			IndexName: "tpid-index"
			KeySchema: [
				AttributeName: "tpid"
				KeyType: "HASH"
			]
			Projection:
				ProjectionType: "ALL"
			ProvisionedThroughput:
				ReadCapacityUnits: 3
				WriteCapacityUnits: 3
		,
			IndexName: "cid-index"
			KeySchema: [
				AttributeName: "cid"
				KeyType: "HASH"
			]
			Projection:
				ProjectionType: "ALL"
			ProvisionedThroughput:
				ReadCapacityUnits: 3
				WriteCapacityUnits: 3
		]

		ProvisionedThroughput:
			ReadCapacityUnits: 3
			WriteCapacityUnits: 3

	dynamodb.createTable params, (err, resp) ->
		console.log "TABLE fcore_c CREATED", err, resp
	return

checkTables (err, resp) ->
	console.log err, resp
	console.log resp.statusCode
	return
