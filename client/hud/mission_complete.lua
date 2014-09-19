----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
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

----------------------------------------------------------------
-- Local functions

local POSITIVE_COLOR = { 140/255, 1, 1, 1 }
local NEGATIVE_COLOR = { 233/255, 145/255, 145/255, 1 }

local NUM_MISSIONS_TO_SPAWN = 3
local HOURS_BEFORE_SPAWN = 24
local HOURS_BEFORE_DIFFICULTY = 24

local CLEANING_COST_BASE = 50 
local CLEANING_COST_EXPONENT = 1.3

local function calculateExplorationBonus( sim, player )
	local exploreCount = 0
	local totalCount = 0
	sim:forEachCell(
		function( cell )
			if not cell.isSolid then
				totalCount = totalCount + 1
				if player:getCell( cell.x, cell.y ) ~= nil then
					exploreCount = exploreCount + 1
				end
			end
		end )


	local explorePercent = exploreCount / totalCount

	return explorePercent
end

local function onClickCampaignComplete( dialog, sim )
	dialog:hide()

	local death_dialog = include( "hud/death_dialog" )
	local rewardsDialog = death_dialog()
	rewardsDialog:show( dialog._game, sim, true )
end

local function onClickTutorial( dialog )
	local stateTeamPreview = include( "states/state-team-preview" )

	FMODMixer:popMix("frontend")
	dialog:hide()	-- Kill this dialog.

	statemgr.deactivate( dialog._game )
	statemgr.activate( stateTeamPreview )
end

local function onClickCORP( dialog, agency )
	local stateLoading = include( "states/state-loading" )

	FMODMixer:popMix("frontend")
	dialog:hide()	-- Kill this dialog.

	statemgr.deactivate( dialog._game )
	stateLoading:loadUpgradeScreen( agency )
end

----------------------------------------------------------------
-- Interface functions

local mission_complete = class()

function mission_complete:updateAgencyFromSim( agency, sim, situation )
	local player = sim:getPC()

	serverdefs.updateStats( agency, sim )
	sim:getStats():incStat( "missions_completed" )

	-- Transfer player abilities
	agency.abilities = {}
	for _, ability in ipairs( player:getAbilities() ) do
		if not ability.no_save then
			table.insert( agency.abilities, ability:getID() )
		end
	end

	-- Transfer agent data.
	agency.newCorpData = 0
	local numAgentsHired = 0
	local i = 0
	for agentID, deployData in pairs( player:getDeployed() ) do
		local agentDef = serverdefs.findAgent( agency, agentID )

		-- deployData.id existence implies this agent was deployed and assigned a unit ID.			
		if deployData.id then
			i = i + 1
			local reequipped = false
			if agentDef == nil then
				-- This is a rescued unit that doesn't exist in the agency, yet.
				agentDef = serverdefs.assignAgent( agency, deployData.agentDef.template )
				reequipped = true
				numAgentsHired = numAgentsHired + 1
			else
				util.tclear( agentDef.upgrades )
			end

			if deployData.escapedUnit then
				-- Feh.  Clear upgrades so we can add them back from the sim unit's inventory.
				
					
				for _,childUnit in ipairs( deployData.escapedUnit:getChildren() ) do
					local upgradeName = childUnit:getUnitData().upgradeName
					if upgradeName then
						local upgradeParams = childUnit:getUnitData().createUpgradeParams and childUnit:getUnitData():createUpgradeParams( childUnit )
						table.insert( agentDef.upgrades, { upgradeName = upgradeName, upgradeParams = upgradeParams })
					end

					if childUnit:getTraits().newLocations then
						if agency.newLocations then
							agency.newLocations = agency.newLocations + childUnit:getTraits().newLocations
						else
							agency.newLocations = childUnit:getTraits().newLocations
						end
					end

					if childUnit:getTraits().score then
						local itemScore = childUnit:getTraits().score * simdefs.DIFFICULTY_REPUTATION_MULT[ sim:getParams().gameDifficulty ] 

						if agency.score then
							agency.score = agency.score + itemScore
						else
							agency.score = itemScore
						end

						agency.newCorpData = agency.newCorpData + 1
					end

					if childUnit:getTraits().artifact then
						local value = childUnit:getTraits().cashInReward * serverdefs.MONEY_SCALAR[ situation.difficulty] * simdefs.DIFFICULTY_MONEY_SCALAR[ sim:getParams().gameDifficulty ]

						sim:addMissionReward(value)
					end					

				end

				agentDef.skills = {}
				for _, skill in ipairs( deployData.escapedUnit:getSkills() ) do
					table.insert( agentDef.skills, { skillID = skill:getID(), level = skill:getCurrentLevel() } )
				end

				agentDef.abilities = {}
				for _, ability in ipairs( deployData.escapedUnit:getAbilities() ) do
					table.insert( agentDef.abilities, ability:getID() )
				end

				-- Keep track which exit this agent escaped from.
				agentDef.deployID = deployData.exitID

				local widget = self._screen:findWidget( "agent" .. i )				
				local data = deployData.escapedUnit:getUnitData()
				widget.binder.name:setText( util.toupper(deployData.escapedUnit:getName()) )
				if reequipped then
					widget.binder.details:setText( STRINGS.UI.REEQUIPPED )
				else
					widget.binder.details:setText( STRINGS.UI.ACTIVE )
				end
				widget.binder.profile:setImage(data.profile_icon_64x64)
				widget:setVisible( true )

			else
				-- Remove this agent from the agency.
				for k,v in pairs(agency.unitDefs) do
					if v.id == agentDef.id then
						local widget = self._screen:findWidget( "agent" .. i )				
						widget.binder.bgMIA:setVisible(false)
						local data = agentdefs[agency.unitDefs[k].template]
						widget.binder.name:setText( util.toupper(data.name) )
						if not deployData.escapedUnit then
							widget.binder.details:setText( STRINGS.UI.MIA)
							widget.binder.profile:setImageState( "mia" )
							widget.binder.bg:setVisible(false)
							widget.binder.bgMIA:setVisible(true)
							self._agents_lost = self._agents_lost + 1
						else
							widget.binder.details:setText( STRINGS.UI.NOT_PAID)
							widget.binder.profile:setImage(data.profile_icon)
						end
						widget:setVisible( true )
						table.remove( agency.unitDefs, k )
					end
				end
			end
		end
	end

	if numAgentsHired > 0 then
		self:addAnalysisStat( STRINGS.UI.AGENTS_HIRED, numAgentsHired, POSITIVE_COLOR )
	end

end


function mission_complete:init()
	local screen = mui.createScreen( "mission_complete.lua" )

	self._screen = screen	
	self._loot = 0
	self._disk = 0
	self._selected = nil	

	self._agents_lost = 0
end

function mission_complete:show( game, sim )
	mui.activateScreen( self._screen )

	MOAIFmodDesigner.stopSound("alarm")
	MOAIFmodDesigner.playSound( "SpySociety/Music/stinger_victory")
	MOAIFmodDesigner.stopMusic()

	self._game = game
	self._analysisIdx, self._totalIdx = 1, 1

	FMODMixer:pushMix("frontend")

	for i, widget in self._screen.binder.pnl.binder:forEach( "stat" ) do
		widget:setVisible( false )
	end
	self._screen.binder.pnl.binder.statlast:setVisible( false )

	for i, widget in self._screen.binder.pnl.binder:forEach( "agent" ) do
		widget:setVisible( false )
	end

	self._updateThread = MOAICoroutine.new()
	self._updateThread:run( function() self:doWinMission(sim) end )
end

function mission_complete:hide()

	if self._screen:isActive() then
		mui.deactivateScreen( self._screen )
		FMODMixer:popMix("frontend")

		if self._missionBlinkThread then
			self._missionBlinkThread:stop()
			self._missionBlinkThread = nil		
		end
	end
end

function mission_complete:addAnalysisStat( leftText, rightText, color, statname )
	
	local widget = nil

	if statname then
		widget = self._screen:findWidget( statname )
	else
		widget = self._screen:findWidget( "stat" .. self._analysisIdx )
		self._analysisIdx = self._analysisIdx + 1
	end

	if leftText == "" then
		--nothing to add, so skip this
		widget.binder.bar1:setVisible( false )
	else
		widget.binder.bar1:setVisible( true )
		rig_util.wait(0.25*cdefs.SECONDS)
		MOAIFmodDesigner.playSound("SpySociety/HUD/menu/mission_end_count")
	end

	widget.binder.leftTxt:setColor( unpack(color) )
	widget.binder.rightTxt:setColor( unpack(color) )

	widget.binder.leftTxt:setText( leftText )
	widget.binder.rightTxt:setText( rightText )
	widget:setVisible( true )
end

function mission_complete:calculateStats( campaign, sim )
	local creditBonus = 0

	local explorePercent = calculateExplorationBonus( sim, sim:getPC() )

	--1
	self:addAnalysisStat( STRINGS.UI.CURRENT_CREDITS,  string.format("$"..campaign.agency.cash ), POSITIVE_COLOR )

	--2
	local missionReward = sim:getMissionReward()
	if missionReward ~= nil then
		self:addAnalysisStat( STRINGS.UI.MISSION_REWARD, string.format("$"..missionReward), POSITIVE_COLOR )
		creditBonus = creditBonus + missionReward
	end

	local PER_CORP_DATA_BONUS = 100
	local corpDataBonus = campaign.agency.newCorpData*PER_CORP_DATA_BONUS
	self:addAnalysisStat( STRINGS.UI.CORPORATE_INTEL, string.format("$"..corpDataBonus), POSITIVE_COLOR )
	creditBonus = creditBonus + corpDataBonus

	--2 / 3
	self:addAnalysisStat( STRINGS.UI.MAP_EXPLORATION, math.floor(explorePercent * 100) .. "%", POSITIVE_COLOR )

	--4 / 5
	if campaign.agency.newLocations then
		self:addAnalysisStat( STRINGS.UI.CORPORATE_MAP, campaign.agency.newLocations, POSITIVE_COLOR )
	else
		self:addAnalysisStat( "", "", POSITIVE_COLOR )
	end

	--5 / 6
	local cleaningKills = sim:getCleaningKills()
	self:addAnalysisStat( STRINGS.UI.KILLS,  cleaningKills, NEGATIVE_COLOR )

	--6 / 7
	local alarmLvl = sim:getTrackerStage()
	self:addAnalysisStat( STRINGS.UI.ALARM_LEVEL, alarmLvl, NEGATIVE_COLOR )

	if sim:getWinner() then
		local cleaningBonus = 0
		--print( "kills: "..cleaningKills )
		if cleaningKills > 0 then
			cleaningBonus = math.floor( (cleaningKills ^ CLEANING_COST_EXPONENT) * CLEANING_COST_BASE)
		end

		--7
		self:addAnalysisStat( STRINGS.UI.CLEAN_UP_COST, string.format("-$"..cleaningBonus), NEGATIVE_COLOR )

		creditBonus = creditBonus - cleaningBonus
	else
		--7
		self:addAnalysisStat( "", "", POSITIVE_COLOR )
	end
	
	--sim:getPC():addCredits( creditBonus )

	--8
	self:addAnalysisStat( STRINGS.UI.TOTAL_CREDITS,  string.format("$"..(campaign.agency.cash +creditBonus) ), POSITIVE_COLOR, "statlast" )
	
	return creditBonus
end

function mission_complete:doWinMission( sim )
	local user = savefiles.getCurrentGame()
	-- Update the save game for a win.
	local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]
	
	self._screen.binder.pnl.binder.okBtn.binder.btn:setText( STRINGS.UI.CONTINUE )

	self:updateAgencyFromSim( campaign.agency, sim, campaign.situation )

	local creditBonus = self:calculateStats( campaign, sim )
	campaign.agency.cash = math.max(0, campaign.agency.cash + creditBonus)

	local situationTime = serverdefs.calculateTravelTime( campaign.location, campaign.situation.mapLocation ) + serverdefs.BASE_TRAVEL_TIME
	local numSituations = NUM_MISSIONS_TO_SPAWN * ( math.floor((campaign.hours + situationTime) / HOURS_BEFORE_SPAWN) - math.floor(campaign.hours / HOURS_BEFORE_SPAWN) )
	numSituations = numSituations + (campaign.agency.newLocations or 0)
	campaign.agency.newLocations = nil

	local situations = campaign.situations

	--If no situations left, accel campaign time to next day and then do new mission spawns. 
	if #situations <= 0 and numSituations <= 0 then
		numSituations = NUM_MISSIONS_TO_SPAWN 
		local nextSpawn = math.ceil( (campaign.hours + situationTime) / HOURS_BEFORE_SPAWN ) * HOURS_BEFORE_SPAWN
		situationTime = nextSpawn - campaign.hours
	end 

	--If we passed a day mark then do the day wipe and up the difficulty
	if (math.floor((campaign.hours + situationTime) / HOURS_BEFORE_DIFFICULTY) - math.floor(campaign.hours / HOURS_BEFORE_DIFFICULTY)) > 0 then 
		campaign.raiseDifficulty = true 
		campaign.dayPassed = true

		for i,situation in ipairs(campaign.situations) do
			if situation.difficulty < 4 then 
				situation.difficulty = situation.difficulty + 1 
			end
		end 

	else 
		campaign.raiseDifficulty = false
		campaign.dayPassed = false 
	end

	serverdefs.advanceCampaignTime( campaign, situationTime )

	campaign.location = campaign.situation.mapLocation

	serverdefs.createCampaignSituations( campaign, numSituations )

	campaign.missionCount = campaign.missionCount + 1
	campaign.sim_history = nil
	campaign.uiMemento = nil

	-- Tutorial speciality: go to Team Select
	if campaign.situation.name == serverdefs.TUTORIAL_SITUATION then
		self._screen.binder.pnl.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, onClickTutorial, self, campaign )
		-- Clear tutorial save-game, new one will be recreated.
		user.data.saveSlots[ user.data.currentSaveSlot ] = nil
	else
		if serverdefs.isFinalMission( campaign ) then
			--open "death" screen
			self._screen.binder.pnl.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, onClickCampaignComplete, self, sim )
		else
			self._screen.binder.pnl.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, onClickCORP, self, campaign.agency )
		end
		campaign.situation = nil
	end

	user:save()

	self._missionBlinkThread = MOAICoroutine.new()
	self._missionBlinkThread:run( function() 
		local i = 0
		while true do
			i = i + 1
			if i % 60 == 0 then
				self._screen.binder.pnl.binder.titleTxt:setText(STRINGS.UI.MISSION_COMPLETE)
			elseif i % 30 == 0 then
				self._screen.binder.pnl.binder.titleTxt:setText(STRINGS.UI.MISSION_COMPLETE.."_")
			end

			coroutine.yield()
		end
	end )
	self._missionBlinkThread:resume()	

end

return mission_complete
