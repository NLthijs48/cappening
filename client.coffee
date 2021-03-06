Shared = require 'shared'
Config = Shared.config()
member = Shared.member()
Events = require 'events'
Ranking = require 'ranking'
tr = I18n.tr

showPopupO = Obs.create() # Beacon key or -1 for user popup
Obs.observe !->
	if (sPopup = Db.local?.get('switchToPopup'))?
		showPopupO.set sPopup
		Db.local.remove 'switchToPopup'
tapFunction = undefined
longTapFunction = undefined

# =============== Events ===============
# Main function, called when plugin is started
exports.render = !->
	log 'FULL RENDER'
	Obs.onClean !->
		log 'FULL CLEAN'
	# Compatibility check
	if (version = App.agent().android)? and version < 3.0
		Dom.text 'Sorry this game is unavailable for android version 2.3 or lower'
		log "Unsupported Android version: "+version
		return

	# Check if cleanup from last game is required
	Obs.observe !->
		local = Db.local.peek 'gameNumber'
		remote = Db.shared.get 'gameNumber'
		log 'Game cleanup checked, local=', local, ', remote=', remote
		if !local? || local isnt remote
			log ' Cleanup performed'
			Db.local.set 'gameNumber', remote
			# Do cleanup stuff
			Db.local.remove 'currentSetupPage'

	# Display correct page
	Obs.observe !->
		if Db.shared.get('gameState') is 0
			homePage()
			return
		page = Page.state.get(0)
		if page is "scores"
			Ranking.render()
		else if page is "log"
			Events.render()
		else
			homePage()

	# Make sure this device has a unique id
	Obs.observe !->
		deviceId = Db.local.peek 'deviceId'
		if not deviceId?
			result = Obs.create(null)
			Server.send 'getNewDeviceId', result.func()
			Obs.observe !->
				if result.get()?
					log 'Got deviceId ' + result.get()
					Db.local.set 'deviceId', result.get()
				else
					log 'Waiting for deviceId from the server'


# Render info page (gear/info icon in top bar)
exports.renderInfo = !->
	Dom.div !->
		Dom.style marginBottom: '-10px'
	Markdown.render """
	On the main map there are several beacons. You need to venture to the real location of a beacon to conquer it.
	When you get in range of the beacon, you'll automatically start to conquer it.
	When the bar at the top of your screen has been filled with your team color, you've conquered the beacon.
	A neutral beacon will take 30 seconds to conquer, but an occupied beacon will take one minute. You first need to drain the opponents' color, before you can fill it with yours!
	"""

	Dom.h2 !->
		Dom.style marginBottom: '-10px'
		Dom.text tr('Rewards and winning')
	Markdown.render """
	You gain #{Config.beaconValueInitial} #{if Config.beaconValueInitial is 1 then "point" else "points"} for being the first team to conquer a certain beacon.
	Beacons that are in possession of your team, will have a circle around it in your team color.
	Every hour the beacon is in your posession, it will generate #{Config.beaconHoldScore} #{if Config.beaconHoldScore is 1 then "point" else "points"}.
	Unfortunately for you, your beacons can be conquered by other teams.
	Every time a beacon is conquered the value of the beacon will drop. Scores for conquering a beacon will decrease with #{Config.beaconValueDecrease} until a minimum of #{Config.beaconValueMinimum}.
	The team with the highest score at the end of the game wins.
	If a team captures all beacons, the game will end quickly if the other teams stay inactive.
	"""

	Dom.h2 !->
		Dom.style marginBottom: '-10px'
		Dom.text tr('Bugs and help')
	Markdown.render """
	Did you find a bug in the plugin? Do you have a question about the plugin that you cannot find the answer for? Contact 'thijs17' and we will try to answer you.
	If you are familiar with GitHub then you can also report the bug on our [GitHub repository](https://github.com/VincentSmit/cappening/issues).
	"""

# Method that is called when admin changes settings (only restart game for now)
exports.renderSettings = !->
	if Db.shared
		Form.check
			name: 'restart'
			text: tr 'Restart the game'
			sub: tr 'Check this to destroy the current game and start a new one.'


# =============== Content fuctions ===============
#Method that renders bar on top of page.
renderNavigationBar = !->
	log "renderNavigationBar()"
	addBar
		top: true
		order: 10
		content: !->
			Dom.style
				Box: 'horizontal'
				height: "50px"
				boxShadow: "0 3px 10px 0 rgba(0, 0, 0, 0.3)"
				backgroundColor: hexToRGBA(Config.teams[Shared.getTeamOfUser(App.userId())].hex, 0.9)
				_textShadow: '0 0 5px #000000, 0 0 5px #000000'
			Dom.css
				'.bar-button:last-of-type':
					borderRight: '0 none !important'
				'.bar-button:hover':
					backgroundColor:'rgba(0, 0, 0, 0.1) !important'
				'.bar-button:active':
					backgroundColor: 'rgba(0,0,0,0.2) !important'
			renderButton = (content) !->
				Dom.div !->
					Dom.style
						height: '100%'
						color: 'white'
						borderRight: '2px solid rgba(255,255,255,0.3)'
						backgroundColor: 'transparent'
						Flex: true
						Box: 'middle center'
					Dom.cls 'bar-button'
					content?()
	        # Button to event log
			renderButton !->
				Icon.render data: 'clipboard', color: '#fff', size: 30, style: {verticalAlign: 'middle'}
				Dom.div !->
					Dom.text 'Events'
					Dom.style verticalAlign: 'middle', display: 'inline-block', marginLeft: '5px', fontSize: '13px'
				Event.renderBubble ['log']
				Dom.onTap !->
					Page.nav 'log'
			# Button to scores page
			renderButton !->
				Dom.div !->
					Dom.style
						width: '29px'
						height: '30px'
						verticalAlign: 'middle'
						display: 'inline-block'
						background: "url(#{App.resourceUri('ranking.png')})"
						backgroundRepeat: "no-repeat"
						backgroundPosition: "0 0"
						backgroundSize: "26px 26px"
				Dom.div !->
					Dom.text 'Ranking'
					Dom.style verticalAlign: 'middle', display: 'inline-block', marginLeft: '5px', fontSize: '13px'
				Dom.onTap !->
					Page.nav 'scores'

# Location sharing bar
renderLocationSharing = !->
	Obs.observe !->
		if !Geoloc.isSubscribed()
			addBar
				top: true
				order: 20
				content: !->
					Dom.style
						width: "100%"
						color: '#666'
						padding: '0'
						fontSize: '16px'
						boxSizing: 'border-box'
						backgroundColor: '#FFF'
						_alignItems: 'center'
						borderBottom: '1px solid #ccc'
					Dom.div !->
						Dom.style
							Box: 'horizontal', backgroundColor: '#BA1A6E', color: '#fff'
						Dom.div !->
							Dom.style padding: "13px"
							Icon.render data: 'map', color: '#fff', style: {position: "static", margin: "0"}, size: 24
						Dom.div !->
							Dom.style
								Flex: true
								padding: "8px 0 5px 0"
							Dom.text tr('Tap to use your location')
							Dom.div !->
								Dom.style
									fontSize: "75%"
								Dom.text tr('Currently you cannot participate in the game')
					Dom.onTap !->
						Geoloc.subscribe()

#Renders the progress bar when a capture is happening
addProgressBar = !->
	addBar
		top: true
		order: 0
		content: !->
			Db.shared.iterate 'game', 'beacons', (beacon) !->
				action = beacon.get('action')
				inRangeValue = beacon.get('inRange', App.userId(), 'device')
				if inRangeValue? and (inRangeValue is 'true' || inRangeValue is Db.local.get('deviceId'))
					dbPercentage = beacon.peek("percentage")
					nextPercentage = -1
					ownTeam = Shared.getTeamOfUser(App.userId())
					nextColor = ''
					owner = beacon.peek('owner')
					nextOwner = beacon.peek('nextOwner')
					actionStarted = beacon.peek("actionStarted")
					barText = ''
					if action is 'none'
						return
					else if action is "capture"
						nextPercentage=100
						dbPercentage += (new Date() /1000 -actionStarted)/30 * 100
						if dbPercentage > 100
							dbPercentage = 100
						if dbPercentage < 0
							dbPercentage = 0
						nextColor = Config.teams[nextOwner].hex
						barText = "Capturing..."
					else if action is "recapture"
						nextPercentage=100
						dbPercentage += (new Date() /1000 -actionStarted)/30 * 100
						if dbPercentage > 100
							dbPercentage = 100
						if dbPercentage < 0
							dbPercentage = 0
						nextColor = Config.teams[owner].hex
						if parseInt(ownTeam) is parseInt(owner)
							barText = "Recapturing..."
						else
							barText = "Enemy is recapturing..."
					else if action is "neutralize"
						nextPercentage=0
						dbPercentage -= (new Date() /1000 -actionStarted)/30 * 100
						if dbPercentage < 0
							dbPercentage = 0
						if dbPercentage > 100
							dbPercentage = 100
						nextColor = Config.teams[owner].hex
						barText = "Neutralizing..."
					else if action is "competing"
						if owner is -1
							nextColor = Config.teams[nextOwner].hex
						else
							nextColor = Config.teams[owner].hex
						fromOtherTeams = 0
						log 'fromOtherTeams='+fromOtherTeams+', nextPercentage='+nextPercentage+', dbPercentage='+dbPercentage
						nextPercentage = dbPercentage
						beacon.iterate 'inRange', (player) !->
							if Shared.getTeamOfUser(player.key()) isnt ownTeam
								fromOtherTeams++
						if dbPercentage is 100 and owner is nextOwner
							if parseInt(ownTeam) is parseInt(owner)
								if fromOtherTeams > 1
									barText = "Captured, but an enemy in range!"
								else
									barText = "Captured, but enemies in range!"
							else
								if fromOtherTeams > 1
									barText = "Enemies are blocking the neutralize!"
								else
									barText = "An enemy is blocking the neutralize!"
						else
							if parseInt(owner) isnt -1
								if parseInt(ownTeam) is parseInt(owner)
									if fromOtherTeams > 1
										barText = "Preventing neutralize by the enemies!"
									else
										barText = "Preventing neutralize by an enemy!"
								else
									if fromOtherTeams > 1
										barText = "Enemies are preventing the neutralize!"
									else
										barText = "An enemy is preventing the neutralize!"
							else
								if parseInt(ownTeam) is parseInt(nextOwner)
									if fromOtherTeams > 1
										barText = "Enemies are preventing the capture!"
									else
										barText = "An enemy is preventing the capture!"
								else
									if fromOtherTeams > 1
										barText = "Preventing capture by the enemies!"
									else
										barText = "Preventing capture by an enemy!"
					else
						nextPercentage = dbPercentage
						if owner is -1
							nextColor = Config.teams[nextOwner].hex
						else
							nextColor = Config.teams[owner].hex
						barText = "Captured"
					time = 0
					if nextPercentage isnt dbPercentage
						time = Math.abs(dbPercentage-nextPercentage) * 300
					log "nextPercentage = ", nextPercentage, ", dbPercentage = ", dbPercentage, ", time = ", time, ", action = ", action, "actionStarted=", actionStarted
					Dom.style
						height: "25px"
						width: "100%"
						boxShadow: 'rgba(0, 0, 0, 0.6) 0px 2px 6px 0px'
						backgroundColor: 'rgba(0, 0, 0, 0.3)'
						border: '0'
					Dom.div !->
						Dom.style
							height: "25px"
							background_: 'linear-gradient(to bottom,  rgba(0,0,0,0) 0%,rgba(0,0,0,0.3) 100%)'
							backgroundColor: nextColor
							zIndex: "10"
							width: "#{dbPercentage}%"
							transition: "width #{time}ms linear"
						# After initial width is set, set the width to transition to
						element = Dom.get()
						Obs.onTime 0, !->
							element.style width: "#{nextPercentage}%"
					Dom.div !->
						Dom.text barText
						Dom.style
							width: '100%'
							color: 'white'
							marginTop: '-22px'
							textAlign: 'center'
							fontSize: '15px'
							_textShadow: '0 0 5px #000000, 0 0 5px #000000' # Double for extra visibility

#Renders bar when game is ended. Displays the winner and admin can restart the game
renderEndGameBar = !->
	addBar
		top: false
		order: 10
		content: !->
			Dom.style
				Box: 'horizontal'
				padding: "7px 5px 7px 10px"
				fontSize: '16px'
				color: 'white'
				_textShadow: '0 0 5px #000000, 0 0 5px #000000'
				marginBottom: '30px'
				_alignItems: 'center'
				backgroundColor: hexToRGBA(Config.teams[Db.shared.peek('game', 'firstTeam')].hex, 0.9)
			Dom.div !->
				Dom.style Flex: true
				if parseInt(Db.shared.peek('game', 'firstTeam')) is parseInt(Shared.getTeamOfUser(App.userId()))
					Dom.text "Your team won the game!"
				else
					Dom.text "Team " + Config.teams[Db.shared.peek('game', 'firstTeam')].name + " won, good luck next round!"
			if App.userIsAdmin()
				Dom.div !->
					Dom.style
						height: "36px"
					Dom.div !->
						Dom.cls 'restartButton' # hover effect
						Dom.css
							'.restartButton:hover':
								backgroundColor: '#A71963 !important'
							'.restartButton:active':
								backgroundColor: '#80134C !important'
						Dom.style
							backgroundColor: '#ba1a6e'
							padding: '8px'
							textAlign: 'center'
							color: 'white'
							lineHeight: '20px'
							_boxShadow: '0 0 3px rgba(0,0,0,0.5)'
							textTransform: 'uppercase'
						Dom.text "Restart game"
						Dom.onTap !->
							Server.call 'restartGame'


renderSetupGuidance = !->
	addBar
		top: true
		order: 10
		content: !->
			Dom.style
				Box: 'horizontal middle'
				backgroundColor: '#FFF'
				padding: '3px'
				borderBottom: '1px solid #ccc'
			Dom.div !->
				Dom.style
					Flex: true
					fontSize: '18px'
					textAlign: 'center'
				if !App.userIsAdmin()
					Dom.text 'The admin is setting up a new game!'
					return
				Dom.text tr("Place beacons by %1 the map", (if App.agent().ios?||App.agent().android? then 'tapping' else 'clicking'))
			if App.userIsAdmin()
				canStart = Obs.create false
				Obs.observe !->
					log 'count='+Db.shared.count('game', 'beacons').get()
					canStart.set (Db.shared.count('game', 'beacons').get() > 0)
				Ui.button !->
					Dom.text 'Start game'
					if canStart.get()
						Dom.style background: '', color: '', border: 'solid 1px transparent'
						Dom.onTap !->
							Server.send 'startGame'
					else
						Dom.style
							background: '#f4f4f4'
							color: '#666'
							border: 'solid 1px #666'
						Dom.onTap !->
							Modal.show 'First place some beacons, ten or more is recommended'


renderSetupOptions = !->
	addBar
		top: false
		order: -10
		content: !->
			Dom.style paddingRight: '10px'
			renderButton = (content) !->
				Dom.div !->
					Dom.style
						display: 'inline-block'
						backgroundColor: if App.userIsAdmin()  then '#ba1a6e' else '#666'
						padding: '8px 12px'
						margin: '0 0 10px 10px'
						fontSize: '17px'
						color: '#FFF'
						borderRadius: '3px'
					content?()
			# Number of teams
			renderButton !->
				Dom.text (Db.shared.get('game', 'numberOfTeams') ? 2) + ' teams'
				Dom.onTap !->
					if !App.userIsAdmin()
						Modal.show 'Number of teams', 'The admin can change this setting'
						return
					if App.users.count().peek() <= 2
						Modal.show "You cannot use more teams since you don't have enough people in your group"
						return
					Modal.show
						title: 'Select number of teams'
						buttons: false
						content: !->
							maxTeams = Math.max(2, Math.min(6, App.users.count().get()))
							renderOption = (count) !->
								Ui.option
									content: count + ' teams'
									onTap: !->
										Server.sync 'setTeams', count, !->
											Db.shared.set 'game', 'numberOfTeams', count
							for count in [2..maxTeams]
								renderOption count
			# Length
			renderButton !->
				Dom.text (Db.shared.get('game', 'roundTimeNumber') ? 7) + ' ' + (Db.shared.get('game', 'roundTimeUnit') ? 'days').toLowerCase()
				Dom.onTap !->
					if !App.userIsAdmin()
						Modal.show 'Duration of the game', 'The admin can change this setting'
						return
					roundTimeNumber = Obs.create Db.shared.peek('game', 'roundTimeNumber')
					roundTimeUnit = Obs.create Db.shared.peek('game', 'roundTimeUnit')
					Modal.show
						title: 'Select round duration'
						content: !->
							# Duration input
							Dom.div !->
								Dom.style maxWidth: '250px', paddingBottom: '10px'
								Dom.text 'After this time the game will determine the winning team'
							Dom.div !->
								Dom.style
									height: '81px'
									Box: 'middle center'
								sanitize = (value) ->
									if value < 1
										return 1
									else if value > 999
										return 999
									else
										return value
								renderArrow = (direction) !->
									Dom.div !->
										Dom.style
											width: 0
											height: 0
											margin: '0 auto'
											borderStyle: "solid"
											borderWidth: "#{if direction>0 then 0 else 20}px 20px #{if direction>0 then 20 else 0}px 20px"
											borderColor: "#{if roundTimeNumber.get()<=1 then 'transparent' else '#ba1a6e'} transparent #{if roundTimeNumber.get()>=999 then 'transparent' else '#ba1a6e'} transparent"
										if (direction>0 and roundTimeNumber.get()<999) or (direction<0 and roundTimeNumber.get()>1)
											Dom.onTap !->
												roundTimeNumber.set sanitize(roundTimeNumber.peek()+direction)
								# Number input
								Dom.div !->
									Dom.style margin: '0 10px 0 0', width: '51px', float: 'left'
									renderArrow 1
									Dom.input !->
										inputElement = Dom.get()
										Dom.prop
											size: 2
											value: roundTimeNumber.get()
										Dom.style
											fontFamily: 'monospace'
											fontSize: '30px'
											fontWeight: 'bold'
											textAlign: 'center'
											border: 'inherit'
											backgroundColor: 'inherit'
											color: 'inherit'
										Dom.on 'input change', !-> roundTimeNumber.set sanitize(inputElement.value())
										Dom.on 'click', !-> inputElement.select()
									renderArrow -1
								# Unit inputs
								Form.segmented
									name: 'timeUnit'
									value: roundTimeUnit.peek() ? 'Days'
									segments: ['Hours', 'Hours', 'Days', 'Days', 'Months', 'Months']
									onChange: (value) !-> roundTimeUnit.set(value)
						cb: !->
							Server.sync 'setRoundTime', roundTimeNumber.peek(), roundTimeUnit.peek(), !->
								Db.shared.set 'game', 'roundTimeNumber', roundTimeNumber.peek()
								Db.shared.set 'game', 'roundTimeUnit', roundTimeUnit.peek()


# Home page with map
homePage = !->
	log 'homePage()'
	Dom.style
		ChildMargin: 0
	renderLocationSharing()
	map = renderMap()
	Obs.observe !->
		if (gameState = Db.shared.get("gameState")) is 0
			renderSetupGuidance()
			renderSetupOptions()
			renderBeacons map
			renderAddBeacons map
			Page.setTitle 'Setting up the game'
		else if gameState is 1
			renderNavigationBar()
			addProgressBar()
			performTutorial()
			renderBeacons map

			nEnd = Db.shared.get('game', 'newEndTime')
			end = Db.shared.get('game', 'endTime')
			if nEnd? and nEnd isnt 0
				end = nEnd
			Page.setTitle !->
				Time.deltaText end, "default", (value) !->
					Dom.text "Conquest has "+value.replace("in ", '')+" left"
				if (end - App.time()) < 3600
					Dom.text "!"
		else if gameState is 2
			renderNavigationBar()
			renderEndGameBar()
			renderBeacons map

			Page.setTitle !->
				if Db.shared.peek("game", "firstTeam") is Shared.getTeamOfUser(App.userId())
					Dom.text "Your team won!"
				else
					Dom.text "Your team lost!"
	renderBars()

# Show tutorial info if the user has not seen that yet
performTutorial = !->
	#Tutorial for playing this game the first time
	tutorial = Db.personal.peek('tutorialState', 'mainContent')
	if !tutorial?
		Modal.show tr("Are you ready to capture your first beacon?"), !->
			Dom.div tr("Walk towards the indicated area's on the map to capture a beacon.")
			Dom.div tr("You will be awarded points for capturing a beacon, and for holding it.")
			Dom.div tr("Tip: Capture all beacons with your team and win in one hour!")
		, !->
			Server.sync 'updateTutorialState', App.userId(), 'mainContent', !->
				Db.personal.set 'tutorialState', 'mainContent', 1
		, ['ok', tr("Got it")]


# =============== Map functions ===============
# Render a map
renderMap = ->
	log "renderMap()"
	Dom.style padding: "0"
	gameState = Db.shared.get 'gameState'
	restoreLocation = Db.local.peek('lastMapLocation')
	map = Map.render
		zoom: Db.local.peek('lastMapZoom') ? 12
		minZoom: 2
		clustering: true
		clusterRadius: 45
		clusterSpreadMultiplier: 2
		latlong: (restoreLocation ? "52.444553, 5.740644")
		onTap: (latlong) !->
			tapFunction?(latlong)
		onLongTap: (latlong) !->
			longTapFunction?(latlong)
	, (map) !->
		# No location stored? Show all placed beacons in the viewport
		if !restoreLocation?
			locations = []
			beacons = Db.shared.peek 'beacons'
			for number,data of beacons
				locations.push data.location
			if locations.length > 0
				map.moveInView locations, 0.2
		Obs.observe !->
			# Switch to certain coordinates
			if (sLatlong = Db.local.get 'switchToMapLocation')? and (sZoom = Db.local.get 'switchToMapZoom')?
				map.setLatlong sLatlong
				map.setZoom sZoom
				Db.local.remove 'switchToMapLocation'
				Db.local.remove 'switchToMapZoom'
			# Save location+zoom for restoring later
			Db.local.set 'lastMapLocation', map.getLatlong()
			Db.local.set 'lastMapZoom', map.getZoom()
		renderLocation map
	return map

# Add beacons to the map
renderBeacons = (map) !->
	log "renderBeacons()"
	Db.shared.iterate 'game', 'beacons', (beacon) !->
		teamNumber = beacon.get('owner') ? -1
		teamColor =  Config.teams[teamNumber].hex
		location = beacon.get 'location'
		map.marker location, !->
			Dom.style
				width: "22px"
				height: "40px"
				margin: "-40px 0 0 -11px"
			# Popup div
			Obs.observe !->
				if showPopupO.get() is beacon.key()
					if Db.shared.get('gameState') is 0
						renderPopup
							width: 120
							anchor: 'bottom'
							content: !->
								Dom.div !->
									Dom.style Box: 'horizontal middle'
									Dom.div !->
										Dom.style
											Flex: true
										Dom.text 'Remove beacon'
									Dom.div !->
										Icon.render
											data: 'cancel'
											size: 20
								Dom.onTap !->
									Server.sync 'deleteBeacon', beacon.key(), !->
										Db.shared.remove 'game', 'beacons', beacon.key()
					else
						renderPopup
							width: 170
							anchor: 'bottom'
							content: !->
								if (owner = +beacon.peek('owner')) is +Shared.getTeamOfUser(App.userId())
									Dom.text tr('Owned by your team')
									if Config.beaconHoldScore is 1
										subtext = tr('Scoring %1 point per hour while held', Config.beaconHoldScore)
									else
										subtext = tr('Scoring %1 points per hour while held', Config.beaconHoldScore)
									smallText subtext
								else if owner is -1
									Dom.text tr('Neutral beacon')
								else
									Dom.text tr('Owned by team %1', Config.teams[owner].name)
								if (owner = +beacon.peek('owner')) isnt +Shared.getTeamOfUser(App.userId())
									smallText tr('Next capture gives %1 points', beacon.peek('captureValue'))
								Obs.observe !->
									return if beacon.count('inRange').get() is 0
									Dom.div !->
										Dom.style Box: 'horizontal middle center', margin: '10px -8px 5px -8px'
										drawLine = !->
											Dom.div !->
												Dom.style
													borderBottom: '2px solid #BBB'
													Flex: true
										drawLine()
										Dom.div !->
											Dom.style padding: '0 5px', color: '#999'
											Dom.text tr('in range')
										drawLine()
									Dom.div !->
										Dom.style
											Box: 'center'
										beacon.iterate 'inRange', (playerO) !->
											Ui.avatar App.userAvatar(playerO.key()),
												onTap: !-> App.userInfo(playerO.key())
			Dom.div !->
				Dom.style
					width: "22px"
					height: "40px"
					background: "50% 100% no-repeat url("+App.resourceUri(teamColor.substring(1) + ".png")+")"
					backgroundSize: "contain"
			# Popup trigger
			Dom.onTap !->
				if showPopupO.peek() is beacon.key()
					showPopupO.set ''
				else
					showPopupO.set beacon.key()
		radius = Db.shared.get('game', 'beaconRadius')
		map.circle location, radius,
			color: teamColor
			fillColor: teamColor
			fillOpacity: 0.3
			weight: 2
			onTap: !->
				if showPopupO.peek() is beacon.key()
					showPopupO.set ''
				else
					showPopupO.set beacon.key()

# Add marker adding
renderAddBeacons = (map) !->
	tapFunction = longTapFunction = (latlong) !->
		log 'click: '+latlong
		beaconRadius = Db.shared.get('game', 'beaconRadius')
		# Check if marker is not close to other marker
		result = undefined
		Db.shared.iterate 'game', 'beacons', (beacon) !->
			if Map.distance(beacon.get('location'), latlong) < beaconRadius*2
				result = 'Beacon is too close to another beacon'
		if result?
			Modal.show(result)
		else
			Server.sync 'addMarker', latlong, !->
				number = Math.floor((Math.random() * 10000) + 200)
				Db.shared.set 'game', 'beacons', number, {location: latlong, owner: -1}
	Obs.onClean !->
		tapFunction = longTapFunction = undefined

# Render the location of the user on the map, pointer if offscreen, and check for beacon capturing
renderLocation = (map) !->
	# Marker on the map
	Obs.observe !->
		return if !Geoloc.isSubscribed()
		state = Geoloc.track()
		return if !state
		Obs.observe !->
			location = state.get('latlong')
			accuracy = state.get('accuracy')
			return if !location
			log '[renderLocation]', location
			map.marker location, !->
				Dom.style
					width: '42px'
					height: '42px'
					margin: '-21px 0 0 -21px'
					borderRadius: '50%'
				# Popup div
				Obs.observe !->
					if showPopupO.get() is -1
						renderPopup
							content: !->
								Dom.style
									whiteSpace: 'normal'
								Dom.text 'Your location'
								if (lastUpdate = state.get('time'))?
									smallText !-> Time.deltaText(lastUpdate)
				Dom.div !->
					Obs.observe !->
						if ((new Date()/1000)-state.get('time')) > 60*60 # Make old locations less visible
							Dom.style opacity: 0.7
						else
							Dom.style opacity: 1
						Ui.avatar App.userAvatar(App.userId()), size: 42
				# Popup trigger
				Dom.onTap !->
					if showPopupO.peek() is -1
						showPopupO.set ''
					else
						showPopupO.set -1
			radius = accuracy
			if radius > 1000
				radius = 1000
			onTap = undefined
			# No ontap in the setup state, otherwise you cannot place beacons there
			if (gameState = Db.shared.get("gameState")) isnt 0
				onTap = !->
					if showPopupO.peek() is -1
						showPopupO.set ''
					else
						showPopupO.set -1
			map.circle location, radius,
				color: '#FFA200'
				fillColor: '#FFA200'
				fillOpacity: 0.1
				weight: 1
				opacity: 0.3
				onTap: onTap
	# Pointer arrow
	Obs.observe !->
		addBar
			top: true
			order: -20
			content: !->
				return if !Geoloc.isSubscribed()
				state = Geoloc.track()
				return if !state
				Obs.observe !->
					location = state.get('latlong')
					lastTime = state.get('time')
					return if !location
					# Render an arrow that points to your location if you do not have it on your screen already
					if !(Map.inBounds(location, map.getLatlongNW(), map.getLatlongSE()))
						Dom.style
							display: 'inline-block'
							padding: '7px'
							width: '50px'
							height: '50px'
						Dom.onTap !->
							map.setLatlong location
							map.setZoom 16
						Dom.div !->
							styleTransformAngle map.getLatlongNW(), location
							Dom.style
								width: '50px'
								height: '50px'
								borderRadius: '50%'
								backgroundColor: '#0077cf'
							Dom.cls 'pointerArrow'
						Dom.div !->
							avatarKey = App.userAvatar()
							Dom.style
								width: '50px'
								height: '50px'
								Box: 'middle center'
								marginTop: '-50px'
								_transform: "translate3d(0,0,0)"
							Ui.avatar avatarKey, size: 44, style:
								display: 'block'
								margin: '0'
						Dom.div !->
							Dom.style
								overflow: "hidden"
								width: '50px'
								height: '50px'
								marginTop: "-50px"
								borderRadius: '50%'
								_transform: "translate3d(0,0,0)"
							Dom.div !->
								Dom.style
									backgroundColor: "#0077cf"
									color: "#FFF"
									fontSize: "50%"
									width: "50px"
									height: "20px"
									paddingTop: "2px"
									marginTop: "35px"
									textAlign: 'center'
								Dom.text getDistanceString map.getLatlongNW(), location
	Dom.css
		'.pointerArrow:after':
			content: "''"
			display: 'block'
			width: '0'
			height: '0'
			top: '-7px'
			left: '21px'
			borderBottom: 'solid 8px #0077cf'
			borderLeft: 'solid 5px transparent'
			borderRight: 'solid 5px transparent'
			position: 'absolute'

	# Check for beacon capturing
	Obs.observe !->
		if Db.shared.peek('gameState') is 1 # Only when the game is running, do something
			return if !Geoloc.isSubscribed()
			state = Geoloc.track(100, 0)
			return if !state
			Obs.observe !->
				location = state.get('latlong')
				accuracy = state.get('accuracy')
				return if !location?
				Db.shared.iterate 'game', 'beacons', (beacon) !->
					distance = Map.distance(location, beacon.get('location'))
					#log 'distance=', distance, 'beacon=', beacon
					beaconRadius = Db.shared.peek('game', 'beaconRadius')
					within = distance - beaconRadius <= 0
					deviceId = Db.local.peek('deviceId')
					inRangeValue = beacon.peek('inRange', App.userId(), 'device')
					checkinLocation = !->
						if +Db.shared.peek('gameState') is 1
							log 'checkinLocation: user='+App.userName()+' ('+App.userId()+'), deviceId='+deviceId+', accuracy='+accuracy+', gameState='+Db.shared.peek('gameState')
							Server.send 'checkinLocation', location, deviceId, accuracy
					if within
						log 'accuracy='+accuracy+', beaconRadius='+beaconRadius
						if accuracy > beaconRadius # Deny capturing with low accuracy
							if not inRangeValue?
								log 'Did not checkin location, accuracy too low: '+accuracy
								addBar
									top: false
									order: 10
									content: !->
										Dom.style
											padding: '11px'
											fontSize: '16px'
											Box: 'horizontal center'
											backgroundColor: '#888888'
											color: 'white'
										Dom.div !->
											Dom.style
												marginRight: '10px'
												width: '30px'
											Icon.render data: 'warn', color: '#fff', style: {paddingRight: '10px'}, size: 30
										Dom.div !->
											Dom.style
												Flex: true
											Dom.text 'Your accuracy of '+accuracy+' meter is higher than the maximum allowed '+beaconRadius+' meter.'
						else
							checkinLocation()
							log 'Trying beacon takeover: userId='+App.userId()+', location='+beacon.peek('location')+', deviceId='+deviceId
					else if (not within and inRangeValue? and (inRangeValue is deviceId || inRangeValue is 'true'))
						log 'Trying stop of beacon takeover: userId='+App.userId()+', location='+beacon.get('location')+', deviceId='+deviceId
						checkinLocation()


# =============== Functions ===============
# Input hexadecimal value and opacity, returns the RGBA equivalent
hexToRGBA = (hex, opacity) ->
	result = 'rgba('
	hex = hex.replace '#', ''
	if hex.length is 3
		result += [parseInt(hex.slice(0,1) + hex.slice(0, 1), 16), parseInt(hex.slice(1,2) + hex.slice(1, 1), 16), parseInt(hex.slice(2,3) + hex.slice(2, 1), 16), opacity]
	else if hex.length is 6
		result += [parseInt(hex.slice(0,2), 16), parseInt(hex.slice(2,4), 16), parseInt(hex.slice(4,6), 16), opacity]
	else
		result += [0, 0, 0, 0.0]
	return result+')'

#Returns the players that are inrange of the given beacon
getInRange = (beacon) ->
	players = undefined
	beacon.iterate 'inRange', (user) !->
		if players?
			players = players+', '+App.userName(user.key())
		else
			players = App.userName(user.key())
	return players;

# Render a map marker popup
renderPopup = (opts) !->
	opts.anchor = 'middle' if !opts.anchor
	opts.width = 100 if !opts.width

	iconWidth = Dom.get().width()
	iconHeight = Dom.get().height()
	Dom.div !->
		opts.content?()
		Dom.style
			width: opts.width
			padding: "8px"
			border: "1px solid #ccc"
		Dom.div !->
			t = "rotate(45deg)"
			if (width = Dom.get().width()) is 0 then width = opts.width
			Dom.style
				width: "10px"
				height: "10px"
				margin: "0 0 -12px "+((width+10)/2-9)+"px"
				backgroundColor: "#FFF"
				_boxShadow: "1px 1px 0 #BBB"
				mozTransform: t
				msTransform: t
				oTransform: t
				webkitTransform: t
				transform: t
				borderRadius: "100% 0 0 0"
		Dom.style
			backgroundColor: "#FFF"
			borderRadius: "5px"
			textAlign: "center"
			overflow: "visible"
			textOverflow: 'ellipsis'
			lineHeight: "125%"
			zIndex: "10000000"
			color: "#222"
		height = Dom.get().height()
		width = Dom.get().width()
		width = opts.width if width is 0
		Dom.style
			margin: (-height-7-(if opts.anchor is 'middle' then iconHeight/2 else iconHeight))+"px 0 7px -"+(width/2-(iconWidth/2))+'px'

# Render small text
smallText = (content) !->
	Dom.div !->
		Dom.style
			fontSize: '90%'
			color: '#999'
		if typeof content is 'function'
			content()
		else
			Dom.text content

# Organize the bottom and top bars
bars = []
barsTrigger = Obs.create {}
barNumber = 0
addBar = (opts) !->
	barNumber++
	thisNumber = barNumber
	bars[thisNumber] = opts.content
	barsTrigger.set thisNumber,
		order: opts.order||1
		top: !!opts.top
	Obs.onClean !->
		barsTrigger.remove thisNumber
		delete bars[thisNumber]
# Render the bars
renderBars = !->
	Dom.div !->
		Dom.style
			position: "absolute"
			top: "0"
			left: "0"
			right: "0"
			zIndex: "999999"
		barsTrigger.iterate (bar) !->
			Dom.div !->
				bars[bar.key()]()
		, (bar) ->
			if bar.get('top')
				-bar.get('order')
	Dom.div !->
		Dom.style
			position: "absolute"
			bottom: "0"
			left: "0"
			right: "0"
			zIndex: "999999"
		barsTrigger.iterate (bar) !->
			Dom.div !->
				bars[bar.key()]()
		, (bar) ->
			if !bar.get('top')
				-bar.get('order')

# Style an element with a rotation to a certain direction
styleTransformAngle = (anchor, to) !->
	[anchorLat,anchorLong] = anchor.split(",")
	[lat,long] = to.split(",")
	pi = 3.14159265
	anchorLat = anchorLat * pi / 180
	lat = lat * pi / 180
	dLon = (long-anchorLong) * pi / 180
	y = Math.sin(dLon) * Math.cos(lat)
	x = Math.cos(anchorLat)*Math.sin(lat) - Math.sin(anchorLat)*Math.cos(lat)*Math.cos(dLon)
	bearing = Math.atan2(y, x) * 180 / pi
	if bearing < 0
		bearing = bearing + 360
	bearing = bearing*(pi/180)
	t = "rotate(" +bearing + "rad)"
	Dom.style
		mozTransform: t
		msTransform: t
		oTransform: t
		webkitTransform: t
		_transform: t

# Get a compact distance string
getDistanceString = (from, to) !->
	distance = Map.distance(from, to)
	if distance <= 1000
		distanceString = Math.round(distance) + "m"
	else
		distanceString = Math.round(distance/1000) + "km"
	return distanceString