request = require("request")
should = require("should")
testutils = require("./_utils")
_ = require("lodash")


testutils = require("./_utils")


# configuration
if process.argv[2]? and process.argv[2] is "dev" or process.env.DEV
	console.log "LOADING DEV Settings"
	config = require "../config_dev.json"
else
	config = require "../config.json"
_port = process.env.PORT or config.port or 3000

_Cnf =
	"DEV":
		baseUrl:"http://localhost:#{_port}"

# get the configuration out of args
if ( _xIdx = process.argv.indexOf( "-x" ) ) >= 0 and ( _x = process.argv[ _xIdx + 1 ] ) in _.keys( _Cnf )
	testConfig = _x
else if process.env?._testconfig?
	testConfig = process.env?._testconfig
else
	testConfig = "DEV"

# define the config
Cnf = _Cnf[ testConfig ]

td = require("./_testdata")( Cnf )

stdCallback = ( done, set = false, opts = {} )->
	return ( err, resp, body )->
		try
			console.error( err ) if err
			should.not.exist( err )
			resp.statusCode.should.equal( 200 )
			
			@test( body, _.extend( { set: set }, opts ) )
			@set( body ) if set
		catch _err
			console.log "   REQUEST", resp.request.method, resp.request.href, "\n	", body 
			throw _err
		done()
		return
	
delCallback = ( done, opts = {} )->
	return ( err, resp, body )->
		try
			should.not.exist( err )
			resp.statusCode.should.equal( 200 )
			
			@test( body, opts)
			@destroy()
		catch _err
			console.log "   REQUEST", resp.request.method, resp.request.href, "\n	", body 
			throw _err
		done()
		return

multiCallback = ( done, testOpt )->
	return ( err, resp, body )->
		try
			should.not.exist( err )
			resp.statusCode.should.equal( 200 )
			# 
			body.should.have.length( @parent[ @cname + "Count"]() )
			@parent[ @cname + "Test"]( body, testOpt )
		catch _err
			console.log "   REQUEST", resp.request.method, resp.request.href, "\n	", body 
			throw _err
		done()
		return

errorCallback = ( done, args... )->
	errorName = null
	statusCode = 400
	testOpt = null
	dump = false
	for arg in args
		if _.isString( arg )
			errorName = arg
		if _.isNumber( arg )
			statusCode = arg
		if _.isObject( arg )
			testOpt = arg
		if arg is true
			dump = true
	return ( err, resp, body )->
		if dump
			console.log "RETURNED", err, resp.statusCode, body, "\nTEST OPTS", errorName, statusCode, testOpt
		try
			should.not.exist( err )
			resp.statusCode.should.equal( statusCode )
			
			if errorName?
				body.should.have.property( "name" ).and.eql( errorName )
			
			if testOpt?.props?
				for _k, _v in testOpt.props
					body.should.have.property( _k ).and.eql( _v )
		catch _err
			console.log "   REQUEST", resp.request.method, resp.request.href, "\n	", body 
			throw _err
		done()
		return

describe 'fCore -', ->
	
	describe 'CONNECTION', ->

		describe 'ping', ->
			it 'should return `OK` if endpoint is available', ( done )->
				request
					url: Cnf.baseUrl + "/ping"
					method: "GET"
					( err, resp, body )->
						should.not.exist( err )
						
						resp.statusCode.should.equal( 200 )
						body.should.have.type( "string" )
						body.should.equal( "OK" )
						done()
						return
				return
			
			return
		return
	
	# init testdata
	tCommA = new td.Community()
	tCommB = new td.Community()
	
	tUserAA = null
	tUserAB = null
	tUserBC = null
	
	tForumAA = null
	tForumAB = null
	tForumBC = null
	
	tThreadAAA = null
	tThreadABB = null
	tThreadABC = null
	tThreadBCD = null
	
	tMessageAAAA = null
	tMessageAAAB = null
	tMessageAAAC = null
	tMessageABCD = null
	
	describe 'COMMUNITY -', ->
		
		describe 'GENERAL -', ->
			it 'create a community', ( done )->
				tCommA.setP( "name": "TestCommunity A" ).request "POST", stdCallback( done, true )
				return
			
			it 'create a second community', ( done )->
				tCommB.setP( "name": "TestCommunity A" ).request "POST", stdCallback( done, true )
				return
			
			it 'get the created community', ( done )->
				tCommA.request "GET", { id: true }, stdCallback( done )
				return
				
			it 'update the community', ( done )->
				tCommA.setP( "name": "TestCommunity A 2" ).request "POST", {id: true}, stdCallback( done, true )
				return
			
			it 'get the community by tpid', ( done )->
				tCommA.request "GET", {url: "/query/tpid/#{tCommA.get('tpid')}"}, ( err, resp, body )->
					should.not.exist( err )
					resp.statusCode.should.equal( 200 )

					body.should.have.length( 1 )
					@test( body[0] )
					done()
					return
				return
			return
				
		describe 'CASES -', ->
			
			it 'create a community without tpid', ( done )->
				comm = new td.Community()
				comm.once "request", ( opts )->
					delete opts.json.tpid
					return
				comm.setP( "name": "TestCommunity Fail 1" ).request "POST", errorCallback( done, "missingParameter", 403 )
				return
			
			it 'create a community with tpid = "null"', ( done )->
				comm = new td.Community()
				comm.once "request", ( opts )->
					opts.json.tpid = null
					return
				comm.setP( "name": "TestCommunity Fail 2" ).request "POST", errorCallback( done, "missingParameter", 403 )
				return
			
			it 'create a community with empty tpid', ( done )->
				comm = new td.Community()
				comm.once "request", ( opts )->
					opts.json.tpid = ""
					return
				comm.setP( "name": "TestCommunity Fail 3" ).request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'create a community with invalid tpid', ( done )->
				comm = new td.Community()
				comm.once "request", ( opts )->
					opts.json.tpid = "abc§$123"
					return
				comm.setP( "name": "TestCommunity Fail 4" ).request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'get a not existing community', ( done )->
				comm = new td.Community()
				comm.request "GET", {url: "/12345_abcdefgh"}, errorCallback( done, "communityNotFound", 404 )
				return
				
			it 'get by invalid id', ( done )->
				comm = new td.Community()
				comm.request "GET", {url: "/1_a"}, errorCallback( done, "invalidValue", 403 )
				return
				
			it 'get by invalid id ="_"', ( done )->
				comm = new td.Community()
				comm.request "GET", {url: "/_"}, errorCallback( done, "invalidValue", 403 )
				return
			
			it 'update a not existing community', ( done )->
				tCommA.request "POST", {url: "/12345_abcdefgh"}, errorCallback( done, 404 )
				return
			
			it 'update with invalid id', ( done )->
				tCommA.request "POST", {url: "/1_a"}, errorCallback( done, "invalidValue", 403 )
				return
				
			it 'update with invalid id "_"', ( done )->
				tCommA.request "POST", {url: "/_"}, errorCallback( done, "invalidValue", 403 )
				return
				
			it 'update without any change', ( done )->
				tCommB.request "POST", {id:true}, stdCallback( done, true, { nochanges: true } )
				return
			
			it 'update and try to set the id', ( done )->
				tCommB.once "request", ( opts )->
					opts.json.id = "12345_abcde"
					return
				tCommB.setP( "name": "TestCommunity B.1" ).request "POST", {id:true}, stdCallback( done, true )
				return
			
			it 'update without v', ( done )->
				tCommB.once "request", ( opts )->
					delete opts.json.v
					opts.json.p.name = "Should Fail 5"
					return
				tCommB.request "POST", {id:true}, errorCallback( done, "missingParameter", 403 )
				return
			
			it 'update with invalid v', ( done )->
				tCommB.once "request", ( opts )->
					opts.json.v = testutils.randomString( 10 )
					opts.json.p.name = "Should Fail 6"
					return
				tCommB.request "POST", {id: true}, errorCallback( done, "invalidVersion", 403 )
				return
			
			it 'get the community by tpid', ( done )->
				tCommB.request "GET", {url: "/query/tpid/_"}, errorCallback( done, "invalidValue", 403 )
				return
			
			return
		return
	
	
	describe 'USER -', ->
		
		describe 'GENERAL -', ->
			it 'create a user', ( done )->
				tUserAA = new td.User( tCommA )
				tUserAA.name( "Test User A" ).request "POST", stdCallback( done, true )
				return
			
			it 'get a user', ( done )->
				tUserAA.request "GET", {id: true}, stdCallback( done )
				return
			
			it 'update a user', ( done )->
				tUserAA.setP( bd: "19800101" ).request "POST", {id: true}, stdCallback( done, true )
				return
			
			it 'get the changed user', ( done )->
				tUserAA.request "GET", {id: true}, stdCallback( done )
				return
			
			it 'create a second user', ( done )->
				tUserAB = new td.User( tCommA )
				tUserAB.name( "Test User B" ).request "POST", stdCallback( done, true )
				return
			
			it 'get all users of community ( type: id )', ( done )->
				tUserAA.request "GET", { qs: "id" }, multiCallback( done, { onlyId: true } )
				return
			
			it 'get all users of community ( type: p )', ( done )->
				tUserAA.request "GET", { qs: type: "p" }, multiCallback( done, { onlyP: true } )
				return
			
			it 'get all users of community ( type: all )', ( done )->
				tUserAA.request "GET", { qs: type: "all" }, multiCallback( done )
				return
			
			it 'create a third user', ( done )->
				tUserBC = new td.User( tCommB )
				tUserBC.name( "Test User C" ).request "POST", stdCallback( done, true )
				return
			
			it 'update a users name', ( done )->
				tUserBC.name( "イザ ナギ" )
				tUserBC.request "POST", {id: true}, stdCallback( done, true )
				return
				
			return
			
		describe 'CASES -', ->
			it 'create a user with unkown community', ( done )->
				comm = new td.Community()
				comm.data.id = "12345_abcdefgh"
				usr = new td.User( comm )
				usr.name( "User with unkown community" ).request "POST", errorCallback( done, "communityNotFound", 404 )
				return
			
			it 'create a user with empty community', ( done )->
				comm = new td.Community()
				comm.data.id = ""
				usr = new td.User( comm )
				usr.name( "User with unkown community" ).request "POST", errorCallback( done, 404 )
				return
				
			it 'create a user with invalid cid', ( done )->
				comm = new td.Community()
				comm.data.id = "_"
				usr = new td.User( comm )
				usr.name( "User with unkown community" ).request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'create a user with a long spaced name', ( done )->
				usr = new td.User( tCommB )
				usr.name( "User with unkown community" )
				usr.data.id = "This is a complex name"
				usr.request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'create a user with a complex name', ( done )->
				usr = new td.User( tCommB )
				usr.name( "イザナギ" )
				usr.request "POST", errorCallback( done, "invalidValue", 403 )
				return
				
			it 'create a user with invalid p', ( done )->
				usr = new td.User( tCommB )
				usr.name( "Invalid P" )
				usr.once "request", ( opts )->
					opts.json.p = "invalid P"
					return
				usr.request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'get a not existing user', ( done )->
				usr = new td.User( tCommB )
				usr.name( "Not Existing" )
				usr.request "GET", {id: true}, errorCallback( done, "userNotFound", 404 )
				return
			
			it 'get a user with empty id', ( done )->
				usr = new td.User( tCommB )
				usr.name( "Not Existing" )
				usr.request "GET", {url: "/_"}, errorCallback( done, "invalidValue", 403 )
				return
			
			it 'update a users with invalid p', ( done )->
				tUserBC.once "request", ( opts )->
					opts.json.p = "invalid P"
					return
				tUserBC.request "POST", {id: true}, errorCallback( done, "invalidValue", 403 )
				return
			
			it 'update a users without v', ( done )->
				tUserBC.once "request", ( opts )->
					delete opts.json.v
					return
				tUserBC.request "POST", {id: true}, errorCallback( done, "missingParameter", 403 )
				return

			###
			# TODO. User delete currently not implemented in fCore
			it 'delete with invalid v', ( done )->
				tUserBC.request "DELETE", {id: true, qs: { v: testutils.randomString( 10 ) }}, errorCallback( done, "invalidVersion", 403 )
				return
			
			###
			it 'update a user with invalid v', ( done )->
				tUserBC.once "request", ( opts )->
					opts.json.v = testutils.randomString( 10 )
					return
				tUserBC.name( "Test User should Fail" ).request "POST", {id: true}, errorCallback( done, "invalidVersion", 403 )
				return
				
			return
		return
	
	describe 'FORUM -', ->
		describe 'GENERAL -', ->
					
			it 'create a forum', ( done )->
				tForumAA = new td.Forum( tCommA )
				tForumAA.setP( name: "Test Forum A", desc: "Forum description" ).request "POST", stdCallback( done, true )
				return
			
			it 'create a second forum', ( done )->
				tForumAB = new td.Forum( tCommA )
				tForumAB.setP( name: "Test Forum B", desc: "Forum description" ).request "POST", stdCallback( done, true )
				return
			
			it 'create a third forum without p data', ( done )->
				tForumBC = new td.Forum( tCommB )
				tForumBC.set( "p", {} ).request "POST", stdCallback( done, true )
				return
			
			it 'get a forum', ( done )->
				tForumAA.request "GET", {id: true}, stdCallback( done )
				return
				
			it 'update a forum', ( done )->
				tForumAA.setP( desc: "The new forum description" ).request "POST", {id: true}, stdCallback( done, true )
				return
				
			it 'delete a forum', ( done )->
				tForumAA.request "DELETE", {id: true}, delCallback( done )
				return
			
			it 'get all forums of cid', ( done )->
				tForumAB.request "GET", { url: "/query/cid/#{tForumAB.parent.id}" }, multiCallback( done )
				return
			
			it 'get all forums of tpid', ( done )->
				tForumAB.request "GET", { url: "/query/tpid/#{tForumAB.parent.tpid}" }, multiCallback( done )
				return
			return
		
		describe 'CASES -', ->
			it 'create a forum with unkown community', ( done )->
				comm = new td.Community()
				comm.data.id = "12345_abcdefgh"
				frm = new td.Forum( comm )
				frm.setP( name: "Test Forum Fail", desc: "Forum description" ).request "POST", errorCallback( done, "communityNotFound", 404 )
				return
			
			it 'create a forum with empty community', ( done )->
				comm = new td.Community()
				comm.data.id = ""
				frm = new td.Forum( comm )
				frm.setP( name: "Test Forum Fail", desc: "Forum description" ).request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'create a forum with invalid cid', ( done )->
				comm = new td.Community()
				comm.data.id = "_"
				frm = new td.Forum( comm )
				frm.setP( name: "Test Forum Fail", desc: "Forum description" ).request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'create a forum with invalid p', ( done )->
				frm = new td.Forum( tCommB )
				frm.once "request", ( opts )->
					opts.json.p = "invalid P"
					return
				frm.request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'get a not existing forum', ( done )->
				frm = new td.Forum( tCommB )
				frm.request "GET", {id: true}, errorCallback( done, 404 )
				return
			
			it 'get a forum with empty id', ( done )->
				frm = new td.Forum( tCommB )
				frm.request "GET", {url: "/_"}, errorCallback( done, "forumNotFound", 404 )
				return
			
			it 'update a forum with invalid p', ( done )->
				tForumAB.once "request", ( opts )->
					opts.json.p = "invalid P"
					return
				tForumAB.request "POST", {id: true}, errorCallback( done, "invalidValue", 403 )
				return
				
			it 'update a forum without v', ( done )->
				tForumAB.once "request", ( opts )->
					delete opts.json.v
					return
				tForumAB.request "POST", {id: true}, errorCallback( done, "missingParameter", 403 )
				return
			
			it 'update a forum with invalid v', ( done )->
				tForumAB.once "request", ( opts )->
					opts.json.v = testutils.randomString( 10 )
					opts.json.p.desc = "should fail"
					return
				tForumAB.request "POST", {id: true}, errorCallback( done, "invalidVersion", 403 )
				return

			return
		return
	
	describe 'THREADS -', ->
		describe 'GENERAL -', ->
			it 'create a thread', ( done )->
				tThreadAAA = new td.Thread( tForumAB ).setEditor( tUserAA )
				tThreadAAA.setP( name: "Someting to define" ).request "POST", stdCallback( done, true )
				return
			
			it 'create a second thread', ( done )->
				tThreadABB = new td.Thread( tForumAB ).setEditor( tUserAB )
				tThreadABB.setP( name: "to delete" ).request "POST", stdCallback( done, true )
				return
			
			it 'create a third thread', ( done )->
				tThreadABC = new td.Thread( tForumAB ).setEditor( tUserAB )
				tThreadABC.setP( name: "to test" ).request "POST", stdCallback( done, true )
				return

			it 'create a second thread', ( done )->
				tThreadBCD = new td.Thread( tForumBC ).setEditor( tUserBC )
				tThreadBCD.setP( name: "to test delete" ).request "POST", stdCallback( done, true )
				return
			
			it 'get a thread', ( done )->
				tThreadAAA.request "GET", {id: true}, stdCallback( done )
				return
			
			it 'get all threads of forum', ( done )->
				tThreadAAA.request "GET", { urlAdd: "/f/#{tThreadAAA.parent.id}/query" }, multiCallback( done )
				return
			
			# TODO: Update tests
			
			it 'delete the second thread', ( done )->
				tThreadABB.request "DELETE", {id: true}, delCallback( done )
				return
			return
		
		describe 'CASES -', ->
			it 'create a thread without existing forum', ( done )->
				frm = new td.Forum( tCommB )
				frm.data.id = "unkown"
				thr = new td.Thread( frm ).setEditor( tUserAA )
				thr.setP( name: "Someting with unkown forum" ).request "POST", errorCallback( done, "forumNotFound", 404 )
				return
				
			it 'create a thread without existing community', ( done )->
				comm = new td.Community()
				comm.data.id = "12345_abcdefgh"
				frm = new td.Forum( comm )
				frm.data.id = "unkown"
				thr = new td.Thread( frm ).setEditor( tUserAA )
				thr.setP( name: "Someting with unkown forum" ).request "POST", errorCallback( done, "forumNotFound", 404 )
				return
			
			it 'create a thread without editor', ( done )->
				thr = new td.Thread( tForumAB )
				thr.setP( name: "Someting with not editor" ).request "POST", errorCallback( done, "missingParameter", 403 )
				return
			
			it 'create a thread with editor of foreign community', ( done )->
				thr = new td.Thread( tForumAA ).setEditor( tUserBC )
				thr.setP( name: "Someting with not editor" ).request "POST", errorCallback( done, "userNotFound", 404 )
				return
			
			it 'create a thread with invalid p', ( done )->
				thr = new td.Thread( tForumAB ).setEditor( tUserAB )
				thr.once "request", ( opts )->
					opts.json.p = "invalid P"
					return
				thr.request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			# TODO: Update cases
			
			it 'get a not existing thread', ( done )->
				thr = new td.Thread( tForumAB ).setEditor( tUserAB )
				thr.data.id = "unkown"
				thr.request "GET", {id: true}, errorCallback( done, "threadNotFound", 404 )
				return

			
			it 'delete a not existing thread', ( done )->
				thr = new td.Thread( tForumAB ).setEditor( tUserAB )
				thr.data.id = "unkown"
				thr.request "DELETE", {id: true}, errorCallback( done, "threadNotFound", 404 )
				return
			
			# TODO: Update an existing thread and check if the version of the forum changes. It should.

			return
		
		return
			
	describe 'MESSAGES -', ->
		
		describe 'GENERAL -', ->
			it 'create a message', ( done )->
				tMessageAAAA = new td.Message( tThreadAAA ).setEditor( tUserAA )
				tMessageAAAA.setP( b: "This is the message content" ).request "POST", stdCallback( done, true, { create: true } )
				return
			
			it 'create a second message', ( done )->
				tMessageAAAB = new td.Message( tThreadAAA ).setEditor( tUserAA )
				tMessageAAAB.setP( b: "This is the second message content" ).request "POST", stdCallback( done, true, { create: true } )
				return
			
			it 'get a second message', ( done )->
				tMessageAAAB.request "GET", {id: true}, stdCallback( done )
				return
				
			it 'update the second message forum', ( done )->
				tMessageAAAB.setP( desc: "A updated message" ).request "POST", {id: true}, stdCallback( done, true )
				return
			
			it 'delete the second message', ( done )->
				tMessageAAAB.request "DELETE", {id: true}, delCallback( done, { del: true } )
				return
			
			it 'create a message by another editor', ( done )->
				tMessageAAAC = new td.Message( tThreadAAA ).setEditor( tUserAB )
				tMessageAAAC.setP( b: "This is the thrird message content" ).request "POST", stdCallback( done, true, { create: true } )
				return
				
			it 'create a message in another thread', ( done )->
				tMessageABCD = new td.Message( tThreadABC ).setEditor( tUserAB )
				tMessageABCD.setP( b: "This is the first message in thread b" ).request "POST", stdCallback( done, true, { create: true } )
				return
				
			it 'list all messages of a thread', ( done )->
				tMessageAAAB.request "GET", { urlAdd:"/f/#{tMessageAAAB.parent.parent.id}/threads/#{tMessageAAAB.parent.id}/query" }, multiCallback( done )
				return
			
			return
			
		describe 'CASES -', ->
			it 'create a message without editor', ( done )->
				msg = new td.Message( tThreadAAA )
				msg.setP( b: "This should fail" ).request "POST", errorCallback( done, "missingParameter", 403 )
				return
			
			it 'create a message without existing user', ( done )->
				usr = new td.User( tCommA )
				usr.data.id = "unkown"
				msg = new td.Message( tThreadAAA ).setEditor( usr )
				msg.setP( b: "This should fail" ).request "POST", errorCallback( done, "userNotFound", 404 )
				return
				
			it 'create a message without existing thread', ( done )->
				thr = new td.Thread( tForumAB )
				thr.data.id = "unkown"
				msg = new td.Message( thr ).setEditor( tUserAA )
				msg.setP( b: "This should fail" ).request "POST", errorCallback( done, "threadNotFound", 404 )
				return
				
			it 'create a message without existing forum', ( done )->
				frm = new td.Forum( tCommB )
				frm.data.id = "unkown"
				thr = new td.Thread( frm )
				thr.data.id = "unkown"
				msg = new td.Message( thr ).setEditor( tUserAA )
				msg.setP( b: "This should fail" ).request "POST", errorCallback( done, "forumNotFound", 404 )
				return
				
			it 'create a message without existing community', ( done )->
				comm = new td.Community()
				comm.data.id = "unkown_123"
				frm = new td.Forum( comm )
				frm.data.id = "unkown"
				thr = new td.Thread( frm )
				thr.data.id = "unkown"
				msg = new td.Message( thr ).setEditor( tUserAA )
				msg.setP( b: "This should fail" ).request "POST", errorCallback( done, "forumNotFound", 404 )
				return
			
			it 'create a message with editor of foreign community', ( done )->
				msg = new td.Message( tThreadAAA ).setEditor( tUserBC )
				msg.setP( b: "This should fail" ).request "POST", errorCallback( done, "userNotFound", 404 )
				return
			
			# TODO: Update cases
			
			it 'create a message with invalid p', ( done )->
				msg = new td.Message( tThreadAAA ).setEditor( tUserAB )
				msg.once "request", ( opts )->
					opts.json.p = "invalid P"
					return
				msg.request "POST", errorCallback( done, "invalidValue", 403 )
				return
			
			it 'get a not existing message', ( done )->
				msg = new td.Message( tThreadAAA ).setEditor( tUserAB )
				msg.data.id = "unkown"
				msg.request "GET", {id: true}, errorCallback( done, "messageNotFound", 404 )
				return


			# TODO: Update an existing message and check if the version of the thread changes. It should.

			return
		return
	
	describe 'DELETE TEST DATA -', ->
		
		
		describe 'FORUM -', ->


			it 'get the tForumAB before delete, due to `v` change by new threads/messages', ( done )->
				tForumAB.request "GET", {id: true}, stdCallback( done, true )
				return

			it 'get the tForumBC before delete, due to `v` change by new threads/messages', ( done )->
				tForumBC.request "GET", {id: true}, stdCallback( done, true )
				return

			it 'delete tForumAB', ( done )->
				tForumAB.request "DELETE", {id: true}, delCallback( done )
				return
			it 'delete tForumBC', ( done )->
				tForumBC.request "DELETE", {id: true}, delCallback( done )
				return
			return

		describe 'COMMUNITY -', ->
			it 'delete tCommA', ( done )->
				tCommA.request "DELETE", {id: true}, delCallback( done )
				return
			it 'delete tCommB', ( done )->
				tCommB.request "DELETE",  {id: true}, delCallback( done )
				return
			return
			
		return
	return
