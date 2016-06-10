# General config values (used by client and server)
config =
	beaconPointsTime: 3600000	# Milliseconds between scoring points for a beacon
	beaconHoldScore: 1			# Number of points scored per <pointsTime> by holding a beacon
	beaconValueInitial: 50 		# Initial capture value of a beacon
	beaconValueDecrease: 5		# Value decrease after capture
	beaconValueMinimum: 10		# Minimum beacon value
	onHTTPKey: '0acc7d0fd7ac9ef4133950d3949b81a7' # Hash of http secret key
	inRangeCheckinTime: 30		# Time between client checkins while inrange of a beacon (seconds)
	inRangeKickTime: 60			# Time after no checkin that the server will remove the client from inrange (seconds)
	teams:						# Colors used for the different teams
		'-1':
			name: 'neutral'
			capitalizedName: 'Neutral'
			hex: '#999999'
		0:
			name: 'blue'
			capitalizedName: 'Blue'
			hex: '#3882b6'
		1:
			name: 'green'
			capitalizedName: 'Green',
			hex: '#009F22'
		2:
			name: 'orange'
			capitalizedName: 'Orange'
			hex: '#FFA200'
		3:
			name: 'red'
			capitalizedName: 'Red'
			hex: '#E41B1B'
		4:
			name: 'yellow'
			capitalizedName: 'Yellow'
			hex: '#F2DB0D'
		5:
			name: 'purple'
			capitalizedName: 'Purple'
			hex: '#E637D8'
exports.config = -> config

# Get the team id the user is added to
exports.getTeamOfUser = (userId) ->
	result = -1
	Db.shared.iterate 'game', 'teams', (team) !->
		if team.peek('users', userId, 'userName')?
			result = team.key()
	return result

# Display a line of users with comma's + 'and'
exports.userStringToFriendly = (users) ->
	if (not (users?)) or users is ''
		return undefined
	split = users.split(', ')
	if split.length is 0
		return ""
	result = App.userName(parseInt(split[0]))
	i=1
	while i<(split.length-1)
		result += ', ' + App.userName(parseInt(split[i]))
		i++
	if split.length > 1
		result += ' and ' + App.userName(parseInt(split[split.length-1]))
	return result

exports.member = ->
	(memberId) ->
		memberId = App.memberId() if !memberId?
		"#{App.userName(memberId)}(#{memberId})"