Ui = require 'ui'
Db = require 'db'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'

# Ranking page
exports.render = !->
	Page.setTitle !->
		Dom.text 'Conquest ranking'
	Ui.list !->
		Dom.style
			padding: '0'
		Db.shared.iterate 'game', 'teams', (team) !->
			teamColor = Shared.teams[team.key()].hex
			teamName = Shared.teams[team.key()].name
			teamScore = Db.shared.get('game', 'teams', team.key(), 'teamScore')
			# list of teams and their scores
			expanded = Obs.create(false)
			Ui.item !->
				Dom.style
					padding: '14px'
					minHeight: '71px'
					alignItems: 'stretch'
				Dom.div !->
					Dom.style
						width: '70px'
						height: '70px'
						background: teamColor
						backgroundSize: 'cover'
						position: 'absolute'
						_textShadow: '0 0 3px rgba(0,0,0,0.8)'
					Dom.div !->
						rank = team.get('ranking')
						Dom.style
							fontSize: "40px"
							paddingTop: "12px"
							textAlign: "center"
							color: "white"
							paddingRight: if rank is 1 then '10px' else '15px'
						Dom.text rank
						rankingSuffix = {1: "st", 2: "nd", 3: "rd", 4: "th", 5: "th", 6: "th"}
						Dom.div !->
							Dom.text rankingSuffix[rank]
							Dom.style
							    position: 'absolute'
							    fontSize: '17px'
							    left: if rank is 1 then '38px' else '40px'
							    top: '15px'
				Dom.div !->
					Dom.style fontSize: '100%', paddingLeft: '84px'
					Dom.text "Team " + teamName + " scored " + teamScore + " points"
					if parseInt(team.key()) is parseInt(Shared.getTeamOfUser(Plugin.userId()))
						Dom.style fontWeight: 'bold'
					# To Do expand voor scores
					if expanded.get() || Plugin.users.count().peek() <= 10
						team.iterate 'users', (user) !->
							Dom.div !->
								if parseInt(user.key())  isnt Plugin.userId()
									Dom.style fontWeight: 'normal'
								Dom.style clear: 'both'
								Ui.avatar Plugin.userAvatar(user.key()),
									style: margin: '6px 10px 0 0', float: 'left'
									size: 40
									onTap: (!-> Plugin.userInfo(user.key()))
								Dom.div !->
									Dom.br()
									Dom.style fontSize: '75%', marginTop: '6px', marginRight: '6px', display: 'block', float: 'left', minWidth: '75px'
									Dom.text Plugin.userName(user.key()) + " has: "
								Dom.div !->
									Dom.style fontSize: '75%', marginTop: '6px', display: 'block', float: 'left'
									Dom.text user.get('userScore') + " points"
									Dom.br()
									Dom.text user.get('captured') + " captured"
									Dom.br()
									Dom.text user.get('neutralized') + " neutralized"
						, (user) -> (-user.get('userScore'))
					else
						Dom.div !->
							Dom.style fontSize: '75%', marginTop: '6px'
							Dom.text "Tap for details"
				if Plugin.users.count().peek() > 10
					Dom.onTap !->
						expanded.set(!expanded.get())
		, (team) -> team.get('ranking')
