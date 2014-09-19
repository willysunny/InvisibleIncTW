----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local mui = include( "mui/mui" )
local util = include( "client_util" )
local array = include( "modules/array" )
local serverdefs = include( "modules/serverdefs" )
local gameobj = include( "modules/game" )
local cdefs = include("client_defs")
local modalDialog = include( "states/state-modal-dialog" )
local options_dialog = include( "hud/options_dialog" )

----------------------------------------------------------------
-- Local functions

local function onClickResume( dialog )
	dialog:hide()	-- Kill this dialog.
end

local function onClickOptions( dialog )
 	dialog._options_dialog:show()
end

local function onClickQuit( dialog )
	dialog:hide()
	local result = modalDialog.showYesNo( "Do you wish to save and exit the current game?", "Save and Exit Game", nil, STRINGS.UI.SAVE_AND_EXIT )
	if result == modalDialog.OK then
		MOAIFmodDesigner.stopMusic()
		dialog._game:quitToMainMenu()
	end	
end

local function onClickRetire( dialog )
	dialog:hide()
	local result = modalDialog.showYesNo( "Are you SURE you want to retire your agency? This will cash in your earned experience.", STRINGS.UI.RETIRE_AGENCY, nil, STRINGS.UI.RETIRE_AGENCY )
	if result == modalDialog.OK then
		dialog._game.simCore:lose()
	end	
end

local function onClickAbort( dialog )
	dialog:hide()
	local result = modalDialog.showYesNo( "Are you SURE you want to abort the mission? Agents in the field will be lost.", STRINGS.UI.ABORT_MISSION, nil, STRINGS.UI.ABORT_MISSION )
	if result == modalDialog.OK then
        local sim = dialog._game.simCore
        local player = sim:getPC()
		for i,unit in pairs( player:getUnits() ) do
            if player:findAgentDefByID( unit:getID() ) then
				unit:setKO( sim , 1)
			end 
		end			
		sim:updateWinners()
	end	
end


----------------------------------------------------------------
-- Interface functions

local pause_dialog = class()

function pause_dialog:init(game)
	local screen = mui.createScreen( "pause_dialog_screen.lua" )
	self._game = game
	self._screen = screen	

	self._options_dialog = options_dialog( game )

	screen.binder.pnl.binder.resumeBtn.onClick = util.makeDelegate( nil, onClickResume, self )
	screen.binder.pnl.binder.optionsBtn.onClick = util.makeDelegate( nil, onClickOptions, self )
	screen.binder.pnl.binder.quitBtn.onClick = util.makeDelegate( nil, onClickQuit, self )
    if self._game and self._game.simCore:hasTag( "isTutorial" ) then
	    screen.binder.pnl.binder.abortBtn:setVisible( false )
	    screen.binder.pnl.binder.retireBtn:setVisible( false )
    else
	    screen.binder.pnl.binder.abortBtn.onClick = util.makeDelegate( nil, onClickAbort, self )
    	screen.binder.pnl.binder.retireBtn.onClick = util.makeDelegate( nil, onClickRetire, self )
    end
end


function pause_dialog:show()
	mui.activateScreen( self._screen )
	FMODMixer:pushMix( "quiet" )
	MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_POPUP )
end

function pause_dialog:hide()
	if self._screen:isActive() then
		mui.deactivateScreen( self._screen )
		FMODMixer:popMix( "quiet" )
	end
end


return pause_dialog
