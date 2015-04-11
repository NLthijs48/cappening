Dom.css
# Main content page
	'.bar-button':
		height: "100%"
		width: "25%"
		float: "left"
		color: "white"
		backgroundColor: "#666"
		lineHeight: "50px"
		textAlign: "center"
		verticalAlign: "middle"
	'.bar-button::after':
		content: '""'
		display: 'block'
		width: '1px'
		height: '40px'
		backgroundColor: '#ABABAB'
		margin: '-44px 0 0 0'
		boxShadow: 'none'
	'.bar-button:first-of-type::after':
		display: 'none'
	'.mapbox-logo':
		display: "none"
# Plugin setup pages
	'.stepbar': # The bar at the top
		color: "white"
		backgroundColor: "#888"
		lineHeight: "50px"
		textAlign: "center"
		right: "0"
		left: "0"
		top: "0"
		position: "absolute"
		zIndex: "5"
		boxShadow: "0 3px 5px 0 rgba(0, 0, 0, 0.2)"
		borderColor: "#EFEFEF"
		fontSize: '20px'
		boxSizing: 'border-box'
		display: 'flex'
		flexDirection: 'row'
	'.stepbar-middle': # The middle section
		flexGrow: '1'
		flexShrink: '1'
		textOverflow: 'ellipsis'
		whiteSpace: 'nowrap'
		overflow: 'hidden'
	'.stepbar-button': # A button with an arrow
		borderColor: 'inherit'
		fontSize: '16px'
		color: '#EFEFEF'
		flexGrow: '0'
		flexShrink: '0'
	'.stepbar-button:hover':
		backgroundColor: '#7C7C7C'
	'.stepbar-button:active':
		backgroundColor: '#767676 !important'
	'.stepbar-left': # The left arrow button
		textAlign: 'left'
		paddingLeft: '38px'
		paddingRight: '10px'
	'.stepbar-left::before':
		content: '""' # The left arrow button (pseudo element to create the arrow)
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
	'.stepbar-right::before': # The right arrow button (pseudo element to create the arrow)
		content: '""'
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