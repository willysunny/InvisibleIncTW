----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local modalDialog = include( "states/state-modal-dialog" )
local mui = include("mui/mui")
local array = include( "modules/array" )
local util = include("client_util")
local guiex = include( "guiex" )
local stateFeedback = {}

stateFeedback.onClickCancel = function( self )
	statemgr.deactivate( self )
end

stateFeedback.onClickSend = function( self )
	local feedbackTxt = self.screen.binder.editBox:getText()
	local task = cloud.sendSlackTask( util.formatGameInfo( self.game and self.game.params ) .. "\n-----\n" .. feedbackTxt, "#invisibleinc-feedback" )
	guiex.createDialogTask( "Sending Feedback...", task,
		function( result, responseCode )
			if responseCode == cloud.HTTP_OK then
				modalDialog.show( "Thank you for your feedback!" )
			else
				modalDialog.show(
					string.format( "There was an error sending feedback (%d - %s).  Please try again later or visit our forums.", tostring(responseCode), util.tostringl(result) ) )
			end
			statemgr.deactivate( self )
		end )
end

local function onClickForums()
	MOAISim.visitURL( config.FORUM_URL )
end

----------------------------------------------------------------
stateFeedback.onLoad = function ( self, game )
	self.screen = mui.createScreen( "modal-feedback.lua" )
	mui.activateScreen( self.screen )
	self.game = game

	self.screen.binder.cancelBtn.onClick = util.makeDelegate(self, "onClickCancel")
	self.screen.binder.sendBtn.onClick = util.makeDelegate(self, "onClickSend")
	self.screen.binder.forumBtn.onClickImmediate = onClickForums
	self.screen.binder.forumBtn:setTooltip( config.FORUM_URL )
end

----------------------------------------------------------------
stateFeedback.onUnload = function ( self )
	mui.deactivateScreen( self.screen )
	self.screen = nil
end

return stateFeedback

