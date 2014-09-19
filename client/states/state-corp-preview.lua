----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local game = include( "modules/game" )
local version = include( "modules/version" )
local serverdefs = include( "modules/serverdefs" )
local resources = include("resources")
local util = include("client_util")
local rand = include( "modules/rand" )
local array = include("modules/array")
local mathutil = include("modules/mathutil")
local cdefs = include("client_defs")
local mui = include( "mui/mui" )
local serverdefs = include( "modules/serverdefs" )
local metrics = include( "metrics" )
local stateLoading = include( "states/state-loading" )
local modalDialog = include( "states/state-modal-dialog" )
local simparams = include( "sim/simparams" )
local rig_util = include( "gameplay/rig_util" )
local scroll_text = include("hud/scroll_text")


local DESC_SPOOL_SPEED = 18

----------------------------------------------------------------

local corpPreview = {}

local function spaceText(txt)
	local newtxt = ""

	for w in string.gmatch (txt, ".") do
		if w == " " then
  			newtxt = newtxt ..w ..".  "
  		else
  			newtxt = newtxt ..w .." "
  		end
	end

	return newtxt
end

local RANDOM_CHARS = { "1","2","3","4","5","6","7","8","9","0","A","B","C","D","X","M", }

local function randomChar()
	return RANDOM_CHARS[math.floor(math.random() * #RANDOM_CHARS)+1]
end

local RANDOM_BUILDINGS =
{
	"gui/menu pages/corp_select/Building_1_1.png",
	"gui/menu pages/corp_select/Building_1_2.png",
	"gui/menu pages/corp_select/Building_1_3.png",
	"gui/menu pages/corp_select/Building_1_4.png",
	"gui/menu pages/corp_select/Building_1_5.png",
	"gui/menu pages/corp_select/Building_1_6.png",
	"gui/menu pages/corp_select/Building_1_7.png",
}

local function randomBuilding()
	return RANDOM_BUILDINGS[math.floor(math.random()*#RANDOM_BUILDINGS)+1]
end

local function onClickContinue( self )
	local version = include( "modules/version" )
	
	local user = savefiles.getCurrentGame()
	local campaign = corpPreview._campaign
	user.data.saveSlots[ user.data.currentSaveSlot ] = campaign
	user.data.num_games = (user.data.num_games or 0) + 1
	campaign.sim_version = version.VERSION
	user:save()

	metrics.app_metrics:incStat( "new_games" )

	statemgr.deactivate( corpPreview )

	stateLoading:loadCampaign( campaign )
end

----------------------------------------------------------------
--

corpPreview.waitForSound = function ( self, soundname )

	while MOAIFmodDesigner.isPlaying( soundname ) do
		coroutine.yield()
	end

end


local showGeneral = function( self, screen )
	local situation = serverdefs.SITUATIONS[ self._campaign.situation.name ]
	local pnlGroup = screen:findWidget("missionbriefbodygroup.generalPanel")
	local poiGroup = screen:findWidget("missionbriefbodygroup.personOfInterestGroup")
	local descLen = string.len( string.gsub( string.gsub(self._missionText, " ", "" ), "\n", "") )--remove whitespace
	local corpData = serverdefs.LOCATIONS[ self._campaign.situation.locationName ]

	local brief = math.floor(math.random()* #situation.briefing) +1

	pnlGroup:setPosition(poiGroup:getPosition())

	pnlGroup:setVisible(true)
	pnlGroup.binder.poiFadeToBlack:blinkWhiteTransition()
	pnlGroup.binder.interestName:setText("")
	pnlGroup.binder.interestType:setText("")
	screen:findWidget("situationTxt"):setText("")

	pnlGroup.binder.details.binder.fileName:setText("FILE#".. randomChar()..randomChar().."-"..randomChar()..randomChar()..randomChar()..randomChar()..randomChar()..randomChar().."-"..randomChar()..randomChar()..randomChar()..randomChar()..randomChar()..randomChar()..randomChar())

	pnlGroup.binder.additionalInfo1.binder.insetImg:setImage(corpData.data.insetImg)
	pnlGroup.binder.additionalInfo1.binder.insetTitle:setText(corpData.data.insetTitle)
	pnlGroup.binder.additionalInfo1.binder.insetTxt:setText(corpData.data.insetTxt)

	pnlGroup.binder.locationImg:setImage(randomBuilding())
	pnlGroup.binder.corpLogo:setImage(corpData.imgs.logoLarge)

	--jcheng: magic line space number! It's an additional 0.3 linespacing @ 72 DPI
	screen:findWidget("situationTxt"):setLineSpacing( 0.2/72 )

	rig_util.wait(0.75*cdefs.SECONDS)

	
	MOAIFmodDesigner.playSound(situation.briefing[brief].situation, "situation")

	self._missionText = string.gsub( situation.strings[situation.briefing[brief].text], "<Corporation>", corpData.corp )
	self._missionText = string.gsub( self._missionText, "<Location>", corpData.locationName )
	self._missionText = string.gsub( self._missionText, "<Num>", corpData.locationName )
	screen:findWidget("situationTxt"):spoolText(self._missionText, DESC_SPOOL_SPEED)

	--jcheng: do threads expire when it's done running?
	local interestNameThread = MOAICoroutine.new(corpData.data)
	interestNameThread:run( function() 
		local courierName = util.toupper(corpData.locationName)
		local spoolSpeed = 12
		pnlGroup.binder.interestName:spoolText(courierName, spoolSpeed)
		rig_util.wait((string.len(courierName)/spoolSpeed + 0.5)*cdefs.SECONDS)
		pnlGroup.binder.interestType:spoolText(corpData.corp, spoolSpeed)
	end )

	--rig_util.wait((string.len(self._missionText)/DESC_SPOOL_SPEED + 0.5)*cdefs.SECONDS)

	self:waitForSound( "situation" )
	rig_util.wait(0.5*cdefs.SECONDS)

	--select random goal index
	local goalIdx = math.random( 1, #corpData.data.desc )
	local descLen = string.len( string.gsub( string.gsub(self._missionText, " ", "" ), "\n", "") )--remove whitespace
	self._missionText = self._missionText.."\n\n"..corpData.data.desc[goalIdx].text
	screen:findWidget("situationTxt"):spoolText(self._missionText, DESC_SPOOL_SPEED)
	screen:findWidget("situationTxt"):setReveal(descLen)

	MOAIFmodDesigner.playSound(corpData.data.desc[goalIdx].vo, "goal")
	self:waitForSound( "goal" )

	rig_util.wait(0.5*cdefs.SECONDS)

	descLen = string.len( string.gsub( string.gsub(self._missionText, " ", "" ), "\n", "") )--remove whitespace
	self._missionText = self._missionText.."\n\n"..string.gsub( situation.strings[situation.briefing[brief].endertext], "<Corporation>", corpData.corp )
	screen:findWidget("situationTxt"):spoolText(self._missionText, DESC_SPOOL_SPEED)
	screen:findWidget("situationTxt"):setReveal(descLen)

	MOAIFmodDesigner.playSound(situation.briefing[brief].ender, "ender")
	self:waitForSound( "ender" )
end



local showDescription = function( self, screen )
	local situation = serverdefs.SITUATIONS[ self._campaign.situation.name ]

	local poiGroup = screen:findWidget("missionbriefbodygroup.personOfInterestGroup")

	poiGroup:setVisible(true)
	poiGroup.binder.poiFadeToBlack:blinkWhiteTransition()
	poiGroup.binder.interestName:setText("")
	poiGroup.binder.interestType:setText("")
	screen:findWidget("situationTxt"):setText("")

	--bind the person of interest face (and the hacky drop shadow)
	screen:findWidget("poiCharAnim"):bindBuild( situation.profileAnim )
	screen:findWidget("poiCharAnim"):bindAnim( situation.profileAnim )
	screen:findWidget("poiCharAnim 2"):bindBuild( situation.profileAnim )
	screen:findWidget("poiCharAnim 2"):bindAnim( situation.profileAnim )

	--jcheng: magic line space number! It's an additional 0.3 linespacing @ 72 DPI
	screen:findWidget("situationTxt"):setLineSpacing( 0.2/72 )

	rig_util.wait(0.75*cdefs.SECONDS)

	local corpData = serverdefs.LOCATIONS[ self._campaign.situation.locationName ]
	MOAIFmodDesigner.playSound(situation.introVO.."_"..corpData.shortname, "situation")
	self._missionText = string.gsub( situation.strings.MISSION_DESCRIPTION, "<Corporation>", corpData.corp )
	screen:findWidget("situationTxt"):spoolText(self._missionText, DESC_SPOOL_SPEED)

	--jcheng: do threads expire when it's done running?
	local interestNameThread = MOAICoroutine.new()
	interestNameThread:run( function() 
		local courierName = situation.strings.MISSION_PERSON_OF_INTEREST
		local spoolSpeed = 12
		poiGroup.binder.interestName:spoolText(courierName, spoolSpeed)
		rig_util.wait((string.len(courierName)/spoolSpeed + 0.5)*cdefs.SECONDS)
		poiGroup.binder.interestType:spoolText(situation.strings.MISSION_POI_TYPE, spoolSpeed)
	end )

	--rig_util.wait((string.len(self._missionText)/DESC_SPOOL_SPEED + 0.5)*cdefs.SECONDS)

	self:waitForSound( "situation" )
end

local showGoal = function( self, screen )
	local situation = serverdefs.SITUATIONS[ self._campaign.situation.name ]
	local poiGroup = screen:findWidget("missionbriefbodygroup.personOfInterestGroup")
	local descLen = string.len( string.gsub( string.gsub(self._missionText, " ", "" ), "\n", "") )--remove whitespace
	local corpData = serverdefs.LOCATIONS[ self._campaign.situation.locationName ]

	self._missionText = self._missionText.."\n\n"..string.gsub( situation.strings.MISSION_GOAL, "<Corporation>", corpData.corp )
	screen:findWidget("situationTxt"):spoolText(self._missionText, DESC_SPOOL_SPEED)
	screen:findWidget("situationTxt"):setReveal(descLen)

	MOAIFmodDesigner.playSound(situation.goalVO, "goal")
	self:waitForSound( "goal" )

	rig_util.wait(0.5*cdefs.SECONDS)
end

local showEnder = function( self, screen )
	local situation = serverdefs.SITUATIONS[ self._campaign.situation.name ]
	local poiGroup = screen:findWidget("missionbriefbodygroup.personOfInterestGroup")
	local descLen = string.len( string.gsub( string.gsub(self._missionText, " ", "" ), "\n", "") )--remove whitespace
	local corpData = serverdefs.LOCATIONS[ self._campaign.situation.locationName ]

	if situation.enderVO then
		MOAIFmodDesigner.playSound(situation.enderVO, "ender")
		
		self._missionText = self._missionText.."\n\n"..string.gsub( situation.strings.MISSION_ENDER, "<Corporation>", corpData.corp )
		screen:findWidget("situationTxt"):spoolText(self._missionText, DESC_SPOOL_SPEED)
		screen:findWidget("situationTxt"):setReveal(descLen)
	else
		local ender = cdefs.SOUND_VO_GENERIC_ENDERS[ math.random( 1, #cdefs.SOUND_VO_GENERIC_ENDERS ) ]
		MOAIFmodDesigner.playSound(ender, "ender")
	end

	self:waitForSound( "ender" )
end

local showLocation = function( self, screen )
	local poiGroup = screen:findWidget("missionbriefbodygroup.personOfInterestGroup")

	--animate poiGroup to the side and fade it to black
	local poiOriginX, poiOriginY = poiGroup:getPosition()
	local poiFinalX = poiOriginX - 300 --about half a 1280 screen
	local poiFinalY = poiOriginY + 50

	self._movePOIThread = MOAICoroutine.new()
	self._movePOIThread:run( function() 
		MOAIFmodDesigner.playSound( "SpySociety/HUD/menu/popdown" )
		local i = 0
		local t = 0
		local transitionTime = 0.6*cdefs.SECONDS
		while t <= 1 do
			i = i + 1
			t = i / transitionTime
			poiGroup:setPosition( mathutil.outQuad(poiOriginX, poiFinalX,t), mathutil.outQuad(poiOriginY, poiFinalY,t) )
			poiGroup.binder.poiFadeToBlack:setColor(0,0,0,mathutil.outQuad(0,150/255,t))
			coroutine.yield()
		end
	end )


	local locationGroup = screen:findWidget("missionbriefbodygroup.locationGroup")

	locationGroup.binder.locationName:setText("")
	locationGroup.binder.locationAddress:setText("")

	MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/smallconnection" )
	locationGroup:createTransition("activate_left")
	locationGroup:setVisible(true)

	rig_util.wait(0.5*cdefs.SECONDS)
	
	local corpData = serverdefs.LOCATIONS[ self._campaign.situation.locationName ]

	MOAIFmodDesigner.playSound(corpData.locationVO, "location")

	local locationName = util.toupper(corpData.locationName)

	local addressNumber = math.random( 1000, 10000 )
	local addressStreet = corpData.streets[ math.random( 1, #corpData.streets ) ]
	local addressCity = corpData.cities[ math.random( 1, #corpData.cities ) ]
	local locationAddress = string.format("%d %s, %s", addressNumber, addressStreet, addressCity)

	local spoolSpeed = 12
	locationGroup.binder.locationName:spoolText(locationName, spoolSpeed)
	rig_util.wait((string.len(locationName)/spoolSpeed + 0.5)*cdefs.SECONDS)
	locationGroup.binder.locationAddress:spoolText(locationAddress, spoolSpeed)

	rig_util.wait(1.5*cdefs.SECONDS)
	--self:waitForSound( "location" )
end

corpPreview.populateCorp = function( self )

	self._missionText = ""

	MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/smallconnection" )

	local situation = serverdefs.SITUATIONS[ self._campaign.situation.name ]
	self.screen:findWidget("missionHeaderName"):setText( situation.strings.MISSION_TITLE )
	
	local briefbody = self.screen:findWidget("missionbriefbodygroup")
	briefbody.binder.locationGroup:setVisible(false)
	briefbody:setVisible(true)
	briefbody:createTransition("activate_left")

	if self._campaign.situation.name == "escape" or self._campaign.situation.name == "initial_escape" then
		showGeneral(self, self.screen)
	else
		showDescription(self, self.screen)
		showLocation(self, self.screen)
		showGoal(self, self.screen)
		showEnder(self, self.screen)
	end

	self.screen:findWidget("acceptBtn.btn"):blink(0.2, 2, 2)
end

corpPreview.onLoad = function ( self, campaign )
	assert( campaign ~= nil )
	self._campaign = campaign

	self.screen = mui.createScreen( "corp_preview_screen.lua" )
	mui.activateScreen( self.screen )

	self._scroll_text = scroll_text.panel( self.screen.binder.bg )

	FMODMixer:pushMix("missionbrief")
	MOAIFmodDesigner.playSound("SpySociety/AMB/missionbrief", "AMB2")

	self.screen:findWidget("missionbriefbodygroup"):setVisible(false)

	local txt = self.screen:findWidget("missionbriefingheader"):getText()
	self._missionBlinkThread = MOAICoroutine.new()
	self._missionBlinkThread:run( function() 
		local i = 0
		while true do
			i = i + 1
			if i % 60 == 0 then
				self.screen:findWidget("missionbriefingheader"):setText( txt )
			elseif i % 30 == 0 then
				self.screen:findWidget("missionbriefingheader"):setText( "_"..txt )
			end

			coroutine.yield()
		end
	end )
	self._missionBlinkThread:resume()	

	self.screen:findWidget("acceptBtn.btn"):setText(STRINGS.UI.START_MISSION)
	self.screen.binder.acceptBtn.binder.btn.onClick = function() onClickContinue (self) end

	self._updateThread = MOAICoroutine.new()
	self._updateThread:run( function() self:populateCorp() end )
end

corpPreview.onUnload = function ( self )
	self._scroll_text:destroy()
	self._missionBlinkThread:stop()
	self._missionBlinkThread = nil

	self._updateThread:stop()
	self._updateThread = nil

	if self._movePOIThread then
		self._movePOIThread:stop()
		self._movePOIThread = nil
	end

	MOAIFmodDesigner.stopSound("location")
	MOAIFmodDesigner.stopSound("situation")
	MOAIFmodDesigner.stopSound("goal")
	MOAIFmodDesigner.stopSound("ender")

	self.screen:findWidget("acceptBtn.btn"):blink(0)
	MOAIFmodDesigner.stopSound("AMB2")
	FMODMixer:popMix("missionbrief")

	mui.deactivateScreen( self.screen )
end

return corpPreview
