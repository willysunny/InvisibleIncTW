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
local agentdefs = include("sim/unitdefs/agentdefs")
local unitdefs = include( "sim/unitdefs" )
local skilldefs = include( "sim/skilldefs" )
local modalDialog = include( "states/state-modal-dialog" )
local scroll_text = include("hud/scroll_text")
local unitdefs = include("sim/unitdefs")
local simfactory = include( "sim/simfactory" )
local guiex = include( "client/guiex" )
local cdefs = include( "client_defs" )

local SET_COLOR = {r=244/255,g=255/255,b=120/255, a=1}
local POSSIBLE_COLOR = {r=56/255,g=96/255,b=96/255, a=1}
local BLANK_COLOR = {r=12/255,g=17/255,b=16/255, a=1}
local HOVER_COLOR = {r=255/255,g=255/255,b=255/255, a=1}
local HOVER_COLOR_FAIL = {r=178/255,g=0/255,b=0/255, a=1}
local TEST_COLOR = {r=0/255,g=184/255,b=0/255, a=1}

local ACTIVE_TXT = { 61/255,81/255,83/255,1 }
local INACTIVE_TXT = { 1,1,1,1 }

local ACTIVE_BG = { 140/255, 255/255, 255/255,1 }
local INACTIVE_BG = { 78/255, 136/255, 136/255,0 }
local SELECTED_BG = { 140/255, 255/255, 255/255,1 }

----------------------------------------------------------------
-- Adapter to check skills for an agentDef

local skillOwner = class()

function skillOwner:init( agentDef )
    self.agentDef = agentDef
end

function skillOwner:hasSkill( skillID, level )
    return array.findIf( self.agentDef.skills, function( s ) return s.skillID == skillID and s.level >= level end )
end

----------------------------------------------------------------
local upgradeScreen = {}

local function onEnterSpool( widget )
	widget:spoolText( widget:getText() )
end

local function getMaxInv(self,unitDef,index)
	return unitDef.skills[3].level + 2 + self._changes[index][3]
end

local function applyAndSave( self )
	local user = savefiles.getCurrentGame()
	local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]

	--permanently upgrade
	for k,v in pairs(self._agency.unitDefs) do
		local unitDef = self._agency.unitDefs[k]
		local skills = unitDef.skills

		for i, skillWidget in self.screen.binder.skillGroup.binder:forEach( "skill" ) do 
			if i <= #skills then
				local skill = skills[i]
				skill.level = skill.level + self._changes[k][i]
			end
		end
	end

	user:save()
end

local function onClickInv(self, unitDef, upgrade, index, itemIndex, stash )

	if stash then
		if self._agency.upgrades and #self._agency.upgrades >= 8 then
			MOAIFmodDesigner.playSound("SpySociety/HUD/gameplay/upgrade_cancel_unit")
			modalDialog.show( "not enough space!" )			
		else
			if not self._agency.upgrades then
				self._agency.upgrades ={}
			end
			table.insert(self._agency.upgrades,upgrade)
			table.remove(unitDef.upgrades,itemIndex)			
		end
	else

		if #unitDef.upgrades >= getMaxInv(self,unitDef,index) then
			MOAIFmodDesigner.playSound("SpySociety/HUD/gameplay/upgrade_cancel_unit")
			modalDialog.show( "not enough space!" )			
		else			
			table.insert(unitDef.upgrades,upgrade)
			table.remove(self._agency.upgrades,itemIndex)	
		end		
	end
	self:refreshInventory(unitDef,index)

end

local function onClickMap(self)
	local stateMapScreen = include( "states/state-map-screen" )
	statemgr.deactivate( upgradeScreen )

	local user = savefiles.getCurrentGame()
	local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]

	statemgr.activate( stateMapScreen, campaign )
end

local function onClickMenu( self )
	local result = modalDialog.showYesNo( "Do you wish to save and exit the current game?", "Save and Exit Game", nil, STRINGS.UI.SAVE_AND_EXIT )
	if result == modalDialog.OK then
		local stateLoading = include( "states/state-loading" )
		statemgr.deactivate( upgradeScreen )
		stateLoading:loadFrontEnd()
	end	
end

local function onClickLearnSkill( self, unitDef, skill, skillLevel, skillindex, k )

	if self._agency.cash >= skillLevel.cost then 
		self._changes[k][skillindex] = self._changes[k][skillindex] + 1
		self._agency.cash = self._agency.cash - skillLevel.cost
		MOAIFmodDesigner.playSound("SpySociety/HUD/gameplay/upgrade_select_unit")
	else
		MOAIFmodDesigner.playSound("SpySociety/HUD/gameplay/upgrade_cancel_unit")
		modalDialog.show( "Insufficient funds!" )
	end
	
    
    local cashAvailable = string.format(STRINGS.UI.UPGRADE_SCREEN_AVAILABLE_CREDITS, self._agency.cash)
	self.screen:findWidget("agencyCredits"):setText( cashAvailable )

	self:refreshSkills( unitDef, k )
	self:refreshInventory(unitDef,k)

end

local function onRollOver(self,skill,skillDef,index,k)
	
	self.screen:findWidget("skillIcon"):setVisible(true)
	self.screen:findWidget("skillIcon"):setImage(skillDef.icon_large)

	self.screen:findWidget("skillTitle"):setVisible(true)
	self.screen:findWidget("skillTitle"):setText(util.toupper(skillDef.name))

	self.screen:findWidget("skillTxt"):setVisible(true)
	self.screen:findWidget("skillTxt"):setText(skillDef.description)		

	--self.screen.binder.tipTitle:setText(util.toupper(skillDef.name).." UPGRADES")
	
	self:displaySkill(skillDef, skill.level)

	local level = skill.level + self._changes[k][index] + 1

	if skill.level +  self._changes[k][index] < skillDef.levels then
	
		if self._agency.cash >= skillDef[level].cost then 				
			self.screen:findWidget("skill"..index..".bar"..level..".bar"):setColor(HOVER_COLOR.r,HOVER_COLOR.g,HOVER_COLOR.b,HOVER_COLOR.a)			
		else
			self.screen:findWidget("skill"..index..".bar"..level..".bar"):setColor(HOVER_COLOR_FAIL.r,HOVER_COLOR_FAIL.g,HOVER_COLOR_FAIL.b,HOVER_COLOR_FAIL.a)			
		end	
	
	end
	
end

local function onRollOut(self,skill,skillDef,index,k)

	local level = skill.level + self._changes[k][index] + 1
	
	if skill.level + self._changes[k][index] < skillDef.levels then
		self.screen:findWidget("skill"..index..".bar"..level..".bar"):setColor(POSSIBLE_COLOR.r,POSSIBLE_COLOR.g,POSSIBLE_COLOR.b,POSSIBLE_COLOR.a)
	end

	self:clearCurrentlyDisplayedSkill()
	
end

----------------------------------------------------
local tooltip = class()

function tooltip:init( panel,skill,skillDef,index, k )
	self._panel = panel
 	self._skill = skill
 	self._skillDef = skillDef
 	self._index = index
 	self._k = k 
end

function tooltip:activate( screen )
	onRollOver(self._panel, self._skill, self._skillDef, self._index, self._k)
end

function tooltip:deactivate( screen )
	onRollOut(self._panel, self._skill, self._skillDef, self._index, self._k)
end

function tooltip:setPosition( )
end



----------------------------------------------------------------
--

upgradeScreen.clearCurrentlyDisplayedSkill = function(self)
	self.screen.binder.tipTitle:setText(STRINGS.UI.UPGRADE_SCREEN_SELECT_UPGRADE)
	self.screen:findWidget("skillIcon"):setVisible(false)
	self.screen:findWidget("skillTitle"):setVisible(false)
	self.screen:findWidget("skillTxt"):setVisible(false)


	for i, bar in self.screen.binder:forEach( "metterBar" ) do 
		bar.binder.bar:setColor(POSSIBLE_COLOR.r,POSSIBLE_COLOR.g,POSSIBLE_COLOR.b,POSSIBLE_COLOR.a)
		bar.binder.cost:setVisible(false)
		bar.binder.level:setVisible(false)
		bar.binder.txt:setVisible(false)				
	end
end

upgradeScreen.displaySkill = function(self, skillDef, level)

	self.screen.binder.tipTitle:setText( string.format(STRINGS.UI.UPGRADE_SCREEN_UPGRADE_TITLE, util.toupper(skillDef.name)) )

	for i, bar in self.screen.binder:forEach( "metterBar" ) do 
		if i <= level then
			bar.binder.bar:setColor(SET_COLOR.r,SET_COLOR.g,SET_COLOR.b,SET_COLOR.a)
		elseif i <= skillDef.levels then
			bar.binder.bar:setColor(POSSIBLE_COLOR.r,POSSIBLE_COLOR.g,POSSIBLE_COLOR.b,POSSIBLE_COLOR.a)
		else
			bar.binder.bar:setColor(BLANK_COLOR.r,BLANK_COLOR.g,BLANK_COLOR.b,BLANK_COLOR.a)
		end

		if i <= skillDef.levels then
			bar.binder.cost:setVisible(true)
			bar.binder.level:setVisible(true)
			bar.binder.txt:setVisible(true)

			bar.binder.cost:setText("$ "..skillDef[i].cost.." ")
			bar.binder.level:setText("LEVEL "..i)
			bar.binder.txt:setText(skillDef[i].tooltip)	

			if i <= level then
				bar.binder.cost:setColor(0,0,0,1)
			else
				bar.binder.cost:setColor(140/255,1,1,1)
			end
		else
			bar.binder.cost:setVisible(false)
			bar.binder.level:setVisible(false)
			bar.binder.txt:setVisible(false)				
		end		
	end
end

upgradeScreen.refreshSkills = function( self, unitDef, k )

	local skills = unitDef.skills

	for i, skillWidget in self.screen.binder.skillGroup.binder:forEach( "skill" ) do 
		if i <= #skills then
			skillWidget:setVisible(true)
			local skill = skills[i]
			local skillDef = skilldefs.lookupSkill( skill.skillID )

			skillWidget.binder.icon:setImage(skillDef.icon)
			skillWidget.binder.skillTitle:setText(util.toupper(skillDef.name))
			skillWidget.binder.icon:setColor(SET_COLOR.r,SET_COLOR.g,SET_COLOR.b,SET_COLOR.a)
			if skill.level + self._changes[k][i] < skillDef.levels then 			
				local currentLevel = skillDef[ skill.level+ self._changes[k][i] +1 ]
				skillWidget.binder.costTxt:setText("$"..currentLevel.cost.." ")
				skillWidget.binder.btn:setDisabled(false) 
				skillWidget.binder.btn.onClick = util.makeDelegate( nil, onClickLearnSkill, self, unitDef, skill, skillDef[skill.level + self._changes[k][i] +1],i,k )	
			else 
				skillWidget.binder.costTxt:setText("MAX")
				skillWidget.binder.btn:setDisabled(true) 
			end

			for j,bar in skillWidget.binder:forEach( "bar" ) do
				if j <=  skill.level then
					bar.binder.bar:setColor(SET_COLOR.r,SET_COLOR.g,SET_COLOR.b,SET_COLOR.a)
				elseif j <= skill.level + self._changes[k][i] then
					bar.binder.bar:setColor(TEST_COLOR.r,TEST_COLOR.g,TEST_COLOR.b,TEST_COLOR.a)
				elseif j <= skillDef.levels then
					bar.binder.bar:setColor(POSSIBLE_COLOR.r,POSSIBLE_COLOR.g,POSSIBLE_COLOR.b,POSSIBLE_COLOR.a)
				else
					bar.binder.bar:setColor(BLANK_COLOR.r,BLANK_COLOR.g,BLANK_COLOR.b,BLANK_COLOR.a)
				end
			end
			skillWidget.binder.btn:setColor(1,0,0,1)
		
			local toolTip = tooltip(self,skill,skillDef,i, k)
			skillWidget.binder.btn:setTooltip(toolTip) 

		else
			skillWidget:setVisible(false)
			if not self._firstTime then
				for i, widget in self.screen.binder.skillGroup.binder:forEach("num") do 
					local x0, y0 = widget:getPosition()
					widget:setPosition(x0, y0+40)
				end
			end
		end
	end

	self._firstTime = true
end



upgradeScreen.refreshInventory = function( self, unitDef, index )
	local invLimit = getMaxInv(self,unitDef,index)

	for i, widget in self.screen.binder:forEach( "inv_" ) do
		if unitDef.upgrades[i] then
			local itemDef, upgradeParams
            if type(unitDef.upgrades[i]) == "string" then
                itemDef = unitdefs.lookupTemplate( unitDef.upgrades[i] )
            else
                upgradeParams = unitDef.upgrades[i].upgradeParams
                itemDef = unitdefs.lookupTemplate( unitDef.upgrades[i].upgradeName )
            end
			local itemUnit = simfactory.createUnit( util.extend( itemDef )( upgradeParams and util.tcopy( upgradeParams )), nil )

            guiex.updateButtonFromItem( self.screen, widget, itemUnit, nil, skillOwner( unitDef ) )
			widget.binder.btn.onClick = util.makeDelegate( nil, onClickInv, self, unitDef, unitDef.upgrades[i], index, i, true )
		else
			if i > invLimit then
				widget:setVisible(false)
			else
                guiex.updateButtonEmptySlot( widget )
			end
		end
	end	

	for i, widget in self.screen.binder:forEach( "agency_inv_" ) do
		if self._agency.upgrades and  self._agency.upgrades[i] then
			local itemDef, upgradeParams
            if type(self._agency.upgrades[i]) == "string" then
                itemDef = unitdefs.lookupTemplate( self._agency.upgrades[i] )
            else
                upgradeParams = self._agency.upgrades[i].upgradeParams
                itemDef = unitdefs.lookupTemplate( self._agency.upgrades[i].upgradeName )
            end
			local itemUnit = simfactory.createUnit( util.extend( itemDef )( upgradeParams and util.tcopy( upgradeParams )), nil )

            guiex.updateButtonFromItem( self.screen, widget, itemUnit, nil, skillOwner( unitDef ) )
			widget.binder.btn.onClick = util.makeDelegate( nil, onClickInv, self, unitDef, self._agency.upgrades[i], index, i, false)			

		else
            guiex.updateButtonEmptySlot( widget )
		end
	end	
end

upgradeScreen.selectAgent = function( self, unitDef, index )
    if self._selectedIndex == index then
        return
    end

    self._selectedIndex = index
	local data = agentdefs[unitDef.template]
	self.screen:findWidget("agentTitle"):setText(util.toupper(data.name))
	self.screen:findWidget("splashImage"):setImage(data.splash_image)
	self.screen:findWidget("splashImage"):createTransition("activate_left")

	self.screen:findWidget("agentDescBody"):setText( data.blurb )

	local fluff = "REAL NAME: ".. data.fullname .." / SERVICE: ".. data.yearsOfService .." YEARS / STATUS: ACTIVE"
	self.screen:findWidget("fluffTxt"):spoolText( util.toupper(fluff) )

	self:clearCurrentlyDisplayedSkill()
	self:refreshSkills( unitDef, index )

	self.refreshInventory(self,unitDef,index)

	for i=1,4,1 do
		local btn = self.screen:findWidget("agent"..i..".btn")
		if i == index then
			--btn:setTextColorInactive( unpack(ACTIVE_TXT) )
			btn:setColorInactive( unpack(SELECTED_BG) )
		else
			--btn:setTextColorInactive( unpack(INACTIVE_TXT) )
			btn:setColorInactive( unpack(INACTIVE_BG) )
		end
		btn:updateImageState()		
	end	

end
upgradeScreen.populateScreen = function( self )
	--loop over all members of the agency
	for i,v in pairs(self._agency.unitDefs) do
		local data = agentdefs[self._agency.unitDefs[i].template]
		local btn = self.screen:findWidget("agent"..i..".btn")

		local img = self.screen:findWidget("agentImg"..i)
		img:setImage(data.profile_icon_64x64)
		img:setColor(1,1,1,1)
		img:setVisible(true)

		btn:setVisible(true)
		btn.onClick = util.makeDelegate( nil, upgradeScreen.selectAgent, self, self._agency.unitDefs[i], i )
		self._changes[i] = {0, 0, 0, 0}
	end

	self._cashUpdateThread = guiex.createCountUpThread( self.screen:findWidget("agencyCredits"), 0, self._agency.cash, 1)

	self:selectAgent(self._agency.unitDefs[1], 1 )
end

upgradeScreen.onLoad = function ( self, agency )
	self.screen = mui.createScreen( "upgrade_screen.lua" )
	mui.activateScreen( self.screen )
	
	self._scroll_text = scroll_text.panel( self.screen.binder.bg )

	MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/largeconnection" )
	MOAIFmodDesigner.playSound("SpySociety/Music/music_title","theme")

	self.screen:findWidget("acceptBtn.btn").onClick = util.makeDelegate( nil, onClickMap, self)
	self.screen:findWidget("acceptBtn.btn"):setText(STRINGS.UI.MAP)
	self.screen:findWidget("acceptBtn.btn"):setTextColorActive(unpack(ACTIVE_TXT))
	self.screen:findWidget("acceptBtn.btn"):setTextColorInactive(unpack(INACTIVE_TXT))

	self.screen:findWidget("menuBtn.btn").onClick = util.makeDelegate( nil, onClickMenu, self)
	self.screen:findWidget("menuBtn.btn"):setText(STRINGS.UI.EXIT)
	self.screen:findWidget("menuBtn.btn"):setTextColorActive(unpack(ACTIVE_TXT))
	self.screen:findWidget("menuBtn.btn"):setTextColorInactive(unpack(INACTIVE_TXT))

	for i=1,4,1 do
		self.screen:findWidget("agent"..i..".btn"):setTextColorInactive(unpack(INACTIVE_TXT))
		self.screen:findWidget("agent"..i..".btn"):setTextColorActive(unpack(ACTIVE_TXT))
		self.screen:findWidget("agent"..i..".btn"):setVisible(false)
		self.screen:findWidget("agentImg"..i):setImage("gui/menu pages/upgrade_screen/border_64x64.png")
		self.screen:findWidget("agentImg"..i):setColor(144/255,1,1,.5)
	end

	self._selectedIndex = nil
	self._agency = agency
	self._changes = {}

	self:populateScreen()
end

upgradeScreen.onUnload = function ( self )
    applyAndSave( self )
    if self._cashUpdateThread then
        self._cashUpdateThread:stop()
        self._cashUpdateThread = nil
    end
	self._scroll_text:destroy()
	mui.deactivateScreen( self.screen )
end

return upgradeScreen
