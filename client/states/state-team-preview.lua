----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local game = include( "modules/game" )
local util = include("client_util")
local array = include( "modules/array" )
local mui = include( "mui/mui" )
local serverdefs = include( "modules/serverdefs" )
local stateCampaignGame = include( "states/state-campaigngame" )
local modalDialog = include( "states/state-modal-dialog" )
local rig_util = include( "gameplay/rig_util" )
local cdefs = include("client_defs")
local skilldefs = include( "sim/skilldefs" )
local tool_templates = include("sim/unitdefs/itemdefs")
local mainframe_abilities = include( "sim/abilities/mainframe_abilities" )
local scroll_text = include("hud/scroll_text")
local unitdefs = include( "sim/unitdefs" )
local metadefs = include( "sim/metadefs" )
local simdefs = include( "sim/simdefs" )
local simfactory = include( "sim/simfactory" )

----------------------------------------------------------------

local SET_COLOR = {r=244/255,g=255/255,b=120/255, a=1}
local POSSIBLE_COLOR = {r=0/255,g=184/255,b=0/255, a=1}
local BLANK_COLOR = {r=56/255,g=96/255,b=96/255, a=200/255}
local HOVER_COLOR = {r=255/255,g=255/255,b=255/255, a=1}
local HOVER_COLOR_FAIL = {r=178/255,g=0/255,b=0/255, a=1}

local ACTIVE_TXT = { 61/255,81/255,83/255,1 }
local INACTIVE_TXT = { 1,1,1,1 }

local ACTIVE_BG = { 244/255, 255/255, 120/255,1 }
local INACTIVE_BG = { 78/255, 136/255, 136/255,1 }

local teamPreview = {}

local function lookupTemplate( name )
	return tool_templates[ name ] 
end

local function onClickCampaign(self)

	local agentIDs = {}
	for k,v in ipairs(self._selectedAgents) do
		local agentName = serverdefs.SELECTABLE_AGENTS[v]
		if metadefs.isRewardUnlocked( agentName ) then
			agentIDs[k] = agentName
		else
			modalDialog.show( STRINGS.UI.TEAM_SELECT.LOCKED_LOADOUT )
			return
		end
	end

	local programIDs = {}
	for k,v in ipairs(self._selectedPrograms) do
		local programName = serverdefs.SELECTABLE_PROGRAMS[v]
		if metadefs.isRewardUnlocked( programName ) then
			programIDs[k] = programName
		else
			modalDialog.show( STRINGS.UI.TEAM_SELECT.LOCKED_LOADOUT )
			return
		end
	end

	local selectedAgency = serverdefs.createAgency( agentIDs, programIDs )
	local campaign = serverdefs.createNewCampaign( selectedAgency, false )

	if self._endlessMode then
		campaign.endless = true
	end

	local user = savefiles.getCurrentGame()
	user.data.saveSlots[ user.data.currentSaveSlot ] = campaign
	user.data.num_campaigns = (user.data.num_campaigns or 0) + 1
	user.data.lastDifficulty = self._selectedDifficulty
	campaign.gameDifficulty = self._selectedDifficulty
	user:save()

	local stateMapScreen = include( "states/state-map-screen" )
	statemgr.deactivate( teamPreview )

	statemgr.activate( stateMapScreen, campaign )

	if self._dialog then
		self._dialog:close()
		self._dialog = nil
	end
end

local function onClickCancel(self)
	local stateMainMenu = include( "states/state-main-menu" )
	statemgr.deactivate( teamPreview )
	statemgr.activate( stateMainMenu )

	if self._dialog then
		self._dialog:close()
		self._dialog = nil
	end	
end

local function selectProgram( self, programIdx, programID )
	local programPanel = self._panel.binder["program"..programIdx]
	local programData =  mainframe_abilities[programID]

	if metadefs.isRewardUnlocked( programID ) then
		programPanel.binder["programIcon"]:setImage(programData.icon)
		programPanel.binder["programIcon"]:setColor(1,1,1)
		programPanel.binder["programName"]:setText(util.toupper(programData.name))
		programPanel.binder["programTxt"]:spoolText( programData.desc )
		programPanel.binder["programTxt"]:setColor(140/255,255/255,255/255)	

		if programData.break_firewalls > 0 then
			programPanel.binder["powerTxt"]:setText(tostring(programData.break_firewalls))
		else
			programPanel.binder["powerTxt"]:setText("-")
		end

		if programData.cpu_cost then 
			for i, widget in programPanel.binder:forEach( "power" ) do	
				if i<=programData.cpu_cost then
					widget:setColor(140/255,255/255,255/255)
				else
					widget:setColor(17/255,29/255,29/255)
				end
			end
		else
			for i, widget in programPanel.binder:forEach( "power" ) do
				widget:setColor(17/255,29/255,29/255)
			end
		end

	else
		programPanel.binder["programIcon"]:setImage(programData.icon)
		programPanel.binder["programIcon"]:setColor(0,0,0)
		programPanel.binder["programName"]:setText( STRINGS.UI.TEAM_SELECT.LOCKED_AGENT_NAME )
		programPanel.binder["programTxt"]:setText( STRINGS.UI.TEAM_SELECT.UNLOCK_TO_USE )
		programPanel.binder["programTxt"]:setColor( 1, 1, 1 )

		programPanel.binder["powerTxt"]:setText("?")

		for i, widget in programPanel.binder:forEach( "power" ) do
			widget:setColor(17/255,29/255,29/255)
		end
	end



	programPanel:setVisible(true)
end

local function selectAgent( self, agentIdx, agentID, transition )
	-- Show team info

	-- Show the agents on the team
	local agentDef = unitdefs.lookupTemplate( agentID )
	assert( agentDef )

	local agentWidget = self._panel.binder[ "agent" .. agentIdx ]

	rig_util.wait(0.2*cdefs.SECONDS)
	MOAIFmodDesigner.playSound( "SpySociety/HUD/menu/popdown" )

	if transition then
		agentWidget:createTransition( "activate_left" )
	end

	agentWidget:setVisible(true)
	--agentWidget.binder.fadeBox:blinkWhiteTransition()

	if metadefs.isRewardUnlocked( agentID ) then
		agentWidget.binder.agentName:spoolText(util.toupper(agentDef.name),15)

		if agentDef.team_select_img then
			agentWidget.binder.agentImg:setImage(agentDef.team_select_img[1])		
			agentWidget.binder.agentImg:setColor(1,1,1)
			agentWidget.binder.agentImg:createTransition("activate_left")
			agentWidget.binder.agentImgBG:createTransition("activate_left")
		end
	
		local fluff = "REAL NAME: ".. agentDef.fullname .." / SERVICE: ".. agentDef.yearsOfService .." YEARS / STATUS: ACTIVE"
		agentWidget.binder.fluffTxt:spoolText(util.toupper(fluff))


		-- item icons
		for i, widget in agentWidget.binder:forEach( "item" ) do
			if agentDef.upgrades[i] then
				widget:setVisible(true)

				local unitData = lookupTemplate( agentDef.upgrades[i] )
                local newItem = simfactory.createUnit( unitData, nil )						
				widget:setImage( unitData.profile_icon )

		        local tooltip = util.tooltip( self.screen )
		        local section = tooltip:addSection()
		        newItem:getUnitData().onTooltip( section, newItem )
		        widget:setTooltip( tooltip )
			else
				widget:setVisible(false)
			end
		end
	
		-- skill bars
		for i, widget in agentWidget.binder:forEach( "skill" ) do
			if agentDef.skills[i] then 
				widget.binder.costTxt:spoolText(util.toupper(agentDef.skills[i]),15)

				for i, barWidget in widget.binder:forEach( "bar" ) do
					barWidget.binder.meterbarSmall.binder.bar:setColor(BLANK_COLOR.r,BLANK_COLOR.g,BLANK_COLOR.b,BLANK_COLOR.a)					
				end

				widget.binder.bar1.binder.meterbarSmall.binder.bar:setColor(SET_COLOR.r,SET_COLOR.g,SET_COLOR.b,SET_COLOR.a)
				widget:setVisible( true )
			else 
				widget:setVisible(false)
			end
		end
		for i, skillUpgrade in pairs(agentDef.startingSkills) do
	  		for v, skill in ipairs(agentDef.skills) do
		  		for f=1,skillUpgrade-1 do
					if skill == i then
			     		 agentWidget.binder["skill"..v].binder["bar"..(1+f)].binder.meterbarSmall.binder.bar:setColor(POSSIBLE_COLOR.r,POSSIBLE_COLOR.g,POSSIBLE_COLOR.b,POSSIBLE_COLOR.a)
					end
				end
	  		end		
		end

		-- Specialties

		agentWidget.binder.agentDescBody:setText( agentDef.blurb )

		for i, widget in agentWidget.binder:forEach( "iconSkill" ) do
			widget:setVisible(false)
			agentWidget.binder["skillTxt"..i]:setVisible(false)
		end

	else
		agentWidget.binder.agentName:setText( STRINGS.UI.TEAM_SELECT.LOCKED_AGENT_NAME )
		agentWidget.binder.fluffTxt:setText( STRINGS.UI.TEAM_SELECT.UNLOCK_TO_USE )
		agentWidget.binder.agentDescBody:setText( STRINGS.UI.TEAM_SELECT.LOCKED_AGENT_DESC )
		if agentDef.team_select_img then
			agentWidget.binder.agentImg:setImage(agentDef.team_select_img[1])		
			agentWidget.binder.agentImg:setColor(0,0,0)
			agentWidget.binder.agentImg:createTransition("activate_left")
			agentWidget.binder.agentImgBG:createTransition("activate_left")
		end

		for i, widget in agentWidget.binder:forEach( "item" ) do
			widget:setVisible( false )
		end
		for i, widget in agentWidget.binder:forEach( "skill" ) do
			if agentDef.skills[i] then 
				widget.binder.costTxt:spoolText(util.toupper(agentDef.skills[i]),15)

				for i, barWidget in widget.binder:forEach( "bar" ) do
					barWidget.binder.meterbarSmall.binder.bar:setColor(BLANK_COLOR.r,BLANK_COLOR.g,BLANK_COLOR.b,BLANK_COLOR.a)					
				end
				widget:setVisible( true )
			else 
				widget:setVisible(false)
			end
		end
		for i, widget in agentWidget.binder:forEach( "iconSkill" ) do
			widget:setVisible( false )
		end
	end
end

----------------------------------------------------------------
--

local function onClickNextAgent( self, direction, agentIdx )

	local selectionIdx = self._selectedAgents[agentIdx] + direction 
	if selectionIdx <= 0 then
		selectionIdx = #serverdefs.SELECTABLE_AGENTS
	elseif selectionIdx > #serverdefs.SELECTABLE_AGENTS then
		selectionIdx = 1
	end

	self._selectedAgents[agentIdx] = selectionIdx

	if self._selectedAgents[1] == self._selectedAgents[2] then
		--skip this one and keep going
		onClickNextAgent( self, direction, agentIdx )
	else		
		selectAgent( self, agentIdx, serverdefs.SELECTABLE_AGENTS[selectionIdx] )
	end
end

local function onClickNextProgram( self, direction, programIdx )

	local selectionIdx = self._selectedPrograms[programIdx] + direction 
	if selectionIdx <= 0 then
		selectionIdx = #serverdefs.SELECTABLE_PROGRAMS
	elseif selectionIdx > #serverdefs.SELECTABLE_PROGRAMS then
		selectionIdx = 1
	end

	self._selectedPrograms[programIdx] = selectionIdx

	if self._selectedPrograms[1] == self._selectedPrograms[2] then
		--skip this one and keep going
		onClickNextProgram( self, direction, programIdx )
	else		
		selectProgram( self, programIdx, serverdefs.SELECTABLE_PROGRAMS[selectionIdx] )
	end
end

local function onClickNormalDifficulty( self )
	self._selectedDifficulty = simdefs.NORMAL_DIFFICULTY

	self._panel.binder.normalBtn:setTextColorInactive( unpack(ACTIVE_TXT) )
	self._panel.binder.normalBtn:setColorInactive( unpack(ACTIVE_BG) )
	self._panel.binder.expertBtn:setTextColorInactive( unpack(INACTIVE_TXT) )
	self._panel.binder.expertBtn:setColorInactive( unpack(INACTIVE_BG) )
	self._panel.binder.expertBtn:updateImageState()
	self._panel.binder.normalBtn:updateImageState()
end 

local function onClickExpertDifficulty( self )
	self._selectedDifficulty = simdefs.HARD_DIFFICULTY

	self._panel.binder.expertBtn:setTextColorInactive( unpack(ACTIVE_TXT) )
	self._panel.binder.expertBtn:setColorInactive( unpack(ACTIVE_BG) )
	self._panel.binder.normalBtn:setTextColorInactive( unpack(INACTIVE_TXT) )
	self._panel.binder.normalBtn:setColorInactive( unpack(INACTIVE_BG) )
	self._panel.binder.expertBtn:updateImageState()
	self._panel.binder.normalBtn:updateImageState()
end

teamPreview.onLoad = function ( self, endlessMode )
	
	self.screen = mui.createScreen( "team_preview_screen.lua" )
	mui.activateScreen( self.screen )

	self._endlessMode = endlessMode

	self._scroll_text = scroll_text.panel( self.screen.binder.bg )

	self._panel = self.screen.binder.pnl

	self._panel.binder.acceptBtn.onClick = util.makeDelegate( nil,  onClickCampaign, self)
	self._panel.binder.cancelBtn.onClick = util.makeDelegate( nil,  onClickCancel, self)

	--
	self._panel.binder.agent1.binder.arrowLeft.binder.btn.onClick = util.makeDelegate( nil,  onClickNextAgent, self, -1, 1 )
	self._panel.binder.agent1.binder.arrowRight.binder.btn.onClick = util.makeDelegate( nil,  onClickNextAgent, self, 1, 1 )
	self._panel.binder.agent2.binder.arrowLeft.binder.btn.onClick = util.makeDelegate( nil,  onClickNextAgent, self, -1, 2 )
	self._panel.binder.agent2.binder.arrowRight.binder.btn.onClick = util.makeDelegate( nil,  onClickNextAgent, self, 1, 2 )

	self._panel.binder.program1.binder.arrowLeft.binder.btn.onClick = util.makeDelegate( nil,  onClickNextProgram, self, -1, 1 )
	self._panel.binder.program1.binder.arrowRight.binder.btn.onClick = util.makeDelegate( nil,  onClickNextProgram, self, 1, 1 )
	self._panel.binder.program2.binder.arrowLeft.binder.btn.onClick = util.makeDelegate( nil,  onClickNextProgram, self, -1, 2 )
	self._panel.binder.program2.binder.arrowRight.binder.btn.onClick = util.makeDelegate( nil,  onClickNextProgram, self, 1, 2 )

	self._panel.binder.normalBtn.onClick = util.makeDelegate( nil, onClickNormalDifficulty, self )
	self._panel.binder.expertBtn.onClick = util.makeDelegate( nil, onClickExpertDifficulty, self )

	self._panel.binder.normalBtn:setText( STRINGS.UI.NORMAL_DIFFICULTY )
	self._panel.binder.expertBtn:setText( STRINGS.UI.HARD_DIFFICULTY )
	self._panel.binder.normalBtn:setTooltip( STRINGS.UI.NORMAL_DIFFICULTY_TOOLTIP )
	self._panel.binder.expertBtn:setTooltip( STRINGS.UI.HARD_DIFFICULTY_TOOLTIP )

	--self:populateTeams()
	local user = savefiles.getCurrentGame()
	self._selectedAgents = { 1, 2 }
	self._selectedPrograms = { 1, 2 }
	self._selectedDifficulty = user.data.lastDifficulty or simdefs.NORMAL_DIFFICULTY

	if self._selectedDifficulty == simdefs.NORMAL_DIFFICULTY then 
		onClickNormalDifficulty( self )
	else 
		onClickExpertDifficulty( self )
	end

	self._panel.binder.agent1:setVisible(false)
	self._panel.binder.agent2:setVisible(false)
	self._panel.binder.program1:setVisible(false)
	self._panel.binder.program2:setVisible(false)

	selectAgent( self, 1, serverdefs.SELECTABLE_AGENTS[1], true )
	selectAgent( self, 2, serverdefs.SELECTABLE_AGENTS[2], true )
	selectProgram( self, 1, serverdefs.SELECTABLE_PROGRAMS[1] )
	selectProgram( self, 2, serverdefs.SELECTABLE_PROGRAMS[2] )

	if not MOAIFmodDesigner.isPlaying("theme") then
		MOAIFmodDesigner.playSound("SpySociety/Music/music_title","theme")
	end
	
end

teamPreview.onUnload = function ( self )

	self._scroll_text:destroy()

	mui.deactivateScreen( self.screen )
end

return teamPreview
