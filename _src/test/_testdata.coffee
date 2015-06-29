Events = require("events").EventEmitter

should = require("should")
clone = require("clone")
request = require("request")
testutils = require("./_utils")
_ = require("lodash")
extend = require("extend")

module.exports = ( Cnf )->
	class TestData extends Events
		urlAdd: ""
		default: ->
			p: {}
		
		subs: ->[]
		
		createFields: ->[ "p" ]
			
		constructor: ( init, @options )->
			@_addSubElement(sub) for sub in @subs()
			@data = extend( true, {}, @default(), init )
			
			@getter( "cname", ->@constructor.name.toLowerCase() )
			@getter( "json", @get )
			@getter( "id", ->@get( "id" ) )
			@getter( "p", ->@get( "p" ) )
			
			@saved = false
			return
		
		_addSubElement: ( cnst )=>
			name = cnst.name.toLowerCase()
			@[name + "s"] = list = []
			# internal users
			@[name + "Add"] = ( el )=>
				@[ name + "s" ].push( el )
				return @
			
			@[name + "Remove"] = ( el )=>
				if not el instanceof cnst
					el = @[name]( el )
					
				if el?
					_idx = list.indexOf( el )
					if _idx >= 0
						list.splice( _idx, 1 )
				return @
			
			@[name] = ( id )->
				for el in list when el.id is id
					return el
				return null
			
			@[name[0] + "ids"] = ->
				return _.pluck( list, "id" )
				
			@[name + "Count"] = ->
				return list.length
				
			@[name + "Test"] = ( els, options = {} )=>
				if not _.isArray( els )
					els = [ els ]
				for el in els
					_obj = @[name]( el.id )
					should.exist( _obj )
					_obj.test( el, options )
				return
			
			return
		
		getter: ( prop, _get, enumerable = true )=>
			_obj =
				enumerable: enumerable
				#writable: false

			if _.isFunction( _get )
				_obj.get = _get
			else
				_obj.value = _get
			Object.defineProperty @, prop, _obj
			return
		
		get: ( key )=>
			if key?
				return clone( @data[ key ] )
			return clone( @data )
		
		set: ( key, val, context = @data )=>
			if _.isObject( key )
				context = val if val?
				_.extend( context, key )
				return @
				
			if not key? or not val?
				throw ( new Error("no key and value define to '.set()'") )
				
			context[ key ] = val
			return @
			
		setP: ( args... )=>
			args.push( @data.p )
			return @set.apply( @, args )
			
		eqlP: ( testP )=>
			@data.p.should.eql( testP )
			return @
		
		test: ( test )=>
			test.should.have.property( "p" )
			return @eqlP( test.p )
			
		request: ( args..., cb )=>
			[ method, options ] = args
			method = "GET" if not method
			
			_.defaults( options, { json: true } )
			
			_isCreate = not @get( "v" )?
			_urlAdd = _.result(options, 'urlAdd') or _.result(@, 'urlAdd')
			_opts =
				url: Cnf.baseUrl + _urlAdd + ( _.result(options, 'url') or "" )
				method: method
				headers: _.result(options, 'headers') or {}
			
			if options?.id and @data.id?
				_opts.url += "/" + @data.id
			
			if method in [ "POST", "PUT" ]
				if _isCreate
					_opts.json = _.pick( @json, @createFields())
				else
					_opts.json = @json
			else if options?.json?
				_opts.json = true
			if options?.qs?
				_opts.qs = options.qs
			
			_handle = ( err )=>
				# set to treue after first successful save
				if not err? and method is "POST" and not ( options?.id and @data.id? )
					@saved = true
				cb.apply( @, arguments )
				return
				
			@emit "request", _opts
			request( _opts, _handle )
			return @
		
		destroy: ->
			return
			
	class TestDataSub extends TestData
		getParent: ->return
		constructor: ( @parent, init, @options )->
			@cParent = @getParent()
			if not @cParent?
				new Error("no parent defined")
				return
				
			if not @parent instanceof @cParent
				new Error("a forum needs a #{@cParent.name}")
				return
			super( init, @parent )
			
			@set( "#{@cParent.name[0].toLowerCase()}id", @parent.id )
			@parent[ "#{ @constructor.name.toLowerCase() }Add" ]( @ )
			return
	
		destroy: =>
			@parent[ "#{ @constructor.name.toLowerCase() }Remove" ]( @ )
			return
		
	class Community extends TestData
		urlAdd: "/c"
		default: ->
			tpid: null
			id: null
			p:
				name: ""
			v: null
		
		createFields: ->[ "p", "tpid" ]
		
		subs: ->[ User, Forum ]
		constructor: ->
			super
			@genTpid() if not @data[ "tpid" ]?
			@getter( "tpid", ->@get( "tpid" ) )
			return
		
		genTpid: ( len = 10 )=>
			@data[ "tpid" ] = testutils.randomString( len )
			return @data[ "tpid" ]
		
		test: ( test, options = {} )=>
			super
			test.should.have.property( "id" ).and.startWith( @data.tpid + "_" )
			test.should.have.property( "v" )
			if options?.nochanges
				test.v.should.equal( @get( "v" ) )
			else
				if @saved and options.set and @get( "v" )?
					test.v.should.not.equal( @get( "v" ) )
			return @
		
	class User extends TestDataSub
		urlAdd: =>
			return "/c/#{@parent.get('id')}/users"
		default: ->
			id: null
			extid: null
			p:
				sn: null
				ln: null
				origName: null
			c: null
			v: null
		
		createFields: ->[ "p", "id" ]
		getParent: ->Community
		test: ( test, options = {} )=>
			test.should.have.property( "id" ).and.equal( @data.id )
			if options.onlyId?
				return @
			super
			if options.onlyP?
				return @
			test.should.have.property( "v" )
			test.should.have.property( "c" )
			if test.c isnt test.v
				test.v.should.greaterThan( test.c )
			if @saved and options.set and @get( "v" )?
				test.v.should.not.equal( @get( "v" ) )
			return @
		
		regExName: /[^A-z0-9]/g
		name: ( name )=>
			if name?
				@set( "id", name.replace( @regExName, "" ).toLowerCase() ) if not @data.id?
				[sn, ln...] = name.split( " " )
				@setP( sn: sn, ln: ln.join( " " ), origName: name )
			return @

	class Forum extends TestDataSub
		urlAdd: ->
			return "/f"
		default: ->
			id: null
			cid: null
			p:
				name: null
				desc: null
			tm: 0
			tt: 0
			v: null
		createFields: ->[ "p", "cid" ]
		
		subs: ->[ Thread ]
		getParent: ->Community
		
		test: ( test, options = {} )=>
			test.should.have.property( "id" )
			if options.onlyId?
				return @
			super
			if options.onlyP?
				return @
			
			test.should.have.property( "cid" )
			test.cid.should.equal( @parent.id )
			
			test.should.have.property( "tm" ).and.be.above(-1)
			test.should.have.property( "tt" ).and.be.above(-1)
			test.should.have.property( "v" )
			
			if @saved and options.set and @get( "v" )?
				test.v.should.not.equal( @get( "v" ) )
			return
		
	class Thread extends TestDataSub
		urlAdd: ->
			return "/f/#{@parent.id}/threads"
		default: ->
			id: null
			fid: null
			p: {}
			a: null
			la: null
			tm: 0
			v: null
		
		createFields: ->[ "p", "a" ]
		getParent: ->Forum
		subs: ->[ Message ]
		
		setEditor: ( author )=>
			@set( "a", author.id )
			# this author is also the creator
			@editor = author
			if not @get( "v" )?
				@creator = author
			return @
		
		test: ( test, options = {} )=>
			test.should.have.property( "id" )
			if options.onlyId?
				return @
			super
			if options.onlyP?
				return @
						
			test.should.have.property( "a" ).and.equal( @creator.id )
			
			test.should.have.property( "tm" ).and.be.above(-1)
			test.should.have.property( "v" )
			
			if @saved and options.set and @get( "v" )?
				test.should.have.property( "la" ).and.equal( @editor.id )
				test.v.should.not.equal( @get( "v" ) )
			return @
	
	class Message extends TestDataSub
		urlAdd: ->
			return "/f/#{@parent.parent.id}/threads/#{@parent.id}/messages"
		default: ->
			id: null
			fid: null
			tid: null
			p: {}
			a: null
			v: null
		
		createFields: ->[ "p", "a" ]
		getParent: ->Thread
		
		setEditor: ( author )=>
			@set( "a", author.id )
			# this author is also the creator
			@editor = author
			if not @get( "v" )?
				@creator = author
			
			# pass the author to the parent Thread to set the last author
			@parent.setEditor( author )
			return @
		set: ( key, val, context = @data )=>
			if key?.thread?
				return super( key.message, val, context )
			else
				return super
			
		test: ( raw, options = {} )=>
			if options.create or options.del
				{ thread, message } = raw
				test = message
			else
				test = raw
				
			test.should.have.property( "id" )
			if options.onlyId?
				return @
			super( test, options )
			if options.onlyP?
				return @
			
			if options.create or options.del
				@parent.test( thread, options )
			
			test.should.have.property( "a" ).and.equal( @creator.id )
			test.should.have.property( "v" )
			
			if @saved and options.set and @get( "v" )?
				test.v.should.not.equal( @get( "v" ) )
			return @

		
	# return the test helpers	
	Community: Community
	User: User
	Forum: Forum
	Thread: Thread
	Message: Message
