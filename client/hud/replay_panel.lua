----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local mui = include( "mui/mui" )
local client_util = include( "client_util" )
local util = include("modules/util")
local simdefs = include( "sim/simdefs" )

include( "class" )

----------------------------------------------------------------
-- Local functions

local MODE_PAUSE = 0
local MODE_PLAY = 1

local function onClickRewind( panel )
	panel._game:stepBack()
	panel:clearEvents()
	panel:updatePanel()
end

local function onClickFF( panel )
	panel._game:step()
	panel:updatePanel()
end

local function onClickReset( panel )
	-- Keep only the first (deploy) action
	panel._game:goto( 1 )
	panel:clearEvents()
	panel._game.simHistory = { panel._game.simHistory[1] }
end

local function onClickPlayPause( panel )
	if panel._game.debugStep ~= nil then
		panel._game.debugStep = nil
	else
		panel._game.debugStep = true
	end
	panel:updatePanel()
end

local function onClickEventUp( panel )
	panel:changeFocusEvent(1)
	panel:updatePanel()	
end

local function onClickEventDwn( panel )
	panel:changeFocusEvent(-1)
	panel:updatePanel()	
end


local function onSliderStart( panel, slider, value )
end

local function onSliderStop( panel, slider, value )
	local idx = math.floor(value)
	if idx ~= panel._game.simHistoryIdx then
		panel._game:goto( idx )
		panel:clearEvents()
	end
end

local function onSliderChanged( panel, slider, value )
	local idx = math.floor(value)
	local action = panel._game.simHistory[ idx ]
	local str = string.format( "%d/%d", idx, #panel._game.simHistory )

	if action and action.playerIndex then
		str = str .. string.format( " (P%d - %s)", action.playerIndex, action.name )
	end

	panel:clearEvents()
	panel._screen.binder.replayTxt:setText( str )

	-- if value ~= panel._game.simHistoryIdx and not slider:isSliding() then
	-- 	panel._game:goto( idx )
	-- end
end


----------------------------------------------------------------
-- Interface functions

local replay_panel = class()

function replay_panel:init( game )
	self._game = game
	self._screen = mui.createScreen( "replay-dialog.lua" )
	self._events = {}
	self._focusEvent = 1

	mui.activateScreen( self._screen )
	
	self._screen.binder.rewindBtn.onClick = client_util.makeDelegate( nil, onClickRewind, self )
	self._screen.binder.ffBtn.onClick = client_util.makeDelegate( nil, onClickFF, self )
	self._screen.binder.playBtn.onClick = client_util.makeDelegate( nil, onClickPlayPause, self )
	self._screen.binder.resetBtn.onClick = client_util.makeDelegate( nil, onClickReset, self )
	self._screen.binder.slider.onValueChanged = client_util.makeDelegate( nil, onSliderChanged, self )
	self._screen.binder.slider.onSliderStart = client_util.makeDelegate( nil, onSliderStart, self )
	self._screen.binder.slider.onSliderStop = client_util.makeDelegate( nil, onSliderStop, self )
	self._screen.binder.slider:setRange( 0, #game.simHistory )
	self._screen.binder.slider:setStep( 1 )
	self._screen.binder.eventUpBtn.onClick = client_util.makeDelegate( nil, onClickEventUp, self )
	self._screen.binder.eventDwnBtn.onClick = client_util.makeDelegate( nil, onClickEventDwn, self )

	self:updatePanel()
end

function replay_panel:destroy()
	mui.deactivateScreen( self._screen )
	self._screen = nil
end

function replay_panel:updatePanel()
	
	self._screen.binder.slider:setRange( 0, #self._game.simHistory )
	if not self._screen.binder.slider:isSliding() then
		self._screen.binder.slider:setValue( self._game.simHistoryIdx )
	end

	local str = string.format( "%d/%d", self._game.simHistoryIdx, #self._game.simHistory )
	
	if self._game.simThread then
		local t = debug.getinfo( self._game.simThread, 3 )
		if t == nil then
			str = str .. " PLAYING"
		else
			local line = string.format( " %s:%d: %s", t.short_src, t.currentline, tostring(t.name))
			str = str .. line
		end
	end

	if self._game.debugStep ~= nil then
		self._screen.binder.playBtn:setText( ">" )
		if #self._events > 0 then
			local events = {}
			local maxEventsToDisplay = 20
			for i = math.min(self._focusEvent, #self._events), math.max(self._focusEvent-maxEventsToDisplay, 1), -1 do
				local str = " "
				if i == self._focusEvent then
					str = ">"
				end
				str = str..tostring(i)..": "..util.debugPrintTableWithColours(self._events[i].debug, 2)
				table.insert(events, str)
			end

			self._screen.binder.eventsTxt:setText(table.concat(events, "\n") )
			self._screen.binder.stackTxt:setText(self._events[self._focusEvent].stack)
		else
			self._screen.binder.eventsTxt:setText("")
			self._screen.binder.stackTxt:setText("")
		end
	else
		self._screen.binder.playBtn:setText( "||" )
		self._screen.binder.eventsTxt:setText("")
	end

	self._screen.binder.replayTxt:setText( str )
end

function replay_panel:addEvent(event, stack)
	--translate the event type
	local eventDebug = {eventType = simdefs:stringForEvent(event.eventType), eventData = event.eventData}
	table.insert(self._events, {debug=eventDebug, stack=stack} )
	self._focusEvent = #self._events
end

function replay_panel:changeFocusEvent(delta)
	self._focusEvent = math.min(#self._events, math.max(1, self._focusEvent+delta) )
end

function replay_panel:clearEvents()
	self._events = {}
	self:updatePanel()
end

function replay_panel:setVisible( isVisible )
	self._screen:setVisible( isVisible )
end

return replay_panel
