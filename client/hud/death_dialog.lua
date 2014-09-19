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

----------------------------------------------------------------
-- Local functions

local POSITIVE_COLOR = { 140/255, 1, 1, 1 }

local function onClickOK( self, campaign )
	self:hide()

	--statemgr.deactivate( self._game )

	local score_dialog = include( "hud/score_dialog" )
	local scoreDialog = score_dialog( campaign, self._campaignWin, self._game )
	scoreDialog:show()
end

local function setRewardImage( widget, rewardData )
	if rewardData == nil then
		widget:setVisible( false )
		return
	end

	local agentdefs = include( "sim/unitdefs/agentdefs" )
	local abilitydefs = include( "sim/abilitydefs" )
	local rewardName = rewardData.name

	widget:setVisible( true )

	-- Rewards are always either AGENTS or PROGRAMS (abilities)
	if agentdefs[ rewardName ] then
		local agentDef = agentdefs[ rewardName ]
		-- Updates the agent information for the current unit (profile image, brief info text)
		if agentDef.profile_anim then
			widget.binder.img:setVisible(false)
			widget.binder.portrait:setVisible(true)
			widget.binder.portrait:bindBuild( agentDef.profile_build or agentDef.profile_anim )
			widget.binder.portrait:bindAnim( agentDef.profile_anim )
		else
			widget.binder.img:setVisible(true)
			widget.binder.portrait:setVisible(false)
			widget.binder.img:setImage( agentDef.profile_icon )	
		end

	else
		local ability = abilitydefs.lookupAbility( rewardName )
		if ability then
			widget.binder.portrait:setVisible( false )
			widget.binder.img:setVisible( true )
			widget.binder.img:setImage( ability.icon_100 )
		else
			assert( false, "Unknown reward:" .. rewardName )
		end
	end
end

----------------------------------------------------------------

local death_dialog = class()

function death_dialog:init()
	local screen = mui.createScreen( "death-dialog.lua" )

	self._screen = screen
	self._campaignWin = false
end 

function death_dialog:show( game, sim, campaignWin )
	mui.activateScreen( self._screen ) 

	MOAIFmodDesigner.stopSound("alarm")
	MOAIFmodDesigner.playSound( "SpySociety/Music/stinger_victory")
	MOAIFmodDesigner.stopMusic()

	self._game = game
	self._analysisIdx = 1
	self._campaignWin = campaignWin

	--Get/set initial XP, XP Ratio. 
	for i, widget in self._screen.binder.pnl.binder:forEach( "stat" ) do
		widget:setVisible( false )
	end

	FMODMixer:pushMix("frontend")

	self:populate( sim )
end

function death_dialog:hide()
	if self._screen:isActive() then
		mui.deactivateScreen( self._screen )
		FMODMixer:popMix("frontend")

		if self._updateThread then
			self._updateThread:stop()
			self._updateThread = nil
		end

		MOAIFmodDesigner.stopSound( "tally" )
	end
end

function death_dialog:addAnalysisStat( leftText, countNum, constantNum, color )

	local widget = nil

	widget = self._screen:findWidget( "stat" .. self._analysisIdx )
	self._analysisIdx = self._analysisIdx + 1

	if leftText == "" then
		--nothing to add, so skip this
		widget.binder.bar1:setVisible( false )
	else
		widget.binder.bar1:setVisible( true )
	end

	widget.binder.leftTxt:setColor( unpack(color) )
	widget.binder.countTxt:setColor( unpack(color) )
	widget.binder.multiply:setColor( unpack(color) )
	widget.binder.constantTxt:setColor( unpack(color) )
	widget.binder.rightTxt:setColor( unpack(color) )

	widget.binder.leftTxt:setText( leftText )
	widget.binder.countTxt:setText( countNum )
	widget.binder.multiply:setVisible( true )
	widget.binder.constantTxt:setText( constantNum )

	local rightNum = countNum * constantNum
	widget.binder.rightTxt:setText( rightNum )

	widget:setVisible( true )

	MOAIFmodDesigner.playSound("SpySociety/HUD/menu/mission_end_count")
	rig_util.wait(0.25*cdefs.SECONDS)

	return rightNum
end

function death_dialog:setCurrentProgress( currentXP, newXP )

	local currentLevel = metadefs.GetLevelForXP( currentXP )
	local prevXP, deltaXP = metadefs.GetXPForLevel( currentLevel )
	local nextXP = prevXP + deltaXP

	while currentXP < newXP do
		currentXP = math.min( newXP, nextXP )

		self._screen.binder.pnl.binder.xpTxt:setText( string.format( "%d / %d XP", currentXP, nextXP ) )
		self._screen.binder.pnl.binder.progressBar:setProgress( (currentXP - prevXP) / deltaXP )

		if currentXP >= nextXP then
			-- Gained a level.  Unlocked the thing!
			self._screen.binder.pnl.binder.portrait:setColor(1,1,1,1)
			self._screen.binder.pnl.binder.img:setColor(1,1,1,1)
			self._screen.binder.pnl.binder.unlockedTxt:setVisible(true)

			MOAIFmodDesigner.stopSound( "tally" )
			MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/unlock_agent" )

			rig_util.wait(2*cdefs.SECONDS)

			MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/tally_LP", "tally" )

			--okay back to black
			self._screen.binder.pnl.binder.portrait:setColor(0,0,0,1)
			self._screen.binder.pnl.binder.img:setColor(0,0,0,1)
			self._screen.binder.pnl.binder.unlockedTxt:setVisible(false)

			currentLevel = currentLevel + 1
			prevXP, deltaXP = metadefs.GetXPForLevel( currentLevel )
			nextXP = prevXP + deltaXP
		end
	end

	local rewardData = metadefs.GetRewardForLevel( currentLevel )
	if self._currentReward ~= rewardData then
		self._currentReward = rewardData
		setRewardImage( self._screen:findWidget( "reward" ), rewardData )
	end

	if currentXP >= metadefs.GetXPCap() then
		self._screen.binder.pnl.binder.xpTxt:setText( string.format( "%d / AT CAP!", currentXP ) )
		self._screen.binder.pnl.binder.progressBar:setProgress( 1 )
	else
		self._screen.binder.pnl.binder.xpTxt:setText( string.format( "%d / %d XP", currentXP, nextXP ) )
		self._screen.binder.pnl.binder.progressBar:setProgress( (currentXP - prevXP) / deltaXP )
	end
end

function death_dialog:updateProgress( agency, oldXp, newXp ) 
	assert( newXp >= oldXp, tostring(newXp)..">="..tostring(oldXp) )

	self:addAnalysisStat( STRINGS.UI.SECURITY_HACKED, agency.security_hacked, metadefs.XP_PER_SMALL_ACTION, POSITIVE_COLOR )
	self:addAnalysisStat( STRINGS.UI.GUARDS_KOD, agency.guards_kod, metadefs.XP_PER_SMALL_ACTION, POSITIVE_COLOR )
	self:addAnalysisStat( STRINGS.UI.SAFES_LOOTED, agency.safes_looted, metadefs.XP_PER_BIG_ACTION, POSITIVE_COLOR )
	self:addAnalysisStat( STRINGS.UI.CREDITS_EARNED, agency.credits_earned, 1, POSITIVE_COLOR )
	self:addAnalysisStat( STRINGS.UI.PROGRAMS_ACQUIRED, agency.programs_earned, metadefs.XP_PER_BIG_ACTION, POSITIVE_COLOR )
	self:addAnalysisStat( STRINGS.UI.ITEMS_PURCHASED, agency.items_earned, metadefs.XP_PER_SMALL_ACTION, POSITIVE_COLOR )
	self:addAnalysisStat( STRINGS.UI.MISSIONS_COMPLETED, agency.missions_completed, metadefs.XP_PER_MISSION, POSITIVE_COLOR )
	
	local currentXp = oldXp
	local XP_DELTA = 10 --10*60 XP per sec
	local totalXpGain = 0

	MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/tally_LP", "tally" )
	while currentXp < newXp do
		local xpGain = math.min( XP_DELTA, newXp - currentXp )

		self._screen.binder.pnl.binder.statFinal.binder.rightTxt:setText( totalXpGain + xpGain )

		self:setCurrentProgress( currentXp, currentXp + xpGain )
		currentXp = currentXp + xpGain
		totalXpGain = totalXpGain + xpGain
		
		coroutine.yield()
	end

	MOAIFmodDesigner.stopSound( "tally" )
end

function death_dialog:populate( sim )
	local user = savefiles.getCurrentGame()
	local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]
	
	local oldXp = math.min( metadefs.GetXPCap(), user.data.xp or 0)
	self:setCurrentProgress( oldXp, oldXp )

	self._screen.binder.pnl.binder.statFinal:setVisible( false )

	self._screen.binder.pnl.binder.okBtn.binder.btn:setText( STRINGS.UI.CONTINUE )
	self._screen.binder.pnl.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, onClickOK, self, campaign )

	-- Officially update and clear the campaign data from the savegame.  Also assigns XPs/rewards.
	serverdefs.updateStats( campaign.agency, sim )

	self._screen.binder.pnl.binder.statFinal:setVisible(true)
	self._screen.binder.pnl.binder.statFinal.binder.rightTxt:setText(0)

	if self._campaignWin == true then
		self._screen.binder.pnl.binder.titleTxt:setText( STRINGS.UI.CAMPAIGN_COMPLETE )
		savefiles.addCompletedGame( "VICTORY" )
	else
		self._screen.binder.pnl.binder.titleTxt:setText( STRINGS.UI.TEAM_ELIMINATED )
		savefiles.addCompletedGame( "FAILURE" )
	end

	self._updateThread = MOAICoroutine.new()
	self._updateThread:run( self.updateProgress, self, campaign.agency, oldXp, user.data.xp )
end

return death_dialog