----------------------------------------------------------------
-- Copyright (c) 2014 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local mui = include( "mui/mui" )
local util = include( "client_util" )
local array = include( "modules/array" )
local serverdefs = include( "modules/serverdefs" )
local version = include( "modules/version" )
local gameobj = include( "modules/game" )
local cdefs = include("client_defs")
local agentdefs = include("sim/unitdefs/agentdefs")
local simdefs = include( "sim/simdefs" )
local STRINGS = include( "strings" )
local rig_util = include( "gameplay/rig_util" )
local metadefs = include( "sim/metadefs" )
local guiex = include( "client/guiex" )
local modalDialog = include( "states/state-modal-dialog" )

----------------------------------------------------------------
-- Local functions

local POSITIVE_COLOR = { 140/255, 1, 1, 1 }

local function onClickLogout( screen )

	local user = savefiles.getCurrentGame()

	if user.data.storyWins == 1 and screen._win then
		--first win!
		modalDialog.show( STRINGS.UI.ENDLESS_MODE_DESC, STRINGS.UI.ENDLESS_MODE_UNLOCKED )
	end

	local stateLoading = include( "states/state-loading" )

	assert(screen._game)
	statemgr.deactivate( screen._game )

	FMODMixer:popMix("frontend")
	screen:hide()	-- Kill this screen.

	stateLoading:loadFrontEnd()
end

local function onClickRetry( screen )
	local stateTeamPreview = include( "states/state-team-preview" )
	local user = savefiles.getCurrentGame()

	if user.data.storyWins == 1 and screen._win then
		--first win!
		modalDialog.show( STRINGS.UI.ENDLESS_MODE_DESC, STRINGS.UI.ENDLESS_MODE_UNLOCKED )
	end

	statemgr.deactivate( screen._game )

	FMODMixer:popMix("frontend")
	screen:hide()	-- Kill this dialog.

	statemgr.activate( stateTeamPreview, screen._campaign.endless )
end


----------------------------------------------------------------

local score_dialog = class()

function score_dialog:init( campaign, win, game )
	local screen = mui.createScreen( "score-dialog.lua" )

	self._game = game
	self._screen = screen
	self._campaign = campaign
	self._win = win
end 

function score_dialog:populateScore(panel)
	local score = self._campaign.agency.score or 0
	local finalScore = score + self._campaign.agency.cash

	local user = savefiles.getCurrentGame()
	local oldMaxScore = user.data.maxScore or 0

	if finalScore > oldMaxScore then
		user.data.maxScore = finalScore
	end

	user:save()

	panel.binder.scoreVal:setText(0)
	panel.binder.creditsVal:setText( "$0" )
	panel.binder.finalVal:setText( 0 )
	panel.binder.newHighScore:setVisible(false)

	local COUNT_SPEED = 1

	if score > 0 then
		MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/tally_LP", "tally" )		
		self._scoreCounterThread2 = guiex.createCountUpThread( panel.binder.scoreVal, 0, score, COUNT_SPEED )
		rig_util.wait( COUNT_SPEED*cdefs.SECONDS )
		MOAIFmodDesigner.stopSound( "tally" )		

		rig_util.wait( 0.25*cdefs.SECONDS )
	end

	if self._campaign.agency.cash > 0 then
		MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/tally_LP", "tally" )

		self._scoreCounterThread1 = guiex.createCountUpThread( panel.binder.creditsVal, 0, self._campaign.agency.cash, COUNT_SPEED, "$%d" )
		rig_util.wait( COUNT_SPEED*cdefs.SECONDS )
		MOAIFmodDesigner.stopSound( "tally" )		

		rig_util.wait( 0.25*cdefs.SECONDS )
	end

	if finalScore > 0 then
		self._scoreCounterThread3 = guiex.createCountUpThread( panel.binder.finalVal, 0, finalScore, COUNT_SPEED )

		if finalScore > oldMaxScore then

			MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/tally_LP", "tally" )
			local waitTime = (oldMaxScore / finalScore)*COUNT_SPEED*cdefs.SECONDS
			rig_util.wait( waitTime )

			MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/unlock" )
			panel.binder.newHighScore:setVisible(true)

			rig_util.wait( COUNT_SPEED*cdefs.SECONDS - waitTime )

			MOAIFmodDesigner.stopSound( "tally" )		
			rig_util.wait( 0.25*cdefs.SECONDS )
		else	
			MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/tally_LP", "tally" )
			rig_util.wait( COUNT_SPEED*cdefs.SECONDS )
			MOAIFmodDesigner.stopSound( "tally" )		
			rig_util.wait( 0.25*cdefs.SECONDS )
		end
	end
end

function score_dialog:show()
	mui.activateScreen( self._screen ) 

	FMODMixer:pushMix("frontend")

	self._screen.binder.pnl.binder.retryBtn:setText( STRINGS.UI.RETRY )
	self._screen.binder.pnl.binder.retryBtn.onClick = util.makeDelegate( nil, onClickRetry, self )
	self._screen.binder.pnl.binder.logoutBtn:setText( STRINGS.UI.EXIT )
	self._screen.binder.pnl.binder.logoutBtn.onClick = util.makeDelegate( nil, onClickLogout, self )

	self._populateThread = MOAICoroutine.new()
	self._populateThread:run( function() 
		self:populateScore(self._screen.binder.pnl)
	end)
end

function score_dialog:hide()
	if self._screen:isActive() then

		mui.deactivateScreen( self._screen )
		FMODMixer:popMix("frontend")

		if self._scoreCounterThread1 then
			self._scoreCounterThread1:stop()
			self._scoreCounterThread1 = nil
		end

		if self._scoreCounterThread2 then
			self._scoreCounterThread2:stop()
			self._scoreCounterThread2 = nil
		end

		if self._scoreCounterThread3 then
			self._scoreCounterThread3:stop()
			self._scoreCounterThread3 = nil
		end

		if self._populateThread then
			self._populateThread:stop()
			self._populateThread = nil
		end

		MOAIFmodDesigner.stopSound( "tally" )
	end
end


return score_dialog