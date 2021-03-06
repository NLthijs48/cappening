Shared = require 'shared'
Config = Shared.config()
tr = I18n.tr

# Eventlog page
exports.render = !->
	Page.setTitle !->
		Dom.text 'Conquest game events'
	Event.showStar tr('Game events')
	Dom.div !->
		Dom.style MarginPolicy: 'adopt'
		Db.shared.iterate 'game', 'eventlist', (capture) !->
			if capture.key() != "maxId"
				Ui.item !->
					if capture.peek('type') is "capture"
						beaconId = capture.peek('beacon')
						teamId = capture.peek('conqueror')
						teamColor = Config.teams[teamId].hex
						teamName = Config.teams[teamId].name
						Dom.onTap !->
							Toast.show !->
								Dom.text 'Captured '
								Time.deltaText(capture.peek('timestamp'))
								if capture.peek('members')?
									Dom.text " by " + Shared.userStringToFriendly(capture.peek('members')) + ' of team ' + teamName
								else
									Dom.text ' by team '+teamName
							Db.local.set 'switchToMapLocation', Db.shared.peek('game', 'beacons', beaconId, 'location')
							Db.local.set 'switchToMapZoom', 16
							Db.local.set 'switchToPopup', beaconId
							Page.nav()
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{App.resourceUri('marker-plain.png')}) no-repeat 10px 10px"
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
						teamColor = Config.teams[teamId].hex
						teamName = Config.teams[teamId].name
						log "print capture: teamId; " + teamId
						Dom.onTap !->
							Toast.show !->
								Dom.text 'Captured '
								Time.deltaText(capture.peek('timestamp'))
								if capture.peek('members')?
									Dom.text " by " + Shared.userStringToFriendly(capture.peek('members')) + ' of team ' + teamName
								else
									Dom.text ' by team '+teamName
							Db.local.set 'switchToMapLocation', Db.shared.peek('game', 'beacons', beaconId, 'location')
							Db.local.set 'switchToMapZoom', 16
							Db.local.set 'switchToPopup', beaconId
							Page.nav()
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{App.resourceUri('markers-plain.png')}) no-repeat 10px 10px" 
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
						teamColor = Config.teams[teamId].hex
						teamName = Config.teams[teamId].name
						Dom.onTap !->
							Page.nav 'scores'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor+" url(#{App.resourceUri('rank-switch.png')}) no-repeat 10px 10px" 
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
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: "#DDDDDD url(#{App.resourceUri('markers-cancel-plain.png')}) no-repeat 10px 10px" 
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
						teamColor = Config.teams[teamId].hex
						teamName = Config.teams[teamId].name
						Dom.style
							padding: '14px'
						Dom.div !->
							Dom.style
								width: '70px'
								height: '70px'
								marginRight: '10px'
								background: teamColor + " url(#{App.resourceUri('ranking-plain.png')}) no-repeat 10px 10px"
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
