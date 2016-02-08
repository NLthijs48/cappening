Dom.css
# Plugin setup pages
	'.stepbar': # The bar at the top
		color: 'white'
		backgroundColor: '#888'
		lineHeight: '50px'
		textAlign: 'center'
		zIndex: '5'
		boxShadow: '0 3px 5px 0 rgba(0, 0, 0, 0.2)'
		borderColor: '#EFEFEF'
		fontSize: '19px'
		boxSizing: 'border-box'
		position: 'absolute'
		width: '100%'
		margin: '-8px -8px 0 -8px'
	'.stepbar-middle': # The middle section
		textOverflow: 'ellipsis'
		whiteSpace: 'nowrap'
		overflow: 'hidden'
		padding: '0 80px 0 80px'
	'.stepbar-button': # A button with an arrow
		borderColor: 'inherit'
		fontSize: '16px'
		color: '#EFEFEF'
		_flexGrow: '0'
		_flexShrink: '0'
		position: 'absolute'
	'.stepbar-button:hover':
		backgroundColor: '#7C7C7C'
	'.stepbar-button:active':
		backgroundColor: '#767676 !important'
	'.stepbar-left': # The left arrow button
		textAlign: 'left'
		paddingLeft: '38px'
		paddingRight: '10px'
		left: '0'
		top: '0'
	'.stepbar-left::before':
		content: "''" # The left arrow button (pseudo element to create the arrow)
		position: 'absolute'
		display: 'block'
		width: '0'
		margin: '10px 0 0 8px'
		borderRight: '25px solid'
		borderTop: '15px solid transparent'
		borderBottom: '15px solid transparent'
		borderRightColor: 'inherit'
		left: '0'
	'.stepbar-right': # The right arrow button
		textAlign: 'right'
		paddingRight: '38px'
		paddingLeft: '10px'
		right: '0'
		top: '0'
	'.stepbar-right::before': # The right arrow button (pseudo element to create the arrow)
		content: "''"
		position: 'absolute'
		display: 'block'
		width: '0'
		margin: '10px 8px 0 0'
		borderLeft: '25px solid'
		borderTop: '15px solid transparent'
		borderBottom: '15px solid transparent'
		borderLeftColor: 'inherit'
		right: '0'
	'.stepbar-disable': # Class to disable an arrow button
		borderColor: '#A3A3A3'
		backgroundColor: 'transparent !important'
		color: '#A3A3A3'
		cursor: 'default'
	'.stepbar-disable:active':
		backgroundColor: 'transparent !important'

# Scores page
	'.teampage':
		fontSize: '20px'
		display: 'block'
		borderBottom: '2px solid'
		paddingBottom: '2px'
		textTransform: 'uppercase'
		textShadow: '1px 1px 2px #000000'

# End game page
	'.restartButton:hover':
		backgroundColor: '#A71963 !important'
	'.restartButton:active':
		backgroundColor: '#80134C !important'