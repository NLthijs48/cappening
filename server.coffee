MD5 = require 'md5' # MD5 library (packed with the plugin)
Shared = require 'shared'
member = Shared.member()
Config = Shared.config()
tr = I18n.tr


########## SHARED
#	gameState: <number>
#		// 0 = setup, user that added plugin selects settings
#		// 1 = running, game is running
#		// 2 = ended, game is over, new game can be started
#	gameNumber: <number> // Current game number, increased when creating a new game
#	version: <number> // Game version, see onUpgrade() in server.coffee
#	maxDeviceId: <number> // Maximum device id that is assigned (next to assign is +1)
#	lastNotification: // Last notification about close to beacon (background location)
#		<id>: <timestamp> // Time of last notification to user with <id>
#	game: // Contains all information about the current game
#		roundTime: <number> // Round time in seconds
#		numberOfTeams: <number> // Number of teams to create
#		beaconRadius: <number> // Radius of beacons in meters
#		roundTimeNumber: <number> // Number for the round time
#		roundTimeUnit: <word> // Time unit currently selected
#		startTime: <timestamp> // Start time of the game
#		endTime: <timestamp> // Original entime of the game
#		newEndTime: <timestamp> // New endtime of the game incase all beacons are captured
#		beacons:
#			<number>: // Increasing unique number
#				location: <latlong>
#				owner: <teamnumber> // Team that currently owns the beacon
#				captureValue: <value for takeover> // Number of points for the next capture
#				actionStarted: <timestamp> // Time that capture or neutralize started
#				action: <none|capture|neutralize> // Current action
#				nextOwner: <teamnumber>
#				percentage: <0-100> // Only updated when the inRange list changes
#					// ‘action’ and ‘actionStarted’ can be used to predict the current percentage
#				inRange: // List with userIds that are in range of this beacon
#					<userId>: // If an entry for a userId exists then he is in range
#						device: <deviceId> // Device id for this entry of the user
#						time: <timestamp> // Last time this inRange has been confirmed
#		teams:
#			<number>: // Increasing unique number, same number as colors<number>
#				teamScore: <number> // Timebased on number of beacons held by team <number>
#				captured: <number> // Number of beacons captured in this game
#				neutralized: <number> // Number of beacons neutralized in this game
#				ranking: <number> // Ranking this team has currently (determined by scores)
#				users:
#					<id>: // Unique name (userId), get actual name with Plugin.username()
#						userScore: <score>
#						userName: <name> // Name of the player for debug, not to be used for display, use Plugin.userName(<id>) instead
#						captured: <number> // Number of beacons captured in this game
#						neutralized: <number> // Number of beacons neutralized in this game
#		eventlist:
#			maxId: <number>
#			<number>: // Increasing unique number or timestamp
#				timestamp: <timestamp> // Seconds since 1970
#				type: <type> // score, capture, captureAll, cancel, end, start
#				beacon: <beaconId>
#				conqueror: <teamId>
#				leading: <teamId>
#				members: <userIdString> // String of userids, separated by ‘, ’
#		firstTeam: <teamnumber>

########## BACKEND
#	collectionRegistered: <true> // Indicates this plugin has registered with the collector
#	history: // Contains old games
#		groupCode: <code>	// Groupcode (used as unique identifier)
#		players: <number> // Number of players in the Happening
#		<number>: // Increasing unique number
#		<gameState>
#				<all information like below the game node>

########## PERSONAL
#	lastNotification:
#		recieved: <time> // time in millieseconds
#		beaconNumber: <beaconId> //number of beacon where notification was sent for
#	tutorialState:	//Indicates which tutorialcontent the user has already seen
#		<content>: 1

########## LOCAL
#	currentSetupPage: <name> // The page the user is on, used for the setup pages
#				// ‘setup’ + number from ‘setupPhase’ node
#	gameNumber: <number> // Current gameNumber the client knows of, used to reset things
#		// after a game
#	deviceId: <number> // Unique id of this device, used for multiple inRange for same client
#	lastMapLocation: <latlong> // Keeps last map location, is restored when restarting the app
#	lastMapZoom: <number> // Keeps last map zoom, is restored when restarting the app
#	switchToMapLocation: <latlong> // Switch to this location when rendering the map
#	switchToMapZoom: <number>
#	switchToPopup: <number>


# ==================== Events ====================
# Game install
exports.onInstall = !->
	Db.shared.set 'version', 100
	initializeGame()

# Game update
exports.onUpgrade = !->
	log "[onUpgrade] at #{new Date()}"
	# Check version number and upgrade if required
	version = Db.shared.peek('version')
	newVersion = version
	if not version?
		version = 0

	# Update legacy Javascript version to new one
	if version < 100
		newVersion = 100
		upgradeLocation = (pathO) !->
			return if !(p=pathO.peek())? or typeof p isnt 'object'
			lat = pathO.peek 'lat'
			lng = pathO.peek 'lng'
			if lat? and lng?
				pathO.set lat+","+lng
			else
				log '[onUpgrade] could not convert path', pathO.key(), 'data:', pathO.peek()
		if Db.shared.peek('game', 'beacons')?
			Db.shared.iterate 'game', 'beacons', (beaconO) !->
				upgradeLocation beaconO.ref 'location'
		upgradeLocation Db.shared.ref('game', 'bounds', 'one')
		upgradeLocation Db.shared.ref('game', 'bounds', 'two')

		Db.backend.iterate 'history', (historyO) !->
			if historyO.peek('game', 'beacons')
				historyO.iterate 'game', 'beacons', (beaconO) !->
					upgradeLocation beaconO.ref 'location'
			upgradeLocation historyO.ref('game', 'bounds', 'one')
			upgradeLocation historyO.ref('game', 'bounds', 'two')

		log '[onUpgrade] Upgraded legacy Javascript version to API version'

	# Write new version to the database
	if newVersion isnt version
		log "[onUpgrade] Upgraded from version #{version} to #{newVersion}"
		Db.shared.set 'version', newVersion

# Config changes (by admin or plugin owner)
exports.onConfig = (config) !->
	if config.restart
		restartGame()

# Get background location from player.
exports.onGeoloc = (userId, geoloc) !->
	#log "[onGeoloc] Geoloc from #{member()}", JSON.stringify(geoloc)
	recieved = new Date()/1000
	if Db.shared.peek('gameState') is 1 and (recieved - (Db.personal(userId).peek('lastNotification', 'recieved') || 0)) > 60*60
		beaconRadius = Db.shared.peek('game', 'beaconRadius')
		found = false
		# Check if user is in range of an enemy beacon, opening the app will capture the beacon
		Db.shared.iterate 'game', 'beacons', (beacon)!->
			if (parseInt(beacon.peek('owner'),10) isnt parseInt(Shared.getTeamOfUser(userId),10)) and !found
				if distance(geoloc.latlong, beacon.peek('location')) < beaconRadius
					found = true
					if beacon.key() isnt Db.personal(userId).peek('lastNotification', 'beaconNumber')
						# send notifcation
						Event.create
							unit: 'inRange'
							include: userId
							text: 'You are in range of an enemy beacon, capture it now!'
						# Last notification send, so that the user will not be spammed with notifications
						Db.personal(userId).set('lastNotification', 'recieved', recieved)
						Db.personal(userId).set('lastNotification', 'beaconNumber', beacon.key())

# Handle new users joining the happening
exports.onJoin = (userId) !->
	log "[onJoin] #{member(userId)}"
	for player in App.userIds()
		isInTeam = false
		if not (Shared.getTeamOfUser(player)?)
			log "[onJoin] Player #{member(player)} joined the Happening"
			if parseInt(Db.shared.peek('gameState')) is 1
				# Find teams with lowest number of members
				min = 99999
				lowest = []
				teamCount = 0
				Db.shared.iterate 'game', 'teams', (team) !->
					teamCount++
					count = Db.shared.count('game', 'teams', team.key(), 'users').get()
					if count < min
						min = count
						lowest = []
						lowest.push team.key()
					else if count is min
						lowest.push team.key()
				# Draw a random team from those
				randomNumber = Math.floor(Math.random() * lowest.length)
				team = lowest[randomNumber]
				if teamCount is 1 # Handle case that you started a game on your own, with 2 teams (one being empty)
					team = 1
					Db.shared.set 'game', 'teams', team,
						teamScore: 0
						captured: 0
						neutralized: 0
					updateTeamRankings()
				# Add player to team
				Db.shared.set 'game', 'teams', team, 'users', player,
					userScore: 0
					captured: 0
					neutralized: 0
					userName: App.userName(player)
				log "[onJoin] Added to team #{team}"

#==================== Client calls ====================
# Restarts game
exports.client_restartGame = restartGame = !->
	#Store old game data in history
	moveData()
	#Reset game database
	initializeGame()

# Add a beacon (during setup phase)
exports.client_addMarker = (location) !->
	App.assertAdmin()
	if Db.shared.peek('gameState') isnt 0
		log "[addMarker] #{member()} tried to add a marker while game is not in setup phase!"
	else
		log "[addMarker] Adding marker at #{location}"
		nextNumber = 0
		while Db.shared.peek('game', 'beacons', nextNumber)?
			nextNumber++
		Db.shared.set 'game', 'beacons', nextNumber,
			location: location
			owner: -1
			nextOwner: -1
			percentage: 0
			captureValue: Config.beaconValueInitial
			action: 'none'

# Delete a beacon (during setup phase)
exports.client_deleteBeacon = (key) !->
	App.assertAdmin()
	#Finding the right beacon
	if Db.shared.peek('gameState') isnt 0
		log "[deleteBeacon] #{member()} tried to delete a beacon while game is not in setup phase!"
	else
		log "[deleteBeacon] Deleted beacon: key: #{key}"
		Db.shared.remove 'game', 'beacons', key

# Set the round time unit and number
exports.client_setRoundTime = (roundTimeNumber, roundTimeUnit) !->
	App.assertAdmin()
	log "[setRoundTime] RoundTime set to: #{roundTimeNumber} #{roundTimeUnit}"
	Db.shared.set 'game', 'roundTimeNumber', roundTimeNumber
	Db.shared.set 'game', 'roundTimeUnit', roundTimeUnit

# Set the number of teams
exports.client_setTeams = (teams) !->
	App.assertAdmin()
	log "[setTeams] Teams set to: #{teams}"
	Db.shared.set 'game', 'numberOfTeams', teams

# Get a new device id
exports.client_getNewDeviceId = (result) !->
	newId = (Db.shared.peek('maxDeviceId'))+1
	log "[getDeviceId] newId #{newId} send to #{member()}"
	Db.shared.set 'maxDeviceId', newId
	result.reply newId

# Log a message from the client on the server(used for testing purposes)
exports.client_log = (message) !->
	log "[log] #{member()}:", message

# Start the game
exports.client_startGame = !->
	App.assertAdmin()
	if Db.shared.peek('gameState') is 0
		setTimer()
		userIds = App.userIds()
		Db.shared.set 'game', 'startTime', new Date()/1000
		teams = Db.shared.peek('game','numberOfTeams')
		team = 0
		while(userIds.length > 0)
			randomNumber = Math.floor(Math.random() * userIds.length)
			userO = Db.shared.ref 'game', 'teams', team, 'users', userIds[randomNumber]
			userO.set 'userScore', 0
			userO.set 'captured', 0
			userO.set 'neutralized', 0
			userO.set 'userName', App.userName(userIds[randomNumber])
			log "[startGame] Team #{team} has player #{member(userO.key())}"
			userIds.splice(randomNumber,1)
			team++
			team = 0 if team >= teams
		Db.shared.iterate 'game', 'teams', (teamO) !->
			teamO.set 'teamScore', 0
			teamO.set 'captured', 0
			teamO.set 'neutralized', 0
		updateTeamRankings()
		addEvent {
			timestamp: new Date()/1000
			type: "start"
		}
		Db.shared.set 'gameState', 1 # Set gameState at the end, because this triggers a repaint at the client so we want all data prepared before that
		Event.create
			unit: 'startGame'
			text: "A new game of Conquest has started!"
			path: ['log']
	else
		log "[startGame] #{member()} tried to start the game while not in setup!"


# Checkin location for capturing a beacon
exports.client_checkinLocation = (location, device, accuracy) !->
	if Db.shared.peek('gameState') isnt 1
		log "[checkinLocation] #{member()} tried to capture beacon while game is not running!"
	else
		#log '[checkinLocation] '+App.userName()+' ('+App.userId()+') location='+location+', device='+device+', accuracy='+accuracy
		if !location?
			log "[checkinLocation] Incorrect location by #{member()}: #{location}"
			return
		beaconRadius = Db.shared.peek('game', 'beaconRadius')
		Db.shared.iterate 'game', 'beacons', (beacon) !->
			current = beacon.peek('inRange', App.userId(), 'device')?
			beaconDistance = distance(location, beacon.get('location'))
			newStatus = beaconDistance < beaconRadius
			#log 'distance='+beaconDistance, 'newstatus='+newStatus, 'currentstatus='+current
			if newStatus isnt current
				# Cancel timers of ongoing caputes/neutralizes (new ones will be set below if required)
				Timer.cancel 'onCapture', {beacon: beacon.key()}
				Timer.cancel 'onNeutralize', {beacon: beacon.key()}
				removed = undefined
				owner = beacon.peek 'owner'
				if newStatus
					if not device? # Deal with old clients by denying them to be added to inRange
						log "[checkinLocation] Denied adding to inRange, no deviceId provided by #{member()}"
						return
					if accuracy > beaconRadius
						log "[checkinLocation] Denied adding to inRange of #{member()}, accuracy too low: #{accuracy}m"
						return
					log "[checkinLocation] Added #{member()} to inRange with device #{device}"
					beacon.set 'inRange', App.userId(), 'device', device
					refreshInrangeTimer(App.userId(), device)
				else
					inRangeDevice = beacon.peek('inRange', App.userId(), 'device')
					if inRangeDevice is device
						log "[checkinLocation] Removed #{member()} from inRange with device #{device}"
						# clean takeover
						beacon.remove 'inRange', App.userId()
						removed = App.userId()
						Timer.cancel 'inRangeTimeout', {beacon: beacon.key(), client: App.userId()}
					else
						log "[checkinLocation] Denied removing #{member()} from inRange, deviceId #{device} does not match inRangeDevice #{inRangeDevice}"
				#log 'removed=', removed
				updateBeaconStatus(beacon, removed)
			else
				if current
					refreshInrangeTimer(App.userId(), device)

#Update tutorial state
exports.client_updateTutorialState = (userId, content) !->
	Db.personal(userId).set 'tutorialState',content, 1


# Update the takeover percentage of a beacon depening on current action and the passed time
updateBeaconPercentage = (beacon) !->
	currentPercentage = beacon.peek 'percentage'
	action = beacon.peek 'action'
	actionStarted = beacon.peek 'actionStarted'
	if action is 'capture'
		time = (new Date()/1000)-actionStarted
		newPercentage = currentPercentage+(time/30*100)
		newPercentage = 100 if newPercentage>100
		beacon.set 'percentage', newPercentage
	else if action is 'neutralize'
		time = (new Date()/1000)-actionStarted
		newPercentage = currentPercentage-(time/30*100)
		newPercentage = 0 if newPercentage<0
		beacon.set 'percentage', newPercentage

# Update the status of the beacon capturing process
updateBeaconStatus = (beacon, removed) !->
	# ========== Handle changes for inRange players ==========
	# Determine members per team
	owner = beacon.peek('owner')
	teamMembers = (0 for team in [0..5])
	inRangeCount = 0
	beacon.iterate 'inRange', (player) !->
		if parseInt(player.key(), 10) isnt parseInt(removed, 10)
			team = Shared.getTeamOfUser(player.key())
			teamMembers[team] = teamMembers[team]+1
			inRangeCount++

	# Determine who is competing
	max = 0
	competing = []
	for team in [0..5]
		if teamMembers[team] > max
			max = teamMembers[team]
			competing = []
			competing.push team
		else if teamMembers[team] is max
			competing.push team
	# Update percentage taken for current time
	updateBeaconPercentage(beacon)

	# Check if there should be progress
	if competing.length is 1
		# Team will capture the flag
		activeTeam = competing[0]
		percentage = beacon.peek 'percentage'
		if activeTeam isnt owner
			beacon.set 'nextOwner', activeTeam
			if owner is -1
				# Capturing
				log "[updateBeaconStatus] Team #{activeTeam} is capturing beacon #{beacon.key()}"
				beacon.set 'actionStarted', new Date()/1000
				beacon.set 'action', 'capture'
				# Set timer for capturing
				Timer.set (100-percentage)*10*30, 'onCapture', {beacon: beacon.key()}
			else
				# Neutralizing
				log "[updateBeaconStatus] Team #{activeTeam} is neutralizing beacon #{beacon.key()}"
				beacon.set 'actionStarted', new Date()/1000
				beacon.set 'action', 'neutralize'
				Timer.set percentage*10*30, 'onNeutralize', {beacon: beacon.key()}
		else if parseInt(percentage) isnt 100 and parseInt(activeTeam) is parseInt(owner)
			# Re-capture (get percentage back to 100)
			log "[updateBeaconStatus] Team #{activeTeam} is recapturing beacon #{beacon.key()}"
			beacon.set 'nextOwner', activeTeam
			beacon.set 'actionStarted', new Date()/1000
			beacon.set 'action', 'recapture'
			# Set timer for capturing
			Timer.set (100-percentage)*10*30, 'onReCapture', {beacon: beacon.key()}
		else
			beacon.set 'actionStarted', new Date()/1000
			beacon.set 'action', 'none'
			#log "[checkinLocation] Active team already has the beacon, #{activeTeam}=#{owner}"
	else
		# No progess, stand-off
		beacon.set 'actionStarted', new Date()/1000
		if competing.length > 1 and inRangeCount > 0
			beacon.set 'action', 'competing'
			log "[updateBeaconStatus] Capture of beacon #{beacon.key()} on hold, competing teams: #{competing}"
		else
			beacon.set 'action', 'none'
			log "[updateBeaconStatus] Capture of beacon #{beacon.key()} stopped, left the area"



#==================== Functions called by timers ====================
#Function called when the game ends
exports.endGame = (args) !->
	if Db.shared.peek('gameState') is 1
		# Cancel timers
		Db.shared.iterate 'game', 'beacons', (beacon) !->
			Timer.cancel 'onCapture', {beacon: beacon.key()}
			Timer.cancel 'onNeutralize', {beacon: beacon.key()}
			Timer.cancel 'overtimeScore', {beacon: beacon.key()}
		# Set winning team
		winningTeam = getFirstTeam()
		Db.shared.set('game', 'firstTeam', winningTeam)
		# End game and activate end game screen
		Db.shared.set 'gameState', 2
		log "[endGame] The game ended! gameState: #{Db.shared.peek('gameState')}, args: #{JSON.stringify(args)},  winningTeam: #{winningTeam}"
		# Event
		addEvent {
			timestamp: new Date()/1000
			type: "end"
		}
		# Pushbericht winnaar en verliezer
		pushToTeam(winningTeam, "Congratulations! Your team won the game!")
		pushToRest(winningTeam, "You lost the game!")
	else
		log "[endGame] called in gameState no 1"

# Called by the beacon capture timer
# args.beacon: beacon key
exports.onCapture = (args) !->
	beacon = Db.shared.ref 'game', 'beacons', args.beacon
	nextOwner = beacon.peek('nextOwner')
	inRangeOfTeam = getInrangePlayersOfTeamArray(args.beacon, nextOwner)
	inRangeOfTeamString = getInrangePlayersOfTeam(args.beacon, nextOwner)
	log "[onCapture] Team #{nextOwner} has captured beacon #{beacon.key()}, inRange players of team: #{inRangeOfTeam}"
	beacon.set 'percentage', 100
	beacon.set 'owner', nextOwner
	beacon.set 'actionStarted', new Date()/1000
	beacon.set 'action', 'none'

	# Set a timer to gain teamscore overtime
	Timer.set Config.beaconPointsTime, 'overtimeScore', {beacon: beacon.key()}

	# The game will end in 1 hour if all the beacons are captured by one team
	capOwner = Db.shared.peek('game', 'beacons', '0', 'owner')
	allBeaconsCaptured = true
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		if capOwner isnt beacon.peek('owner')
			allBeaconsCaptured = false
	endTime = Db.shared.peek('game', 'endTime')
	# Handle push notifications and modify endTime, if needed
	if allBeaconsCaptured and endTime-App.time()>(Config.beaconPointsTime/1000)
		end = App.time() + Config.beaconPointsTime/1000 #in seconds
		Db.shared.set 'game', 'newEndTime', end
		Timer.cancel 'endGame', {}
		Timer.set Config.beaconPointsTime, 'endGame', {}
		# Add event log entrie(s)
		addEvent {
			timestamp: new Date()/1000
			type: "captureAll"
			beacon: beacon.key()
			conqueror: nextOwner
			members: inRangeOfTeamString
		}
		# Notifications
		pushToTeam(nextOwner, "Your team captured all beacons! Hold for one hour and you will win this game!")
		pushToRest(nextOwner, "Team " + Db.shared.peek('colors', nextOwner, 'name') + " has captured all beacons, you have 1 hour to conquer a beacon!")
	else
		# Add event log entrie(s)
		addEvent {
			timestamp: new Date()/1000
			type: "capture"
			beacon: beacon.key()
			conqueror: nextOwner
			members: inRangeOfTeamString
		}
		# Notifications
		pushToTeam(nextOwner, "Your team captured a beacon!")
		pushToRest(nextOwner, Shared.userStringToFriendly(inRangeOfTeamString) + " of team " + Db.shared.peek('colors', nextOwner , 'name') + " captured a beacon")

	# Give 1 person of the team the individual points
	modifyScore inRangeOfTeam[0], beacon.peek('captureValue')

	# Increment captures per team and per capturer
	for player in inRangeOfTeam
		Db.shared.modify 'game', 'teams', Shared.getTeamOfUser(player) , 'users', player, 'captured', (v) -> v+1
	Db.shared.modify 'game', 'teams', nextOwner, 'captured', (v) -> v+1
    # Modify beacon value
	beacon.modify 'captureValue', (v) ->
		if (v - Config.beaconValueDecrease)>=Config.beaconValueMinimum
			return v - Config.beaconValueDecrease
		else
			return Config.beaconValueMinimum

# Called by the beacon recapture timer
# args.beacon: beacon key
exports.onReCapture = (args) !->
	beacon = Db.shared.ref 'game', 'beacons', args.beacon
	inRangeOfTeam = getInrangePlayersOfTeamArray(args.beacon, beacon.peek('owner'))
	log "[onCapture] Team #{beacon.peek('owner')} has recaptured beacon #{beacon.key()}, inRange players of team: #{inRangeOfTeam}"
	beacon.set 'percentage', 100
	beacon.set 'actionStarted', new Date()/1000
	beacon.set 'action', 'none'

# Called by the beacon neutralize timer
# args.beacon: beacon that is neutralized
exports.onNeutralize = (args) !->
	beacon = Db.shared.ref 'game', 'beacons', args.beacon
	neutralizer = beacon.peek('nextOwner')
	inRangeOfTeam = getInrangePlayersOfTeamArray(args.beacon, neutralizer)
	log "[onNeutralize] Team #{neutralizer} has neutralized beacon #{beacon.key()}, players: #{inRangeOfTeam}"
	beacon.set 'percentage', 0
	beacon.set 'owner', -1

	#cancel gain teamscore overtime
	Timer.cancel 'overtimeScore', {beacon: beacon.key()}

	#Call the timer to reset the time in the correct endtime in the database
	end = Db.shared.peek 'game', 'endTime'
	if Db.shared.peek('game', 'newEndTime') isnt 0
		Db.shared.set 'game', 'newEndTime', 0
		Timer.cancel 'endGame', {}
		Timer.set (end-App.time())*1000, 'endGame', {}
		# Cancel event
		addEvent {
			timestamp: new Date()/1000
			type: "cancel"
		}

	# Increment neutralizes per team and per capturer
	for player in inRangeOfTeam
		Db.shared.modify 'game', 'teams', Shared.getTeamOfUser(player), 'users', player, 'neutralized', (v) -> v+1
	Db.shared.modify 'game', 'teams', neutralizer, 'neutralized', (v) -> v+1

	# Handle capturing
	updateBeaconPercentage(beacon)
	percentage = beacon.peek 'percentage'
	log "[onNeutralize] Team #{neutralizer} is capturing beacon #{beacon.key()} (after neutralize)"

	beacon.set 'action', 'capture'
	beacon.set 'actionStarted', new Date()/1000
	# Set timer for capturing
	Timer.set (100-percentage)*10*30, 'onCapture', args

# Modify teamscore for possessing a beacon for a certain amount of time
# args.beacon: beacon that is getting points
exports.overtimeScore = (args) !->
	owner = Db.shared.peek 'game', 'beacons',  args.beacon, 'owner'
	Db.shared.modify 'game', 'teams', owner, 'teamScore', (v) -> v + Config.beaconHoldScore
	checkNewLead() # check for a new leading team
	Timer.set Config.beaconPointsTime, 'overtimeScore', args # Every hour

# Called when an inRange players did not checkin quickly enough
# args.beacon: beacon id
# args.client: user id
exports.inRangeTimeout = (args) !->
	log "[inRangeTimeout] #{member(args.client)} removed from inRange of beacon #{args.beacon}"
	Db.shared.remove 'game', 'beacons', args.beacon, 'inRange', args.client
	updateBeaconStatus(Db.shared.ref('game', 'beacons', args.beacon), -999)


# ==================== Functions ====================
# Get a string of the players that are inRange of a beacon
getInrangePlayers = (beacon) ->
	playersStr = undefined;
	Db.shared.iterate 'game', 'beacons', beacon, 'inRange', (player) !->
		if playersStr?
			playersStr = playersStr + ', ' + player.key()
		else
			playersStr = player.key()
	return playersStr

# Get a string of the players that are inRange of a beacon of a specific team
getInrangePlayersOfTeam = (beacon, team) ->
	playersStr = undefined;
	Db.shared.iterate 'game', 'beacons', beacon, 'inRange', (player) !->
		if parseInt(Shared.getTeamOfUser(player.key())) is parseInt(team)
			if playersStr?
				playersStr = playersStr + ', ' + player.key()
			else
				playersStr = player.key()
	return playersStr

# Get an array of the players that are inRange of a beacon of a specific team
getInrangePlayersOfTeamArray = (beacon, team) ->
	players = [];
	Db.shared.iterate 'game', 'beacons', beacon, 'inRange', (player) !->
		if parseInt(Shared.getTeamOfUser(player.key())) is parseInt(team)
			players.push(player.key())
	return players



# Update the rankings of teams depending on their score
updateTeamRankings = !->
	teamScores = []
	Db.shared.iterate 'game', 'teams', (team) !->
		teamScores.push {team: team.key(), score: getTeamScore(team.key())}
	teamScores.sort((a, b) -> return parseInt(b.score)-parseInt(a.score))
	# Using same ranking number for multiple teams if scores are the same
	ranking = 0
	same = 0
	lastScore = -1
	for teamObject in teamScores
		if lastScore is teamObject.score
			same++
		else
			ranking+=same
			ranking++
		Db.shared.set 'game', 'teams', teamObject.team, 'ranking', ranking
		lastScore = teamObject.score

# Get the score of a team
getTeamScore = (team) ->
	result = Db.shared.peek 'game', 'teams', team, 'teamScore'
	Db.shared.iterate 'game', 'teams', team, 'users', (user) !->
		result += user.peek('userScore')
	return result

# Setup an empty game
initializeGame = !->
	# Stop all timers from the previous game
	Timer.cancel 'endGame', {}
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		Timer.cancel 'onCapture', {beacon: beacon.key()}
		Timer.cancel 'onNeutralize', {beacon: beacon.key()}
		Timer.cancel 'overtimeScore', {beacon: beacon.key()}
		beacon.iterate 'inRange', (client) !->
			Timer.cancel 'inRangeTimeout', {beacon: beacon.key(), client: client.key()}
	# Reset database to defaults
	Db.shared.set 'game', {}
	Db.shared.set 'game', 'numberOfTeams', 2
	Db.shared.set 'game', 'beaconRadius', 200
	Db.shared.set 'game', 'roundTimeUnit', 'Days'
	Db.shared.set 'game', 'roundTimeNumber', 7
	Db.shared.set 'game', 'eventlist', 'maxId', 0
	Db.shared.set 'game', 'firstTeam', -1

	Db.shared.set 'gameState', 0
	Db.shared.modify 'gameNumber', (v) -> (0||v)+1

# Game timer
setTimer = !->
	if Db.shared.peek('game', 'roundTimeUnit') is 'Months'
		seconds = Db.shared.peek('game', 'roundTimeNumber')*2592000
	else if Db.shared.peek('game', 'roundTimeUnit') is 'Days'
		seconds = Db.shared.peek('game', 'roundTimeNumber')*86400
	else if Db.shared.peek('game', 'roundTimeUnit') is 'Hours'
		seconds = Db.shared.peek('game', 'roundTimeNumber')*3600
	end = App.time()+seconds #in seconds
	Db.shared.set 'game', 'endTime', end
	Db.shared.set 'game', 'newEndTime', 0
	Timer.cancel 'endGame', {}
	Timer.set seconds*1000, 'endGame', {} #endGame is the function called when the timer ends

# https://stackoverflow.com/questions/27928/calculate-distance-between-two-latitude-longitude-points-haversine-formula
distance = (latlong1, latlong2) ->
	[lat1,lon1] = latlong1.split(',')
	[lat2, lon2] = latlong2.split(',')
	R = 6371000; # Radius of the earth in m
	dLat = deg2rad(lat2-lat1)
	dLon = deg2rad(lon2-lon1)
	a =
		Math.sin(dLat/2) * Math.sin(dLat/2) +
		Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
		Math.sin(dLon/2) * Math.sin(dLon/2)
	c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
	d = R * c # Distance in m
	return d

deg2rad = (degrees) ->
	degrees * (3.141592653589793/180)

# Returns team with the highest score
getFirstTeam = ->
	teamMax = -1
	maxScore = -1
	Db.shared.iterate 'game', 'teams', (team) !->
		if maxScore < team.peek('teamScore')
			teamMax = team.key()
			maxScore = team.peek('teamScore')
	#log "[getFirstTeam] teamMax: " + teamMax
	return teamMax

# Modify user and team scores by adding "points" to the current value
modifyScore = (client, points) !->
	teamClient = Shared.getTeamOfUser(client)
	log "[modifyScore] client: #{client}, team: #{teamClient}, points: #{points}"
	if not(teamClient?) or parseInt(teamClient) is -1
		log "[modifyScore] WARNING: team is undefined/-1! Stopping modifyScore()"
		return
	# modify user- and team scores
	Db.shared.modify 'game', 'teams', teamClient, 'users', client, 'userScore', (v) -> v + points
	Db.shared.modify 'game', 'teams', teamClient, 'teamScore', (v) -> v + points
	# new lead check
	checkNewLead(teamClient)

refreshInrangeTimer = (client, device) !->
	#log '[refreshInRangeTimer] Refreshing timer for '+App.userName(client)+' ('+client+') on device '+device
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		beacon.iterate 'inRange', (user) !->
			if parseInt(user.key(),10) is parseInt(client,10) and parseInt(user.peek('device'),10) is parseInt(device,10)
				#log 'Resetting timeout'
				user.set 'time', new Date()/1000
				Timer.cancel 'inRangeTimeout', {beacon: beacon.key(), client: client}
				Timer.set Config.inRangeKickTime*1000, 'inRangeTimeout', {beacon: beacon.key(), client: client}

# function called everytime scores are modified to check wheter there is a new leading team or not
checkNewLead = !->
	teamMax = getFirstTeam()
	newLead = false;
	newLead = teamMax isnt Db.shared.peek('game', 'firstTeam')
	# create score event
	# To Do: personalize for team members or dubed players
	if newLead
		log "[checkNewLead] newLead: " + newLead + " "
		addEvent {
			timestamp: new Date()/1000
			type: "score"
			leading: teamMax
		}
		Db.shared.set 'game', 'firstTeam', teamMax # store firstTeam for next new team calculation
		pushToTeam(teamMax, "Your team took the lead!")
		pushToRest(teamMax, "Team " + Db.shared.peek('colors', teamMax, 'name') + " took the lead!")
	# Update rankings
	updateTeamRankings()

# Adds event to the eventlist
addEvent = (eventArgs) !->
	maxId = Db.shared.peek('game', 'eventlist', 'maxId')
	log "[addEvent] Event: " + eventArgs.type + " id: " + maxId
	Db.shared.set 'game', 'eventlist', maxId, eventArgs
	Db.shared.modify 'game', 'eventlist', 'maxId', (v) -> v + 1

# Sends a push notification, message, to all team members
pushToTeam = (teamId, message) !->
	members = []
	Db.shared.iterate 'game', 'teams', teamId, 'users', (teamMember) !->
		members.push(teamMember.key())
	Event.create
    	unit: 'toTeam'
    	include: members
    	text: message
    	path: ['log']

# Sends a push notification, message, to all players not in team, teamId
pushToRest = (teamId, message) !->
	members = []
	Db.shared.iterate 'game', 'teams', teamId, 'users', (teamMember) !->
		members.push(teamMember.key())
	Event.create
    	unit: 'toRest'
    	exclude: members
    	text: message
    	path: ['log']

#Move all data to history tab
moveData = !->
	if not (Db.backend.peek('history', 'groupCode')?)
		Db.backend.set 'history', 'groupCode', App.groupCode()
	if not (Db.backend.peek('history', 'players')?)
		Db.backend.set 'history', 'players', App.userIds().length
	current = Db.shared.peek('gameNumber')
	if current? and parseInt(Db.shared.peek('game', 'gameState')) isnt 0
		Db.backend.set 'history', current,'game', Db.shared.peek('game')
		Db.backend.set 'history', current, 'gameState', Db.shared.peek('gameState')


################## STATS COLLECTION
# Check response on http request and set registered to true
exports.response = !->
	log '[response] registered to data plugin'
	Db.backend.set('collectionRegistered', 'true')

# When http with correct key is recieved database is send
exports.onHttp = (request) !->
	if request.data?
		if MD5.externmd5(request.data) is Config.onHTTPKey
			moveData()
			request.respond 200, JSON.stringify(Db.backend.peek('history'))
			log '[onHTTP] succesfully sent database, id='+App.groupCode()
			return 0
	request.respond 200, 'wrong key'
	log '[onHTTP] failed attempt to sent database'

# Called when plugin is installed. This function sends request to data collection App.
registerPlugin = !->
	if !(Db.backend.peek('collectionRegistered')?)
		Http.post
			url: 'https://happening.im/x/2489x'
			data: App.groupCode()
			name: 'response'