----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local game = include( "modules/game" )
local util = include("client_util")
local mui = include( "mui/mui" )
local mui_defs = include( "mui/mui_defs" )
local mathutil = include( "modules/mathutil" )
local serverdefs = include( "modules/serverdefs" )
local agentdefs = include("sim/unitdefs/agentdefs")
local skilldefs = include( "sim/skilldefs" )
local simdefs = include( "sim/simdefs" )
local simactions = include( "sim/simactions" )
local modalDialog = include( "states/state-modal-dialog" )
local rig_util = include( "gameplay/rig_util" )
local cdefs = include("client_defs")
local scroll_text = include("hud/scroll_text")
local guiex = include( "client/guiex" )

local ACTIVE_TXT = { 61/255,81/255,83/255,1 }
local INACTIVE_TXT = { 1,1,1,1 }

----------------------------------------------------------------
local mapScreen = {}

-- Translates coordinates in serverdefs to widget coordinates.
local function getMapLocation( mapWidget, location, offx, offy )
	local W, H = mapWidget:getScreen():getResolution()
	local wx, wy = mapWidget:getSize()
	local x, y = serverdefs.MAP_LOCATIONS[ location ].x, serverdefs.MAP_LOCATIONS[ location ].y
	x, y = x - 86, y + 16 -- Because these were the magic offsets of the widget when the Map locations were created.

	-- Ensure that with the offset the location is visible on screen.
	if x + offx < -wx/6 then
		x = x + wx/3
	elseif x + offx > wx/6 then
		x = x - wx/3
	end
	return x, y
end

local function onClickMenu( self )
	local result = modalDialog.showYesNo( "Do you wish to save and exit the current game?", "Save and Exit Game", nil, STRINGS.UI.SAVE_AND_EXIT )
	if result == modalDialog.OK then
		local stateLoading = include( "states/state-loading" )
		statemgr.deactivate( mapScreen )
		stateLoading:loadFrontEnd()
	end	
end

local function onClickUpgrade( self )
	local stateLoading = include( "states/state-loading" )
	statemgr.deactivate( mapScreen )
	stateLoading:loadUpgradeScreen( self._campaign.agency )
end

local function onClickSelectLocation( self, index )

	if self._campaign.situations[index].finalMission then
		local result = modalDialog.showDisclaimer(STRINGS.UI.TEMP_FINAL_MISSION_DESC, STRINGS.UI.TEMP_FINAL_MISSION_TITLE, STRINGS.UI.NEW_GAME_CONFIRM )
		if result == modalDialog.OK then

			MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/largeconnection" )

			-- Officially choose the situation in the campaign data.
			self._campaign.situation = table.remove( self._campaign.situations, index )

			local stateCorpPreview = include( "states/state-corp-preview" )
			statemgr.deactivate( mapScreen )
			statemgr.activate( stateCorpPreview, self._campaign )

		end	
	else
		MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/largeconnection" )

		-- Officially choose the situation in the campaign data.
		self._campaign.situation = table.remove( self._campaign.situations, index )

		local stateCorpPreview = include( "states/state-corp-preview" )
		statemgr.deactivate( mapScreen )
		statemgr.activate( stateCorpPreview, self._campaign )
	end
end

local function onClickLocation( self, index, widget, corpData )

	MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/popup" )

	self._screen.binder.pnl.binder.map:reorderWidget( widget )

	if self._selected then
		local selected = self._selected

	--	selected.binder[selected._dir]:createTransition( "deactivate_below" )
		selected.binder[selected._dir]:createTransition( "deactivate_below",
						function( transition )
							selected.binder[selected._dir]:setVisible( false )
						end,
					 { easeOut = true } )

		--selected.binder[selected._dir]:setVisible(false)
		--selected.binder.circle:setVisible(false)
		--selected.binder.circleShadow:setVisible(false)	
		selected.binder.labelTxt:setVisible(false)
		selected.binder.txtShadow:setVisible(false)
		selected.binder.circle:setColor(1,0,0,1)
	end
	if self._selected == widget then
		self._selected = nil
	else
		self._selected = widget
		widget.binder[widget._dir]:createTransition( "activate_below" )
		widget.binder[widget._dir]:setVisible(true)

        if config.DEV then
            print( "CORP: ", corpData.shortname )
        end

		if corpData and corpData.data and corpData.data.insetTxt then
			self:setCentralText(corpData.data.insetTxt)
			self._stopIntroSubtitle = true
		end
	end

end

----------------------------------------------------
local tooltip = class()

function tooltip:init( panel,widget,situation )
	self._panel = panel
	self._widget = widget
	self._situation = situation
end

function tooltip:activate( screen )	
	self._widget.binder.labelTxt:setVisible(true)
	self._widget.binder.txtShadow:setVisible(true)
	self._widget.binder.circle:setColor(1,1,1,1)
		
	local buttonRoutine = MOAICoroutine.new()		
	buttonRoutine:run( function()
		rig_util.waitForAnim(self._widget.binder.anim:getProp(),"over")
		self._widget.binder.anim:getProp():setPlayMode( KLEIAnim.LOOP )
		self._widget.binder.anim:setAnim("idle")			
		end )
	buttonRoutine:resume()	
end

function tooltip:deactivate( screen )
	local situationData = serverdefs.SITUATIONS[self._situation.name]
	if self._situation.decay ~= nil then
		self._widget.binder.anim:setAnim("distress_idle")
	else
		self._widget.binder.anim:setAnim("idle")
	end

	if self._widget._pnl._selected ~= self._widget then
		self._widget.binder.labelTxt:setVisible(false)
		self._widget.binder.txtShadow:setVisible(false)
		self._widget.binder.circle:setColor(1,0,0,1)	
	end
end

function tooltip:setPosition( )
end

----------------------------------------------------------------

local function centreMap( mapWidget, campaign )	
	local cx, cy = getMapLocation( mapWidget, campaign.location, 0, 0 )
	local wx, wy = mapWidget:getSize()

	-- Centre the map at the current campaign location
	mapWidget:setPosition( -cx )
	-- OFfset scissor accordingly.
	mapWidget:setScissor( -(1/6) + cx/wx, -0.5, (1/6) + cx/wx, 0.5 )

	return -cx, 0
end

local function addTeam(self, location)
	local pnl = self._screen.binder.pnl
	local widget = self._screen:createFromSkin( "location", { xpx = true, ypx = true } )
	self._screen.binder.pnl.binder.map:addChild( widget )
	local x,y = getMapLocation( self._screen.binder.map, location, self.locationOffsetX, self.locationOffsetY )
	local w,h = self._screen:getResolution()
	
	widget:setPosition(x,y)

	widget.binder.right:setVisible(false)
	widget.binder.circle:setVisible(false)
	widget.binder.circleShadow:setVisible(false)
	widget.binder.labelTxt:setVisible(false)
	widget.binder.txtShadow:setVisible(false)
	widget.binder.daysRemaining:setVisible(false)
	widget.binder.right:setVisible(false)

	widget.binder.range.binder.range1:setColor(1,1,1,50/255)
	widget.binder.range.binder.range2:setColor(1,1,1,50/255)
	widget.binder.range.binder.range3:setColor(1,1,1,50/255)

	widget.binder.anim:getProp():setPlayMode( KLEIAnim.LOOP )
	widget.binder.anim:setAnim("team")
	self._locationCoords[location] = {x=x,y=y}
end


local function addLocation(self, situation, popin)
	local pnl = self._screen.binder.pnl
	local widget = self._screen:createFromSkin( "location", { xpx = true, ypx = true } )
	self._screen.binder.pnl.binder.map:addChild( widget )

	local x,y = getMapLocation( self._screen.binder.map, situation.mapLocation, self.locationOffsetX, self.locationOffsetY )
	local w,h = self._screen:getResolution()
		
	widget:setPosition(x, y)		



	widget.binder.range:setVisible(false)

	self._locationCoords[situation.mapLocation] = {x=x,y=y}

	local dir  = "right"
	widget._dir = dir
	widget.binder[dir]:setVisible(true)
	widget.binder.circle:setColor(1,0,0,1)

	widget.binder.right:setVisible(false)
	widget.binder.labelTxt:setVisible(false)
	widget.binder.txtShadow:setVisible(false)

	local Xmin = -550
	local Xmax = 560
	local popUpWidth = 300/2

	local x1,y1 = getMapLocation( self._screen.binder.map, self._campaign.location, self.locationOffsetX, self.locationOffsetY )
	local diffx = x-x1

	if diffx < Xmin + popUpWidth then


		local wX,wY = widget.binder.right:getPosition()
		local offset = popUpWidth + Xmin - diffx		

		widget.binder.right:setPosition(wX + offset  ,   wY )
	elseif diffx > Xmax - popUpWidth then

		local wX,wY = widget.binder.right:getPosition()
		local offset = Xmax - diffx - popUpWidth 
	
		widget.binder.right:setPosition(wX + offset, wY )		
	end 


	local corpData = serverdefs.LOCATIONS[ situation.locationName ]

	widget.binder[dir].binder.pnl.binder.icon:setImage(corpData.imgs.logoLarge)
	if self._campaign.gameDifficulty == simdefs.HARD_DIFFICULTY then
		widget.binder[dir].binder.pnl.binder.icon:setVisible( false )
	end

	widget.binder.daysRemaining:setVisible(false)
	if situation.decay ~= nil then						
		widget.binder.daysRemaining.binder.time:setText(string.format( STRINGS.UI.MAP_SCREEN_EXPIRES, situation.decay ) )	
		widget.binder.daysRemaining.binder.timeShadow:setText(string.format( STRINGS.UI.MAP_SCREEN_EXPIRES,situation.decay ) )	
	end

	if situation.finalMission ~= nil then						
		widget.binder.daysRemaining.binder.time:setText( STRINGS.UI.MAP_SCREEN_DISTRESS )	
		widget.binder.daysRemaining.binder.timeShadow:setText( STRINGS.UI.MAP_SCREEN_DISTRESS )	
	end

	widget.binder.labelTxt:spoolText(string.format(  util.toupper(serverdefs.MAP_LOCATIONS[situation.mapLocation].name) ))
	widget.binder.txtShadow:spoolText(string.format( util.toupper(serverdefs.MAP_LOCATIONS[situation.mapLocation].name) ))

	local situationData = serverdefs.SITUATIONS[situation.name]
	local travelTime = serverdefs.calculateTravelTime( self._campaign.location, situation.mapLocation ) + serverdefs.BASE_TRAVEL_TIME 
	local txt = string.format( STRINGS.UI.MAP_SCREEN_TRAVEL_TIME, travelTime )
	widget.binder[dir].binder.pnl.binder.pnl.binder.txt2:setText(txt  )
	if situationData.name == "Escape" then
		if self._campaign.gameDifficulty == simdefs.HARD_DIFFICULTY then
			widget.binder[dir].binder.pnl.binder.pnl.binder.txt:setText(corpData.locationName .. "\nSecurity Level: "..STRINGS.UI.DIFFICULTY[situation.difficulty])
		else
			local posx, posy = widget.binder[dir].binder.pnl.binder.pnl.binder.txt:getPosition()

			local OFFSET_FOR_CORP_ICON = 45
			widget.binder[dir].binder.pnl.binder.pnl.binder.txt:setText(corpData.shortname .. " "..corpData.locationName .. "\nSecurity Level: "..STRINGS.UI.DIFFICULTY[situation.difficulty])
			widget.binder[dir].binder.pnl.binder.pnl.binder.txt:setPosition(posx + OFFSET_FOR_CORP_ICON, posy)
		end
	else
		if situation.decay == 0 then
			widget.binder.labelTxt:setText(string.format(  STRINGS.UI.MAP_SCREEN_EXPIRED ) )	
			widget.binder.txtShadow:setText(string.format( STRINGS.UI.MAP_SCREEN_EXPIRED ) )	

		else
			widget.binder[dir].binder.pnl.binder.pnl.binder.txt:setText( STRINGS.UI.MAP_CODE_NAME .. situationData.strings.MISSION_TITLE.. "\nSecurity Level: "..STRINGS.UI.DIFFICULTY[situation.difficulty])			
		end
	end

	widget.binder[dir].binder.pnl.binder.pnl.binder.star1:setVisible(false)
	widget.binder[dir].binder.pnl.binder.pnl.binder.star2:setVisible(false)
	widget.binder[dir].binder.pnl.binder.pnl.binder.star3:setVisible(false)
	widget.binder[dir].binder.pnl.binder.pnl.binder.star4:setVisible(false)
	--Faster just to do this manually, if we get more difficulty stars we can turn this into a function
	if situation.difficulty > 1 then 
		widget.binder[dir].binder.pnl.binder.pnl.binder.star2:setImage( "gui/menu pages/map_screen/star2.png" )
	end

	if situation.difficulty > 2 then 
		widget.binder[dir].binder.pnl.binder.pnl.binder.star3:setImage( "gui/menu pages/map_screen/star2.png" )
	end

	if situation.difficulty > 3 then 
		widget.binder[dir].binder.pnl.binder.pnl.binder.star4:setImage( "gui/menu pages/map_screen/star2.png" )
	end

	if situation.decay == nil or situation.decay > 0 then
		widget.binder[dir].binder.pnl.binder.pnl.binder.confirmBtn.onClick = util.makeDelegate( nil, onClickSelectLocation, self, situation.index )
		widget.binder[dir].binder.pnl.binder.pnl.binder.confirmBtn:setText(STRINGS.UI.MAP_INFILTRATE)
	end
	--widget.binder[dir].binder.pnl.binder.pnl:setVisible(false)

	local toolTip = tooltip(self,widget,situation)
	widget._pnl = self
	widget.binder.btn:setTooltip(toolTip) 
	widget.binder.btn.onClick = util.makeDelegate( nil, onClickLocation, self, situation.index, widget, corpData)

			

	local cont = true
	local buttonRoutine = MOAICoroutine.new()		
	buttonRoutine:run( function() 		

			while cont == true do
				if popin then
					rig_util.waitForAnim(widget.binder.anim:getProp(),"in")
				end

				widget.binder.anim:getProp():setPlayMode( KLEIAnim.LOOP )

				if situation.finalMission then
					widget.binder.anim:setAnim("distress_idle")
					widget.binder.daysRemaining:setVisible(true)
				elseif situation.decay == nil then
					widget.binder.anim:setAnim("idle")
				else
					widget.binder.anim:setAnim("distress_idle")

					if situation.decay > 0 then
						widget.binder.anim:setAnim("distress_idle")
					elseif situation.decay==0 then
						widget.binder.daysRemaining:setVisible(true)
						rig_util.wait(2*cdefs.SECONDS)
						rig_util.waitForAnim(widget.binder.anim:getProp(),"out")
						widget:setVisible(false)
						break
					end
				end

				cont = false

				coroutine.yield()
			end
		end )
	buttonRoutine:resume()	
		
	return widget
end
-----------------------------------------------------------

mapScreen.populateScreen = function( self )
	local widgets = {}
	local newSit = {}
	local oldSit = {}

	for i,situation in pairs(self._campaign.situations) do
		situation.index = i
		if situation.new == true then
			situation.new = nil
			table.insert(newSit,situation)
		else
			table.insert(oldSit,situation)
		end
	end

	for i,situation in pairs(oldSit) do 
		table.insert(widgets,addLocation(self, situation, false))	
	end
	
	for i,situation in pairs(newSit) do 
		rig_util.wait(0.2*cdefs.SECONDS)
		MOAIFmodDesigner.playSound( "SpySociety/HUD/menu/map_locations" )
		table.insert(widgets,addLocation(self, situation, true))	
	end

	return widgets	
end

mapScreen.addCentralText = function( self, text )
	table.insert( self._centralText, text )
	self._centralTextIdx = #self._centralText

	self:refreshCentralText()
end

mapScreen.setCentralText = function( self, text )
	self._centralText = {text}
	self._centralTextIdx = 1

	self:refreshCentralText()
end

local function prevCentralText( self )
	assert( self._centralTextIdx > 1 )
	self._centralTextIdx = self._centralTextIdx - 1

	self:refreshCentralText()
end

local function nextCentralText( self )
	assert( self._centralTextIdx < #self._centralText )
	self._centralTextIdx = self._centralTextIdx + 1

	self:refreshCentralText()
end

mapScreen.refreshCentralText = function( self )
	self._centralWidget.binder.prevBtn:setVisible(self._centralTextIdx > 1 and #self._centralText > 1)	
	self._centralWidget.binder.nextBtn:setVisible(self._centralTextIdx < #self._centralText and #self._centralText > 1)	
	self._centralWidget.binder.bodyTxt:spoolText(self._centralText[self._centralTextIdx])
end

mapScreen.onLoad = function ( self, campaign )

	self._campaign = campaign
	self._selected = nil
	self._notalking = false
	self._stopIntroSubtitle = false

	self._screen = mui.createScreen( "map_screen.lua" )
	mui.activateScreen( self._screen )
	
	self._scroll_text = scroll_text.panel( self._screen.binder.bg_no_map )

	local pnl = self._screen.binder.pnl

	self._locationCoords = {}

	self.locationOffsetX, self.locationOffsetY = centreMap( self._screen.binder.map, self._campaign )
 	addTeam(self, self._campaign.location)

	self._centralWidget = pnl.binder.Friends
	self:setCentralText("")
	self._centralWidget.binder.prevBtn.onClick = util.makeDelegate( nil, prevCentralText, self)
	self._centralWidget.binder.nextBtn.onClick = util.makeDelegate( nil, nextCentralText, self)
	self:refreshCentralText()

	pnl.binder.Friends:setVisible(false)
	pnl:findWidget("upgradeBtn.btn"):setVisible(false)
	pnl:findWidget("menuBtn.btn"):setVisible(false)

	local currentMin = 0 
	local currentSec = 0 

	if campaign.hours > 0 then
		currentMin = math.random(1,30)
		currentSec = math.random(1,30)
	end

	pnl:findWidget("timer"):setText(string.format(STRINGS.UI.MAP_SCREEN_DAYS_SPENT, math.floor(campaign.hours / 24) + 1, campaign.hours % 24, currentMin, currentSec ))

	self._timeUpdateThread = MOAICoroutine.new()
	self._timeUpdateThread:run( function() 

		local i = 0
		while true do
			i = i + 1
			if i % 60 == 0 then

				currentSec = (currentSec + 1) % 60
				if currentSec == 0 then
					currentMin = (currentMin + 1) % 60
				end

				pnl:findWidget("timer"):setText(string.format(STRINGS.UI.MAP_SCREEN_DAYS_SPENT, math.floor(campaign.hours / 24) + 1, campaign.hours, currentMin, currentSec ))
			end

			coroutine.yield()
		end
	end )


	pnl:findWidget("timeRemaining"):setText(string.format(STRINGS.UI.MAP_SCREEN_REMAINING, math.max(0, serverdefs.FINAL_LEVEL - campaign.hours) ))

	if campaign.endless then
		pnl:findWidget("timeRemaining"):setVisible( false )
		pnl:findWidget("timerGroup"):setPosition( pnl:findWidget("timeRemainingGroup"):getPosition() )
	else
		pnl:findWidget("timeRemaining"):setVisible( true )
	end

	if #campaign.situations == 0 then
		-- Fallback in case all situations were removed
		serverdefs.createCampaignSituations( campaign, 1 )
	end


	MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/smallconnection" )
	if not MOAIFmodDesigner.isPlaying("theme") then
		MOAIFmodDesigner.playSound("SpySociety/Music/music_title","theme")
	end
	
	if campaign.hours == 0 and not self._campaign.endless and not campaign.seenMapIntro then
		campaign.seenMapIntro = true
		modalDialog.showWelcome()
	end

	if campaign.dayPassed or campaign.hours == 0 then 
		local daySwipe = self._screen.binder.daySwipe
		daySwipe:setVisible( true )
		daySwipe.binder.daySwipeTxt:setText( string.format("DAY %d", math.floor(campaign.hours / 24) + 1 ) )
		daySwipe:createTransition( "activate_left" )
		MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/day_popup" )
		rig_util.wait(1.5*cdefs.SECONDS)
		daySwipe:createTransition( "deactivate_right",
			function( transition )
				daySwipe:setVisible( false )
			end,
		 { easeOut = true } )
	end

	--pnl:createTransition( "activate_left", function( transition ) pnl:setVisible( true ) end )

	if campaign.hours > 0 then
		pnl:findWidget("upgradeBtn.btn").onClick = util.makeDelegate( nil, onClickUpgrade, self)
		pnl:findWidget("upgradeBtn.btn"):setText(STRINGS.UI.UPGRADE)
		pnl:findWidget("upgradeBtn.btn"):setTextColorActive(unpack(ACTIVE_TXT))
		pnl:findWidget("upgradeBtn.btn"):setTextColorInactive(unpack(INACTIVE_TXT))
		pnl:findWidget("upgradeBtn.btn"):setVisible(true)
	end

	pnl:findWidget("menuBtn.btn").onClick = util.makeDelegate( nil, onClickMenu, self)
	pnl:findWidget("menuBtn.btn"):setText(STRINGS.UI.EXIT)
	pnl:findWidget("menuBtn.btn"):setTextColorActive(unpack(ACTIVE_TXT))
	pnl:findWidget("menuBtn.btn"):setTextColorInactive(unpack(INACTIVE_TXT))
	pnl:findWidget("menuBtn.btn"):setVisible(true)

	pnl.binder.Friends:setVisible(true)
	pnl.binder.Friends:createTransition( "activate_left" )

	self._updateThread = MOAICoroutine.new()
	self._updateThread:run( function() self:populateScreen() end )

	self._scoreUpdateThread = guiex.createCountUpThread( pnl:findWidget("scoreNum"), 0, campaign.agency.score or 0, 1)
	self._cashUpdateThread = guiex.createCountUpThread( pnl:findWidget("creditsNum"), 0, campaign.agency.cash, 1)

	local txt = self._screen:findWidget("incoming"):getText()

	self._missionBlinkThread = MOAICoroutine.new()
	self._missionBlinkThread:run( function() 
		local i = 0
		while true do
			i = i + 1
			if i % 60 == 0 then
				self._screen:findWidget("incoming"):setText( txt )
			elseif i % 30 == 0 then
				self._screen:findWidget("incoming"):setText( txt.."_" )
				if not self._screen:findWidget("incoming"):isVisible() then
					MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/button_flash" )
				end
			end

			coroutine.yield()
		end
	end )
	self._missionBlinkThread:resume()	

	if campaign.hours == 0 then 

		if campaign.endless then
			-- do one for the voices, and another for the text
			rig_util.wait(0.5*cdefs.SECONDS)
			pnl.binder.Friends.binder.bodyTxt:spoolText("")

			self._missionVoiceThread = MOAICoroutine.new()
			self._missionVoiceThread:run( function() 
				MOAIFmodDesigner.playSound("SpySociety/VoiceOver/Missions/MapScreen/Intro_story_1", "intro1")
				while MOAIFmodDesigner.isPlaying( "intro1" ) do
					coroutine.yield()
				end
				rig_util.wait(0.2*cdefs.SECONDS)

				if not self._notalking then
					MOAIFmodDesigner.playSound("SpySociety/VoiceOver/Missions/MapScreen/Intro_infinite_2", "intro2")
					while MOAIFmodDesigner.isPlaying( "intro2" ) do
						coroutine.yield()
					end
				end
				rig_util.wait(0.5*cdefs.SECONDS)

				if not self._notalking then
					MOAIFmodDesigner.playSound("SpySociety/VoiceOver/Missions/MapScreen/Intro_infinite_3", "intro3")
				end
			end)

			self._missionTextThread = MOAICoroutine.new()
			self._missionTextThread:run( function() 
				self:setCentralText(STRINGS.UI.MAP_DIALOG_INFINITE_INTRO[1])
				rig_util.wait(8.5*cdefs.SECONDS)
				
				if not self._stopIntroSubtitle then
					self:addCentralText(STRINGS.UI.MAP_DIALOG_INFINITE_INTRO[2])
					rig_util.wait(7*cdefs.SECONDS)
				end

				if not self._stopIntroSubtitle then
					self:addCentralText(STRINGS.UI.MAP_DIALOG_INFINITE_INTRO[3])
				end
			end)
		else
			-- do one for the voices, and another for the text
			rig_util.wait(0.5*cdefs.SECONDS)
			pnl.binder.Friends.binder.bodyTxt:spoolText("")

			self._missionVoiceThread = MOAICoroutine.new()
			self._missionVoiceThread:run( function() 
				MOAIFmodDesigner.playSound("SpySociety/VoiceOver/Missions/MapScreen/Intro_story_1", "intro1")
				while MOAIFmodDesigner.isPlaying( "intro1" ) do
					coroutine.yield()
				end
				rig_util.wait(0.2*cdefs.SECONDS)

				if not self._notalking then
					MOAIFmodDesigner.playSound("SpySociety/VoiceOver/Missions/MapScreen/Intro_story_2", "intro2")
					while MOAIFmodDesigner.isPlaying( "intro2" ) do
						coroutine.yield()
					end
				end
				rig_util.wait(0.5*cdefs.SECONDS)

				if not self._notalking then
					MOAIFmodDesigner.playSound("SpySociety/VoiceOver/Missions/MapScreen/Intro_story_3", "intro3")
					while MOAIFmodDesigner.isPlaying( "intro3" ) do
						coroutine.yield()
					end
				end

				rig_util.wait(0.5*cdefs.SECONDS)

				if not self._notalking then
					MOAIFmodDesigner.playSound("SpySociety/VoiceOver/Missions/MapScreen/Intro_story_4", "intro4")
				end
			end)

			self._missionTextThread = MOAICoroutine.new()
			self._missionTextThread:run( function() 
				self:setCentralText(STRINGS.UI.MAP_DIALOG_STORY_INTRO[1])
				rig_util.wait(8.5*cdefs.SECONDS)
				
				if not self._stopIntroSubtitle then
					self:addCentralText(STRINGS.UI.MAP_DIALOG_STORY_INTRO[2])
					rig_util.wait(3*cdefs.SECONDS)
				end

				if not self._stopIntroSubtitle then
					self:addCentralText(STRINGS.UI.MAP_DIALOG_STORY_INTRO[3])
					rig_util.wait(9.5*cdefs.SECONDS)
				end

				if not self._stopIntroSubtitle then
					self:addCentralText(STRINGS.UI.MAP_DIALOG_STORY_INTRO[4])
				end
			end)
		end
	else
		if campaign.raiseDifficulty then 
			self:setCentralText( STRINGS.UI.CENTRAL_MISSION_DIFFICULTY )
		else
			self:setCentralText(STRINGS.UI.MAP_DIALOG_1)
		end
	end

end

mapScreen.onUnload = function ( self )
	self._scroll_text:destroy()
	MOAIFmodDesigner.stopSound("intro1")
	MOAIFmodDesigner.stopSound("intro2")
	MOAIFmodDesigner.stopSound("intro3")
	MOAIFmodDesigner.stopSound("intro4")
	self._notalking = true
	mui.deactivateScreen( self._screen )

	self._timeUpdateThread:stop()
	self._timeUpdateThread = nil

	if self._missionBlinkThread then
		self._missionBlinkThread:stop()
		self._missionBlinkThread = nil
	end

	if self._scoreUpdateThread then
		self._scoreUpdateThread:stop()
		self._scoreUpdateThread = nil
	end

	if self._cashUpdateThread then
		self._cashUpdateThread:stop()
		self._cashUpdateThread = nil
	end

	if self._missionVoiceThread then
		self._missionVoiceThread:stop()
		self._missionVoiceThread = nil
	end

	if self._missionTextThread then
		self._missionTextThread:stop()
		self._missionTextThread = nil
	end
end

return mapScreen

