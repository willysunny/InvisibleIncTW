----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include("client_util")
local cdefs = include("client_defs")
local mui = include( "mui/mui" )
local serverdefs = include( "modules/serverdefs" )
local scroll_text = include("hud/scroll_text")

----------------------------------------------------------------
-- Locals

local stateStats = {}

local function onClickDone()
	statemgr.deactivate( stateStats )
end

----------------------------------------------------------------
-- Stats screen.

function stateStats:refreshStats()
	local user = savefiles.getCurrentGame()

	self.screen.binder.listBox:clearItems()

	for i, game in ipairs( user.data.top_games ) do
		local widget = self.screen.binder.listBox:addItem( game )
		widget.binder.numTxt:setText( string.format( "#%d", i ) )
		widget.binder.dateTxt:setText( os.date( nil, game.complete_time ) )
		widget.binder.infoTxt:setText( string.format( "<c:b3b3f3>%s</> : %s\nHOUR: %s, CREDITS: %d, PLAYTIME: %d secs",
			game.agency.name, tostring(game.result), tostring(game.hours), game.agency.cash, game.play_t ))

	end
end

function stateStats:onLoad()
	self.screen = mui.createScreen( "stats_screen.lua" )
	mui.activateScreen( self.screen )
	
	self._scroll_text = scroll_text.panel( self.screen.binder.bg )

	self.screen.binder.doneBtn.onClick = onClickDone

	self:refreshStats()
end

function stateStats.onUnload()
	stateStats._scroll_text:destroy()
	mui.deactivateScreen( stateStats.screen )
end

return stateStats
