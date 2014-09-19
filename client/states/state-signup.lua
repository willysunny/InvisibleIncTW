----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local modalDialog = include( "states/state-modal-dialog" )
local mui = include("mui/mui")
local array = include( "modules/array" )
local util = include("client_util")
local serverdefs = include( "modules/serverdefs" )
local guiex = include( "guiex" )

local stateSignUp = {}
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local COUNTRIES = {}

local fl = io.open( "data/misc/countries.txt", "r" )
if fl then
	for line in fl:lines() do
		table.insert( COUNTRIES, line:match( "([^\n\r]+)" ))
	end
end

----------------------------------------------------------------
--
local MIN_EMAIL_LEN = 6

local function validateEmail( email )
	if #email < MIN_EMAIL_LEN then
		return false, string.format( "Email must be at least %d characters long.", MIN_EMAIL_LEN )
	end

	-- See RFC 5322, 5321, 3696 for precise syntax.  This is very simplified.- (e.g: %. (dot), %% (%), etc)
	local pattern = "^[%w%p]+@[%w%p]+%.%w+$" -- did not work for new server for some reason
	if email:match( pattern ) == nil  then
		return false, "Invalid email format."
	end

	return true
end


local function populateDays( year, month, comboWidget )
	local isLeapYear = (year % 400 == 0) or (year % 4 == 0 and year % 100 ~= 0)
	local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	if isLeapYear then
		DAYS_IN_MONTH[2] = 29
	end

	comboWidget:clearItems()

	assert( DAYS_IN_MONTH[ month ], month )
	for i = 1, DAYS_IN_MONTH[ month ] do
		comboWidget:addItem( tostring(i) )
	end

	local day = math.max( 1, math.min( DAYS_IN_MONTH[ month ], tonumber( comboWidget:getText() ) or tonumber(os.date("%d"))))
	comboWidget:setText( tostring(day) )
end

----------------------------------------------------------------
stateSignUp.onDateChanged = function( self, str )
	local year = tonumber( self.screen.binder.yearCmb:getText() )
	local month = array.find( MONTHS, self.screen.binder.monthCmb:getText() )
	populateDays( year, month, self.screen.binder.dayCmb )
end

stateSignUp.onClickCancel = function( self )
	statemgr.deactivate( self )
end

stateSignUp.onClickOk = function( self )

	local useremail = self.emailBox:getText()

	local valid, err = validateEmail( useremail )
	if not valid then
		modalDialog.show( err )
		return
	end

	-- Do signup.
	local year = self.screen.binder.yearCmb:getText()
	local month = array.find( MONTHS, self.screen.binder.monthCmb:getText() )
	local day = self.screen.binder.dayCmb:getText()
	local country = self.screen.binder.countryCmb:getText()
	if not country or #country == 0 then
		modalDialog.show( "Please enter a country of origin." )
		return
	end

	local task = cloud.sendSubscribe( useremail, string.format( "%s-%s-%s", day, month, year ), country )
	guiex.createDialogTask( "Signing Up...", task,
		function( result, responseCode )
			if responseCode == cloud.HTTP_OK then
				modalDialog.show(
					string.format( "You are now signed-up to receive updates.\nYou will receive a confirmation email to\n%s\nshortly.", useremail ) )
			else
				modalDialog.show(
					string.format( "There was an error signing up (%d - %s).  Please try again later.", tostring(responseCode), util.tostringl(result) ) )
			end
			statemgr.deactivate( self )
		end )
end

----------------------------------------------------------------
stateSignUp.onLoad = function ( self )
	local user = savefiles.getCurrentGame()

	self.screen = mui.createScreen( "modal-signup.lua" )
	mui.activateScreen( self.screen )

	self.emailBox = self.screen:findWidget("emailBox")
	if user and user.data.email then
		self.emailBox:setText(user.data.email)
	end

	for i = 1, #MONTHS do
		self.screen.binder.monthCmb:addItem( MONTHS[i] )
	end
	self.screen.binder.monthCmb:setText( MONTHS[ tonumber(os.date("%m")) ] )
	self.screen.binder.monthCmb.onTextChanged = util.makeDelegate( self, "onDateChanged" )

	populateDays( tonumber( os.date("%Y")), tonumber(os.date("%m")), self.screen.binder.dayCmb )

	for year = 2013, 1900, -1 do
		self.screen.binder.yearCmb:addItem( tostring(year) )
	end
	self.screen.binder.yearCmb:setText( os.date("%Y"))
	self.screen.binder.yearCmb.onTextChanged = util.makeDelegate( self, "onDateChanged" )

	for i, country in ipairs( COUNTRIES ) do
		self.screen.binder.countryCmb:addItem( country )
	end

	self.screen.binder.cancelBtn.onClick = util.makeDelegate(self, "onClickCancel")
	self.screen.binder.okBtn.onClick = util.makeDelegate(self, "onClickOk")

end

----------------------------------------------------------------
stateSignUp.onUnload = function ( self )
	mui.deactivateScreen( self.screen )
	self.screen = nil
end

return stateSignUp
