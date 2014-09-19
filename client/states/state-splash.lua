----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "modules/util" )
local resources = include( "resources")
local stateMainMenu = include( "states/state-main-menu" )
local modalDialog = include("states/state-modal-dialog")
local stateLoading = include( "states/state-loading" )
local mui = include( "mui/mui" )

local WAIT_SECONDS = 0
----------------------------------------------------------------

local splash = {}

----------------------------------------------------------------
splash.onLoad = function ( self )

	MOAIGfxDevice.setClearColor ( 0, 0, 0, 1 )
	
	self.screen = mui.createScreen( "splash-screen.lua" )
	mui.activateScreen( self.screen )

	self.waitSeconds = WAIT_SECONDS
	self.startTime = MOAISim.getDeviceTime ()

	-- Set the current user to the last user, based on the settings file.
	local settingsFile = savefiles.getSettings( "settings" )
	savefiles.initSaveGame()
	
	settingsFile.data.enableLightingFX = (type(settingsFile.data.enableLightingFX) ~= "boolean") or settingsFile.data.enableLightingFX -- initialize to true if not a bool
	settingsFile.data.enableBackgroundFX = (type(settingsFile.data.enableBackgroundFX) ~= "boolean") or settingsFile.data.enableBackgroundFX -- initialize to true if not a bool
	settingsFile.data.enableOptionalDecore = (type(settingsFile.data.enableOptionalDecore) ~= "boolean") or settingsFile.data.enableOptionalDecore -- initialize to true if not a bool
	settingsFile.data.volumeMusic = settingsFile.data.volumeMusic or 1
	if config.RECORD_MODE then
		settingsFile.data.volumeMusic = 0
	end
	
	settingsFile.data.volumeSfx = settingsFile.data.volumeSfx or 1
	settingsFile:save()

	util.applyUserSettings( settingsFile.data )
end

----------------------------------------------------------------
splash.onUnload = function ( self )
	mui.deactivateScreen( self.screen )
	self.screen = nil
end

----------------------------------------------------------------
splash.onUpdate = function ( self )

	if self.waitSeconds < ( MOAISim.getDeviceTime () - self.startTime ) then
		statemgr.deactivate( self )
		
		if #config.LAUNCHLVL > 0 then
			-- Shortcut directly into game, to play the specified launch level
			local simparams = include( "sim/simparams" )
			local params = simparams.createParams( config.LAUNCHLVL )

			stateLoading:loadLocalGame( params )
		else
			-- Normal flow: progress to main menu
			statemgr.activate ( stateMainMenu )
		end
	end

end

return splash
