module.exports = ( grunt ) ->
	
	# Prevent from throwing event listener warning
	grunt.event.setMaxListeners( 50 )


	# Project configuration.
	grunt.initConfig

		pkg: grunt.file.readJSON( 'package.json' )
		
		# ########
		# DEVELOPMENT
		# ########
		watch:
			coffee:
				files: ['_src/**/*.coffee']
				tasks: ["coffee:all", "notify:watch"]
					
		# ########
		# COMPILE
		# ########
		coffee:
			all:
				expand: true
				cwd: '_src',
				src: ["**/*.coffee"]
				dest: ''
				ext: '.js'
		
		# ########
		# NOTIFY
		# ########
		notify_hooks:
			options:
				enabled: true

		notify:
			watch:
				options:
					title: "Coffee Compile"
					message: "Success!"
		
		# ########
		# TEST
		# ########
		mochacli:
			options:
				require: [ "should" ]
				reporter: "spec"
			main:
				src: [ "test/main.js" ]
				options:
					timeout: 7000
					bail: false
					env:
						DEV: true
		


	# NPM MODULES
	grunt.loadNpmTasks "grunt-contrib-watch"
	grunt.loadNpmTasks "grunt-notify"
	grunt.loadNpmTasks "grunt-contrib-coffee"
	grunt.loadNpmTasks "grunt-mocha-cli"

	# Run on init
	grunt.task.run('notify_hooks')

	grunt.registerTask "default", "build"
	grunt.registerTask "build", ["coffee"]
	grunt.registerTask "test", "mochacli"
	

	grunt.event.on 'watch', (action, filepath) ->
		grunt.config( 'coffee.all.src', filepath )
		return
