----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include("resources")
local util = include("client_util")
local cdefs = include("client_defs")
local mui = include( "mui/mui" )
local mui_defs = include( "mui/mui_defs" )
local serverdefs = include( "modules/serverdefs" )
local metrics = include( "metrics" )
local stateLoading = include( "states/state-loading" )
local stateCredits = include( "states/state-credits" )
local stateSignUp = include( "states/state-signup" )
local modalDialog = include( "states/state-modal-dialog" )
local options_dialog = include( "hud/options_dialog" )
local simparams = include( "sim/simparams" )
local metadefs = include( "sim/metadefs" )
local scroll_text = include("hud/scroll_text")

local CHARACTER_IMAGES = 
{
	{ png="character" },
	{ png="internationale" },
	{ png="shalem", unlock="sharpshooter_1" },
}
----------------------------------------------------------------

local mainMenu = {}

local function onEnterSpool( widget )
	widget:spoolText( widget:getText() )
end

local function onClickPlay()
	if #config.DEFAULTLVL == 0 then
		local modalSaveSlots = include( "fe/saveslots-dialog" )
		local dialog = modalSaveSlots()
		dialog:show()

	else
		statemgr.deactivate( mainMenu )
		local params = simparams.createParams( config.DEFAULTLVL )
		stateLoading:loadLocalGame( params )
	end
end

local function onClickForum()
	MOAISim.visitURL( config.FORUM_URL )
end

local function onClickSignUp()
	statemgr.activate( stateSignUp )
end

local function onClickExit()
	local result = modalDialog.showYesNo( STRINGS.UI.QUIT_CONFIRM, STRINGS.UI.QUIT, nil, STRINGS.UI.QUIT )
	if result == modalDialog.OK then
		MOAIEnvironment.QUIT = true
	end
end


local function onClickCredits()
	statemgr.activate( stateCredits )
end

local function onClickOptions(dialog)
	dialog._options_dialog:show()
end

local function onClickStats()
	local stateStats = include( "states/state-stats" )
	statemgr.activate( stateStats )
end

local function onClickEarlyAccessClose(self)
	mui.deactivateScreen( self._earlyAccessScreen )
	self._earlyAccessScreen = nil
	inputmgr.removeListener( self )

	self:refreshAvgRank()
end


local function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end


local AVG_FLOOR_RANKS = 
{ 
	[1] = "Rookie",
	[2] = "Regular",
	[3] = "Veteran", 
	[4] = "Elite", 
	[5] = "Respected", 
	[6] = "Most Wanted",
	[7] = "Public Enemy #1",
	[8] = "Mastermind",
	[9] = "Infamous",
	[10] = "Infamous Legend", 
}

local TOTAL_GAMES_RANKS = 
{
	[0] = "VanillaNet", 
	[5] = "DeepNet", 
	[10] = "SPIDR.WEB",
	[15] = "DarkNet", 
	[25] = "proxy.2net",
	[40] = "EnigmaNet",
	[50] = ".NETWORK",
 }

mainMenu.refreshAvgRank = function( self )
	
	--[[
	self.screen.binder.avgRankTxt:setVisible( user.data.avgDepth ~= nil )
	if user.data.avgDepth ~= nil then 
		local avgDepth = string.sub( tostring(round(user.data.avgDepth, 2)), 1, 4 ) --Hacky way to cut off to 3 decimal places (e.g. 2.50)
		local string = string.format( STRINGS.UI.AVERAGE_MISSIONS_COMPLETE, avgDepth, #user.data.lastGames )
		local rankIndex = math.max( 1, math.min( #AVG_FLOOR_RANKS, round(user.data.avgDepth)))
		local sub1 = AVG_FLOOR_RANKS[ rankIndex ]
		local sub2 = ""
		for key,rank in pairs(TOTAL_GAMES_RANKS) do
			if #user.data.lastGames >= key then  
				sub2 = rank
			end
		end
		string = string .. "<c:4E8888>\\\\ " .. util.toupper(sub2) .. " " .. util.toupper(sub1) .."</>"
		self.screen.binder.avgRankTxt:setText( string )
	end ]]

	local user = savefiles.getCurrentGame()

	self.screen.binder.avgRankTxt:setVisible(true)
	self.screen.binder.avgRankTxt:spoolText( string.format(STRINGS.UI.STATDISPLAY, user.data.maxScore or 0, user.data.xp or 0) )
end

mainMenu.onInputEvent = function (self, event )
	if event.eventType == mui_defs.EVENT_KeyDown and event.key == mui_defs.K_ESCAPE then
		onClickEarlyAccessClose( self )
	end
end

mainMenu.earlyAccess = function(self)
	self._earlyAccessScreen = mui.createScreen( "modal-earlyaccess.lua" )

	inputmgr.addListener( self, 1 )

	mui.activateScreen( self._earlyAccessScreen )

	local closeBtn = self._earlyAccessScreen.binder.panel.binder.closeBtn
	local forumBtn = self._earlyAccessScreen.binder.panel.binder.forumBtn

	self._earlyAccessScreen.binder.panel.binder.bodyTxt:setText( STRINGS.UI.EARLY_ACCESS_MESSAGE )

	closeBtn.onClick = function() onClickEarlyAccessClose(self) end
	forumBtn.onClick = onClickForum

	closeBtn:setText( STRINGS.UI.CONTINUE )
	forumBtn:setText( STRINGS.UI.FORUMS )

	closeBtn:setHotkey( mui_defs.K_ENTER )
	forumBtn:setHotkey( nil )
end

mainMenu.onLoad = function ( self )
	FMODMixer:pushMix("frontend")
	self.screen = mui.createScreen( "main-menu.lua" )
	mui.activateScreen( self.screen )

	self._scroll_text = scroll_text.panel( self.screen.binder.bg )

	self.screen.binder.watermark:setText( config.WATERMARK )
	self.screen.binder.avgRankTxt:setVisible(false)

	self.screen.binder.playBtn.onClick = onClickPlay
	self.screen.binder.playBtn.onEnter = onEnterSpool

	self.screen.binder.signUpBtn.onClick = onClickSignUp
	self.screen.binder.signUpBtn.onEnter = onEnterSpool
	self.screen.binder.exitBtn.onClick = onClickExit
	self.screen.binder.exitBtn.onEnter = onEnterSpool
	self.screen.binder.creditsBtn.onClick = onClickCredits
	self.screen.binder.creditsBtn.onEnter = onEnterSpool
	self.screen.binder.statsBtn.onClick = onClickStats
	self.screen.binder.statsBtn.onEnter = onEnterSpool

	self.screen.binder.optionsBtn.onClick = util.makeDelegate( nil, onClickOptions, self )  
	self.screen.binder.optionsBtn.onEnter = onEnterSpool

	local imgs = {}
	for i = 1, #CHARACTER_IMAGES do
		if CHARACTER_IMAGES[i].unlock == nil then
			table.insert(imgs, CHARACTER_IMAGES[i].png)
		elseif metadefs.isRewardUnlocked(CHARACTER_IMAGES[i].unlock) then
			table.insert(imgs, CHARACTER_IMAGES[i].png)
		end
	end

	local idx = math.random(1,#imgs)
	self.screen.binder.agent:setImage( "gui/menu pages/main/"..imgs[idx]..".png")
	self.screen.binder.agent:createTransition("activate_left")

	MOAIFmodDesigner.stopMusic()
	if not MOAIFmodDesigner.isPlaying("theme") then
		MOAIFmodDesigner.playSound("SpySociety/Music/music_title","theme")
	end

	self._options_dialog = options_dialog( )

	if not config.DEV and not self._hasShownEarlyAccess then
		self:earlyAccess()
		self._hasShownEarlyAccess = true
	else
		self:refreshAvgRank()
	end

	--calculate what to say on the status
	local updateStatus = STRINGS.UI.EARLY_ACCESS_FRESH
	local daysSinceLastBuild = math.floor( os.difftime(os.time(), os.time( config.LAST_UPDATE_TIME )) /3600/24)

	--if we're not a new build
	if daysSinceLastBuild > 3 then 
		local daysToNextBuild = math.floor( os.difftime(os.time( config.NEXT_UPDATE_TIME ),os.time()) / 3600/24)

		--almost there!
		if daysToNextBuild <= 1 then
			updateStatus = STRINGS.UI.EARLY_ACCESS_IMMINENT
		else
			updateStatus = string.format( STRINGS.UI.EARLY_ACCESS_DAYS, daysToNextBuild )
		end
	end
	
	self.screen.binder.nextupdate:setText(string.format(updateStatus)) --STRINGS.UI.EARLY_ACCESS_NEXT_UPDATE, 
end

----------------------------------------------------------------
mainMenu.onUnload = function ( self )
	self._scroll_text:destroy()
	FMODMixer:popMix("frontend")
	mui.deactivateScreen( self.screen )
end

return mainMenu
