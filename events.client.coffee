Db = require 'db'
Dom = require 'dom'
Obs = require 'obs'
Event = require 'event'
Plugin = require 'plugin'
Page = require 'page'
Ui = require 'ui'

# Eventlog page
exports.render = !->
	Page.setTitle !->
		Dom.text 'Conquest game events'
	Event.showStar tr('Game events')
	Ui.list !->
		Dom.style
			padding: '0'
		Db.shared.iterate 'game', 'eventlist', (capture) !->
			if capture.key() != "maxId"
				Ui.item !->
					Dom.style
						padding: '14px'
					if capture.peek('type') is "capture" and mapReady()
						beaconId = capture.peek('beacon')
						teamId = capture.peek('conqueror')
						teamColor = Shared.teams[teamId].hex
						teamName = Shared.teams[teamId].name
						Dom.onTap !->
							Toast.show !->
								Dom.text 'Captured '
								Time.deltaText(capture.peek('timestamp'))
								if capture.peek('members')?
									Dom.text " by " + Shared.userStringToFriendly(capture.peek('members')) + ' of team ' + teamName
								else
									Dom.text ' by team '+teamName
							Db.local.set 'switchToMapLocation', Db.shared.peek('game', 'beacons' ,beaconId, 'location', 'lat')+':'+Db.shared.peek('game', 'beacons' ,beaconId, 'location', 'lng')
							Db.local.set 'switchToMapZoom', 16
							Page.nav()
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{Plugin.resourceUri('marker-plain.png')}) no-repeat 10px 10px"
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '100%'
							if Event.isNew(capture.peek('timestamp'))
								Dom.style color: '#5b0'
							if capture.peek('members')?
								Dom.text Shared.userStringToFriendly(capture.peek('members')) + ' of team ' + teamName + ' captured a beacon'
							else
								Dom.text "Team " + teamName + " captured a beacon"
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text "Captured "
								Time.deltaText capture.peek('timestamp')
					else if capture.peek('type') is "captureAll"
						beaconId = capture.peek('beacon')
						teamId = capture.peek('conqueror')
						teamColor = Shared.teams[teamId].hex
						teamName = Shared.teams[teamId].name
						log "print capture: teamId; " + teamId
						Dom.onTap !->
							Toast.show !->
								Dom.text 'Captured '
								Time.deltaText(capture.peek('timestamp'))
								if capture.peek('members')?
									Dom.text " by " + Shared.userStringToFriendly(capture.peek('members')) + ' of team ' + teamName
								else
									Dom.text ' by team '+teamName
							Db.local.set 'switchToMapLocation', Db.shared.peek('game', 'beacons', beaconId, 'location', 'lat')+':'+Db.shared.peek('game', 'beacons', beaconId, 'location', 'lng')
							Db.local.set 'switchToMapZoom', 16
							Page.nav()
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{Plugin.resourceUri('markers-plain.png')}) no-repeat 10px 10px" 
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '100%'
							if Event.isNew(capture.peek('timestamp'))
								Dom.style color: '#5b0'
							Dom.text "Team " + teamName + " team captured all beacons"
							if capture.peek('members')?
								Dom.text " thanks to " + Shared.userStringToFriendly(capture.peek('members'))
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text "Captured "
								Time.deltaText capture.peek('timestamp')
					else if capture.peek('type') is "score"
						teamId = capture.peek('leading')
						teamColor = Shared.teams[teamId].hex
						teamName = Shared.teams[teamId].name
						Dom.onTap !->
							Page.nav 'scores'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{Plugin.resourceUri('rank-switch.png')}) no-repeat 10px 10px" 
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '100%'
							if Event.isNew(capture.peek('timestamp'))
								Dom.style color: '#5b0'
							Dom.text "Team " + teamName + " took the lead"
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text "Captured "
								Time.deltaText capture.peek('timestamp')
					else if capture.peek('type') is "cancel"
						Dom.style
							padding: '14px'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: "#DDDDDD url(#{Plugin.resourceUri('markers-cancel-plain.png')}) no-repeat 10px 10px" 
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '16px'
							if Event.isNew(capture.peek('timestamp'))
								Dom.style color: '#5b0'
							Dom.text "No longer are all beacons owned by one team"
							started = Db.shared.peek 'game', 'startTime'
							if started?
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px'
									Dom.text 'Happened '
									Time.deltaText started
					else if capture.peek('type') is "start"
						Dom.style
							padding: '14px'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '55px'
								marginRight: '10px'
								background: '#DDDDDD'
								backgroundSize: 'cover'
								paddingTop: '15px'
							Dom.div !->
								Dom.style
									margin: '0 0 0 20px'
									borderLeft: '34px solid #FFFFFF'
									borderTop: '20px solid transparent'
									borderBottom: '20px solid transparent'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '16px'
							if Event.isNew(capture.peek('timestamp'))
								Dom.style color: '#5b0'
							Dom.text "Start of the game!"
							started = Db.shared.peek 'game', 'startTime'
							if started?
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px'
									Dom.text 'Started '
									Time.deltaText started
					else if capture.peek('type') is "end"
						teamId = Db.shared.peek('game', 'firstTeam')
						teamColor = Shared.teams[teamId].hex
						teamName = Shared.teams[teamId].name
						Dom.style
							padding: '14px'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor + " url(#{Plugin.resourceUri('ranking-plain.png')}) no-repeat 10px 10px"
								backgroundSize: '50px 50px'
						Dom.div !->
							Dom.style Flex: 1, fontSize: '16px'
							if Event.isNew(capture.peek('timestamp'))
								Dom.style color: '#5b0'
							Dom.text "Team " + teamName + " won the game"
							started = Db.shared.peek 'game', 'startTime'
							if started?
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px'
									Dom.text 'Started '
									Time.deltaText started
		, (capture) -> (-capture.key())
