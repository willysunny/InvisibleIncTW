----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources")
local util = include( "modules/util" )
local mui = include( "mui/mui" )
local mui_defs = include( "mui/mui_defs" )
local cdefs = include( "client_defs" )

local CANCEL = 0
local OK = 1
local AUX = 2

----------------------------------------------------------------

local _M =
{
}

_M.setText = function( self, str )
	self.screen.binder.bodyTxt:setText(str)
end

_M.onUnload = function ( self )
	mui.deactivateScreen( self.screen )
	self.screen = nil
end

----------------------------------------------------------------

local function createModalDialog( dialogStr, headerStr )
	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-dialog.lua" )
		mui.activateScreen( self.screen )

		self.screen.binder.okBtn:setPosition( self.screen.binder.cancelBtn:getPosition() )
		self.screen.binder.okBtn.onClick = util.makeDelegate( nil, function() t.result = OK end )
		self.screen.binder.cancelBtn:setVisible( false )
		if headerStr then
			self.screen.binder.headerTxt:setText( headerStr )
		else
			self.screen.binder.headerTxt:setText("")
		end
		self.screen.binder.bodyTxt:setText( dialogStr )
	end

	return t
end

local function createDisclaimerDialog( dialogStr, headerStr, okStr )
	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-disclaimer.lua" )
		mui.activateScreen( self.screen )

		self.screen.binder.okBtn.binder.btn:setText(okStr)
		self.screen.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, function() t.result = OK end )
		self.screen.binder.headerTxt1:setText( headerStr )
		self.screen.binder.bodyTxt1:setText( dialogStr )
	end

	return t
end

local function createUpdateDisclaimerDialog( okStr, readMoreStr )
	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-update-disclaimer.lua" )
		mui.activateScreen( self.screen )

		self.screen.binder.okBtn.binder.btn:setText(okStr)
		self.screen.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, function() t.result = OK end )

		self.screen.binder.readMoreBtn.binder.btn:setText(readMoreStr)
		self.screen.binder.readMoreBtn.binder.btn.onClick = util.makeDelegate( nil, function() MOAISim.visitURL( config.PATCHNOTES_URL ) end )
	end

	return t
end

local function createYesNoDialog( dialogStr, headerStr, auxStr, continueTxt, cancelTxt )
	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-dialog.lua" )
		mui.activateScreen( self.screen )
		
		if continueTxt then
			self.screen.binder.okBtn:setText( util.toupper(continueTxt) )
		end

		self.screen.binder.okBtn.onClick = util.makeDelegate( nil, function() t.result = OK end )
		self.screen.binder.cancelBtn.onClick = util.makeDelegate( nil, function() t.result = CANCEL end )
		if auxStr then
			self.screen.binder.auxBtn:setVisible( true )
			self.screen.binder.auxBtn:setText( auxStr )
			self.screen.binder.auxBtn.onClick = util.makeDelegate( nil, function() t.result = AUX end )
		end
		if cancelTxt then
			self.screen.binder.cancelBtn:setText( cancelTxt )
		end
		if headerStr then
			self.screen.binder.headerTxt:setText( headerStr )
		else
			self.screen.binder.headerTxt:setText("")
		end	
		self.screen.binder.bodyTxt:setText( dialogStr )
	end
	
	return t
end

local function createBusyDialog( dialogStr, headerStr )

	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-busy.lua" )
		mui.activateScreen( self.screen )
		
		self.screen.binder.cancelBtn.onClick = util.makeDelegate( nil, function() t.result = CANCEL end )
		self.screen.binder.cancelBtn:setVisible( false ) -- nothing cancel-able atm
		self.screen.binder.bodyTxt:setText( dialogStr or "" )
		self.screen.binder.headerTxt:setText( headerStr or "" )
	end

	return t
end

local function createAlarmDialog( txt,txt2,num,num2 )

	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-alarm.lua" )
		mui.activateScreen( self.screen )

		self.screen.binder.pnl.binder.okBtn.binder.btn:setText(STRINGS.UI.CONTINUE)
		self.screen.binder.pnl.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, function() t.result = CANCEL end )

		self.screen.binder.pnl.binder.title.binder.titleTxt:setText( STRINGS.UI.ALARM_INSTALL )
		self.screen.binder.pnl.binder.title.binder.titleTxt2:setText( string.format( txt,num ) )
		self.screen.binder.pnl.binder.bodyTxt:setText( string.format( txt2, num2 ) )	

		self.screen.binder.pnl.binder.num:setText(num)

		local color = cdefs.TRACKER_COLOURS[num+1]
		self.screen.binder.pnl.binder.circle:setColor(color.r,color.g,color.b,1)
		self.screen.binder.pnl.binder.num:setColor(color.r,color.g,color.b,1)
		self.screen.binder.pnl.binder.headerbox:setColor(color.r,color.g,color.b,1)
		self.screen.binder.pnl.binder.bodyTxt:setColor(color.r,color.g,color.b,1)
	end

	return t
end

local function createAlarmFirstDialog( txt,txt2,num,num2 )

	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-alarm-first.lua" )
		mui.activateScreen( self.screen )
		self.screen.binder.pnl.binder.okBtn.binder.btn:setText(STRINGS.UI.CONTINUE)
		self.screen.binder.pnl.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, function() t.result = CANCEL end )

		self.screen.binder.pnl.binder.title.binder.titleTxt:setText( STRINGS.UI.ALARM_INSTALL )
		self.screen.binder.pnl.binder.title.binder.titleTxt2:setText( string.format( txt,num ) )
		self.screen.binder.pnl.binder.bodyTxt:setText( string.format( txt2, num2 ) )	

		self.screen.binder.pnl.binder.num:setText(num)

		local color = cdefs.TRACKER_COLOURS[num+1]
		self.screen.binder.pnl.binder.circle:setColor(color.r,color.g,color.b,1)
		self.screen.binder.pnl.binder.num:setColor(color.r,color.g,color.b,1)
		self.screen.binder.pnl.binder.headerbox:setColor(color.r,color.g,color.b,1)
		self.screen.binder.pnl.binder.bodyTxt:setColor(color.r,color.g,color.b,1)
	end

	return t
end

local function createProgramDialog( txt1,txt2,txt3,icon,color )

	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-program.lua" )
		mui.activateScreen( self.screen )

		self.screen.binder.pnl.binder.okBtn.binder.btn:setText(STRINGS.UI.CONTINUE)
		self.screen.binder.pnl.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, function() t.result = CANCEL end )

		self.screen.binder.pnl.binder.title.binder.titleTxt:setText( txt1 )
		self.screen.binder.pnl.binder.title.binder.titleTxt2:setText( txt2 )
		self.screen.binder.pnl.binder.bodyTxt:setText( txt3 )	
		self.screen.binder.pnl.binder.icon:setImage(icon)
		if not color then
			color = {r=140/255,g=255/255,b=255/255,a=1}
		end
		self.screen.binder.pnl.binder.headerbox:setColor(color.r,color.g,color.b,1)
		self.screen.binder.pnl.binder.bodyTxt:setColor(color.r,color.g,color.b,1)
	end

	return t
end

local function showDialog( modalDialog )
	statemgr.activate( modalDialog )

	while modalDialog.result == nil do
		coroutine.yield()
	end

	statemgr.deactivate( modalDialog )

	return modalDialog.result
end

local function show( bodyTxt, headerTxt )
	local modalDialog = createModalDialog( bodyTxt, headerTxt )
	return showDialog( modalDialog )
end

local function showYesNo( bodyTxt, headerTxt, auxTxt, continueTxt, cancelTxt )
	local modalDialog = createYesNoDialog( bodyTxt, headerTxt, auxTxt, continueTxt, cancelTxt )
	return showDialog( modalDialog )
end

local function showAlarm( txt,txt2,num,num2,txt3,txt4 )
	local modalDialog = createAlarmDialog( txt,txt2,num,num2,txt3,txt4 )
	return showDialog( modalDialog )
end

local function showFirstAlarm( txt,txt2,num,num2,txt3,txt4 )
	local modalDialog = createAlarmFirstDialog( txt,txt2,num,num2,txt3,txt4 )
	return showDialog( modalDialog )
end

local function showProgram( txt1,txt2,txt3,icon,color )
	local modalDialog = createProgramDialog( txt1,txt2,txt3,icon,color )
	return showDialog( modalDialog )
end

local function showWelcome()
	local t = util.tcopy( _M )

	t.onLoad = function( self )
		self.screen = mui.createScreen( "modal-posttutorial.lua" )
		mui.activateScreen( self.screen )

		local closeBtn = self.screen.binder.closeBtn.binder.btn
		closeBtn:setHotkey( mui_defs.K_ESCAPE )
		closeBtn:setText( STRINGS.UI.NEW_GAME_CONFIRM )
		closeBtn.onClick = util.makeDelegate( nil, function() t.result = OK end )
	end

	return showDialog( t )
end

local function showDisclaimer( bodyTxt, headerTxt, okTxt )
	local modalDialog = createDisclaimerDialog( bodyTxt, headerTxt, okTxt )
	return showDialog( modalDialog )
end

local function showUpdateDisclaimer( okTxt, readMoreTxt )
	local modalDialog = createUpdateDisclaimerDialog( okTxt, readMoreTxt )
	return showDialog( modalDialog )
end

return
{
	CANCEL = CANCEL,
	OK = OK,
	AUX = AUX,

	show = show,
	showYesNo = showYesNo,
	createBusyDialog = createBusyDialog,
	showAlarm = showAlarm,
	showFirstAlarm = showFirstAlarm, 
	showProgram = showProgram,
	showWelcome = showWelcome,
	showDisclaimer = showDisclaimer,
	showUpdateDisclaimer = showUpdateDisclaimer,
}
