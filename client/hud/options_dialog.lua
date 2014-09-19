----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local mui = include( "mui/mui" )
local mui_defs = include( "mui/mui_defs" )
local util = include( "client_util" )
local array = include( "modules/array" )
local serverdefs = include( "modules/serverdefs" )
local gameobj = include( "modules/game" )
local cdefs = include("client_defs")
local strings = include( "strings" )

----------------------------------------------------------------
-- Local functions

local function refresh( dialog, settings )
	dialog._screen.binder.volumeSfx:setText(tostring(math.floor(settings.volumeSfx*100)))
	dialog._screen.binder.volumeMusic:setText(tostring(math.floor(settings.volumeMusic*100)))
	dialog._screen.binder.musicBar:setValue( settings.volumeMusic * 100 )
	dialog._screen.binder.soundBar:setValue( settings.volumeSfx * 100 )
	dialog._screen.binder.lightingFXbtn:setText( settings.enableLightingFX and "ON" or "OFF" )
	dialog._screen.binder.backgroundFXbtn:setText( settings.enableBackgroundFX and "ON" or "OFF" )
	dialog._screen.binder.decorebtn:setText( settings.enableOptionalDecore and "ON" or "OFF" )

	dialog._screen.binder.fastModeBtn:setText( settings.fastMode and "ON" or "OFF" )
end

local function setSettings( dialog, settings )
    refresh( dialog, settings )
	if dialog._game then
		if settings.enableLightingFX ~= dialog._appliedSettings.enableLightingFX or settings.enableBackgroundFX ~= dialog._appliedSettings.enableBackgroundFX then
			dialog._game:setupRenderTable( settings )
		end
		if dialog._game.boardRig and settings.enableOptionalDecore ~= dialog._appliedSettings.enableOptionalDecore then
			dialog._game:getGfxOptions().enableOptionalDecore = settings.enableOptionalDecore
			dialog._game.boardRig:refreshDecor()
		end
	end
	util.applyUserSettings( settings )
	dialog._appliedSettings = util.tcopy(settings)
end

local function setGfxSettings( dialog, settings )
	local gfxSettings =
	{
		bDirectX11 = settings.bDirectX11,
		bFullscreen = settings.bFullscreen,
		bVsync = settings.bVsync,
		sDisplay = settings.sDisplay,
		iWidth = settings.iWidth,
		iHeight = settings.iHeight,
		iFrequency = settings.iFrequency,
	}

	if util.applyGfxSettings( gfxSettings )  then
		dialog._gfxAppliedOptions = util.tcopy( gfxSettings )
	end
end

local function onClickAccept( dialog ) 
	local settingsFile = savefiles.getSettings( "settings" )
	settingsFile.data = util.tcopy( dialog._appliedSettings )
	settingsFile:save()

	setGfxSettings( dialog, dialog._gfxCurrentOptions )

	local gfxSettingsFile = savefiles.getSettings( "gfx" )
	gfxSettingsFile.data = util.tcopy( dialog._gfxAppliedOptions )
	gfxSettingsFile:save()

	dialog:hide()	-- Kill this dialog.
end

local function onClickCancel( dialog )
	setSettings( dialog, dialog._originalSettings )
	setGfxSettings( dialog, dialog._gfxOriginalOptions )
	dialog:hide()	-- Kill this dialog.
end

local function onClickMusicBar( dialog, widget, value )
	dialog._currentSettings.volumeMusic = math.max( 0, math.min( 1, value/100 ))
	setSettings( dialog, dialog._currentSettings )
end

local function onClickSoundBar( dialog, widget, value )
	dialog._currentSettings.volumeSfx = math.max( 0, math.min( 1, value/100 ))
	setSettings( dialog, dialog._currentSettings )
end

local function toggleLightingFX(dialog)
	dialog._currentSettings.enableLightingFX = not dialog._currentSettings.enableLightingFX
	setSettings( dialog, dialog._currentSettings )
end

local function toggleBackgroundFX(dialog)
	dialog._currentSettings.enableBackgroundFX = not dialog._currentSettings.enableBackgroundFX
	setSettings( dialog, dialog._currentSettings )
end

local function toggleOptionalDecore(dialog)
	dialog._currentSettings.enableOptionalDecore = not dialog._currentSettings.enableOptionalDecore
	setSettings( dialog, dialog._currentSettings )
end

local function onClickFastModeBtn(dialog)
	dialog._currentSettings.fastMode = not dialog._currentSettings.fastMode
	setSettings( dialog, dialog._currentSettings )
end

local function populateGfxRefreshCmb( dialog )
	local combo = dialog._screen.binder.gfxRefreshCmb
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.iFrequencyIdx = 1
	combo:clearItems()
	if gfxOptions.bFullscreen then
		--FULLSCREEN MODE
		local displaylist = MOAISim.getGfxDeviceDisplayModes()
		local display = displaylist[ gfxOptions.iDisplayIdx ]
		local mode = display.modes[ gfxOptions.iModeIdx ]
		for i,frequency in ipairs( mode.frequencys ) do
			combo:addItem( frequency )
			if frequency == gfxOptions.iFrequency then
				gfxOptions.iFrequencyIdx = i
			end
		end
	else
		--WINDOWED MODE
		local displaymode = MOAISim.getGfxCurrentDisplayMode()
		combo:addItem( displaymode.frequency )
	end
	combo:selectIndex( gfxOptions.iFrequencyIdx )
	combo:setDisabled( combo:getItemCount() <= 1 )
end
local function populateGfxModeCmb( dialog )
	local combo = dialog._screen.binder.gfxModeCmb
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.iModeIdx = 1
	combo:clearItems()
	if gfxOptions.bFullscreen then
		--FULLSCREEN MODE
		local displaylist = MOAISim.getGfxDeviceDisplayModes()
		local display = displaylist[ gfxOptions.iDisplayIdx ]
		for i,mode in ipairs( display.modes ) do
			combo:addItem( mode.width .. "x" .. mode.height )
			if mode.width == gfxOptions.iWidth and mode.height == gfxOptions.iHeight then
				gfxOptions.iModeIdx = i
			end
		end
	else
		--WINDOWED MODE
		local displaymode = MOAISim.getGfxCurrentDisplayMode()
		combo:addItem( displaymode.width .. "x" .. displaymode.height )
	end
	combo:selectIndex( gfxOptions.iModeIdx )
	combo:setDisabled( combo:getItemCount() <= 1 )
	populateGfxRefreshCmb( dialog )
end

local function populateGfxDisplayCmb( dialog )
	local combo = dialog._screen.binder.gfxDisplayCmb
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.iDisplayIdx = 1
	combo:clearItems()

	if gfxOptions.bFullscreen then
		--FULLSCREEN MODE
		local displaylist = MOAISim.getGfxDeviceDisplayModes()
		for i,display in ipairs( displaylist ) do
			combo:addItem( display.name )
			if display.name == gfxOptions.sDisplay then
				gfxOptions.iDisplayIdx = i
			end
		end
	else
		--WINDOWED MODE
		local displaymode = MOAISim.getGfxCurrentDisplayMode()
		combo:addItem( displaymode.name )
	end
	combo:selectIndex( gfxOptions.iDisplayIdx )
	combo:setDisabled( combo:getItemCount() <= 1 )
	populateGfxModeCmb( dialog )
end

local function initGfxPane( dialog )
	local gfxFile = savefiles.getSettings( "gfx" )
	local displaymode = MOAISim.getGfxCurrentDisplayMode()
	local gfxOrigins =
	{
		bDirectX11 = dialog._gfxCurrentOptions.bDirectX11,
		sDisplay = displaymode.name,
		bFullscreen = displaymode.fullscreen,
		bVsync = displaymode.vsync,
		iWidth = displaymode.width,
		iHeight = displaymode.height,
		iFrequency = displaymode.frequency,
	}
	dialog._gfxCurrentOptions = util.tcopy( gfxOrigins )
	dialog._gfxAppliedOptions = util.tcopy( gfxOrigins )


	dialog._screen.binder.gfxFullscreenBtn:setText( displaymode.fullscreen and "ON" or "OFF" )
	dialog._screen.binder.gfxVsyncBtn:setText( displaymode.vsync and "ON" or "OFF" )
	dialog._screen.binder.gfxDX11Enabled:setText( gfxOrigins.bDirectX11 and "enabled" or "disabled" )
	populateGfxDisplayCmb( dialog )
end

--Graphics mode changes are batched and all 'applied' at once
local function onGfxApplyBtn( dialog )
	local gfxOptions = dialog._gfxCurrentOptions
	setGfxSettings( dialog, gfxOptions )
end
local function onGfxDX11EnabledBtn( dialog )
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.bDirectX11 = not gfxOptions.bDirectX11
	dialog._gfxAppliedOptions.bDirectX11 = gfxOptions.bDirectX11
	dialog._screen.binder.gfxDX11Enabled:setText( gfxOptions.bDirectX11 and "enabled" or "disabled" )
end
local function onGfxFullscreenBtn( dialog )
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.bFullscreen = not gfxOptions.bFullscreen
	dialog._screen.binder.gfxFullscreenBtn:setText( gfxOptions.bFullscreen and "ON" or "OFF" )
	populateGfxDisplayCmb( dialog )
end
local function onGfxVsyncBtn( dialog )
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.bVsync = not gfxOptions.bVsync
	dialog._screen.binder.gfxVsyncBtn:setText( gfxOptions.bVsync and "ON" or "OFF" )
end
local function onGfxDisplayCmb( dialog )
	local combo = dialog._screen.binder.gfxDisplayCmb
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.iDisplayIdx = combo:getIndex()
	gfxOptions.sDisplay = combo:getText()
	populateGfxModeCmb( dialog )
end
local function onGfxModeCmb( dialog )
	local combo = dialog._screen.binder.gfxModeCmb
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.iModeIdx = combo:getIndex()

	if gfxOptions.bFullscreen then
		local displaylist = MOAISim.getGfxDeviceDisplayModes()
		local display = displaylist[ gfxOptions.iDisplayIdx ]
		local mode = display.modes[ gfxOptions.iModeIdx ]
		gfxOptions.iWidth = mode.width
		gfxOptions.iHeight = mode.height
	end
	populateGfxRefreshCmb( dialog )
end
local function onGfxRefreshCmb( dialog )
	local combo = dialog._screen.binder.gfxRefreshCmb
	local gfxOptions = dialog._gfxCurrentOptions
	gfxOptions.iFrequencyIdx = combo:getIndex()
	if gfxOptions.bFullscreen then
		local displaylist = MOAISim.getGfxDeviceDisplayModes()
		local display = displaylist[ gfxOptions.iDisplayIdx ]
		local mode = display.modes[ gfxOptions.iModeIdx ]
		local frequency = mode.frequencys[ gfxOptions.iFrequencyIdx ]
		gfxOptions.iFrequency = frequency
	else
		local displaymode = MOAISim.getGfxCurrentDisplayMode()
		gfxOptions.iFrequency = displaymode.frequency
	end
end

local function onGlobalEvent( dialog, name, value )
	if name == "gfxmodeChanged" then			--graphics mode changed in some way
		initGfxPane( dialog )
		return
	end

	local gfxOptions = dialog._gfxCurrentOptions
	local gfxOrigins = dialog._gfxOriginalOptions
	
	if not gfxOptions.bFullscreen and not gfxOrigins.bFullscreen and --Currently windowed and windowed selected
	   ( name == "screenPosChanged" or		--moving the window can trigger a display change when windowed
		 name == "resolutionChanged" ) then	--resized the window
		populateGfxDisplayCmb( dialog )
	end
end

----------------------------------------------------------------
-- Interface functions

local options_dialog = class()

function options_dialog:init(game)

	local screen = mui.createScreen( "options_dialog_screen.lua" )
	self._game = game
	self._screen = screen

	self._originalSettings = {}
	self._currentSettings = {}
	self._appliedSettings = {}

	screen.binder.acceptBtn.binder.btn.onClick = util.makeDelegate( nil, onClickAccept, self )
	screen.binder.acceptBtn.binder.btn:setText(STRINGS.UI.BUTTON_ACCEPT)
	screen.binder.cancelBtn.binder.btn.onClick = util.makeDelegate( nil, onClickCancel, self )
	screen.binder.cancelBtn.binder.btn:setText(STRINGS.UI.BUTTON_CANCEL)

	screen.binder.cancelBtn.binder.btn:setHotkey( mui_defs.K_ESCAPE )

	-- Sound FX
	screen.binder.musicBar.onValueChanged = util.makeDelegate( nil, onClickMusicBar, self )
	screen.binder.soundBar.onValueChanged = util.makeDelegate( nil, onClickSoundBar, self )
	
	--GFX bindings
	screen.binder.lightingFXbtn.onClick = util.makeDelegate( nil, toggleLightingFX, self )
	screen.binder.backgroundFXbtn.onClick = util.makeDelegate( nil, toggleBackgroundFX, self )
	screen.binder.decorebtn.onClick = util.makeDelegate( nil, toggleOptionalDecore, self )
	screen.binder.gfxDX11Enabled.onClick = util.makeDelegate( nil, onGfxDX11EnabledBtn, self )
	screen.binder.gfxApplyBtn.binder.btn.onClick = util.makeDelegate( nil, onGfxApplyBtn, self )
	screen.binder.gfxApplyBtn.binder.btn:setText(STRINGS.UI.BUTTON_APPLY)
	screen.binder.gfxFullscreenBtn.onClick = util.makeDelegate( nil, onGfxFullscreenBtn, self )
	screen.binder.gfxVsyncBtn.onClick = util.makeDelegate( nil, onGfxVsyncBtn, self )
	screen.binder.gfxDisplayCmb.onTextChanged = util.makeDelegate( nil, onGfxDisplayCmb, self )
	screen.binder.gfxModeCmb.onTextChanged = util.makeDelegate( nil, onGfxModeCmb, self )
	screen.binder.gfxRefreshCmb.onTextChanged = util.makeDelegate( nil, onGfxRefreshCmb, self )
	
	screen.binder.gfxDX11Enabled:setTextColorActive( 140/255, 1, 1 )
	screen.binder.gfxDX11Enabled:setTextColorInactive( 1, 1, 1)
	screen.binder.gfxFullscreenBtn:setTextColorActive( 140/255, 1, 1 )
	screen.binder.gfxFullscreenBtn:setTextColorInactive( 1, 1, 1 )
	screen.binder.gfxVsyncBtn:setTextColorActive( 140/255, 1, 1 )
	screen.binder.gfxVsyncBtn:setTextColorInactive( 1, 1, 1 )
	screen.binder.lightingFXbtn:setTextColorActive( 140/255, 1, 1 )
	screen.binder.lightingFXbtn:setTextColorInactive( 1, 1, 1 )
	screen.binder.backgroundFXbtn:setTextColorActive( 140/255, 1, 1 )
	screen.binder.backgroundFXbtn:setTextColorInactive( 1, 1, 1 )
	screen.binder.decorebtn:setTextColorActive( 140/255, 1, 1 )
	screen.binder.decorebtn:setTextColorInactive( 1, 1, 1 )
	
	if MOAIEnvironment.osBrand ~= "Windows" then
		screen.binder.gfxDX11Enabled:setDisabled( true )
		screen.binder['dx11 label']:setColor( 140/255, 140/255, 140/255 )
		screen.binder.gfxDX11Enabled:setTextColor( 140/255, 140/255, 140/255 )
	end
	
	local DALTONISM = { "Default", "Protanopia", "Deuteranopia", "Tritanopia" }
	for i, type in ipairs( DALTONISM ) do
		screen.binder.daltonismCmb:addItem( type )
	end
	screen.binder.daltonismCmb:selectIndex(1)
	screen.binder.daltonismCmb.onTextChanged = util.makeDelegate( self, "onFilterChanged" )

	-- Gameplay bindings
	screen.binder.fastModeBtn.onClick = util.makeDelegate( nil, onClickFastModeBtn, self )
	screen.binder.fastModeBtn:setTextColorActive( 140/255, 1, 1 )
	screen.binder.fastModeBtn:setTextColorInactive( 1, 1, 1 )

	screen.binder.tabs:selectTab( 1 )
end

function options_dialog:onFilterChanged( str )
	local filter = self._screen.binder.daltonismCmb:getIndex()
	if filter and filter >= 1 and filter <= 4 then
		KLEIRenderScene:setDaltonizationType( filter-1 )
	end
end

function options_dialog:show()
	mui.activateScreen( self._screen )

	MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_POPUP )
	
	local settingsFile = savefiles.getSettings( "settings" )
	self._originalSettings = util.tcopy(settingsFile.data)
	self._currentSettings = util.tcopy(settingsFile.data)
	self._appliedSettings = util.tcopy(settingsFile.data)

	local gfxFile = savefiles.getSettings( "gfx" )
	local displaymode = MOAISim.getGfxCurrentDisplayMode()
	local gfxOrigins =
	{
		bDirectX11 = gfxFile.data.bDirectX11 or false, -- initialize to false if nil
		sDisplay = displaymode.name,
		bFullscreen = displaymode.fullscreen,
		bVsync = displaymode.vsync,
		iWidth = displaymode.width,
		iHeight = displaymode.height,
		iFrequency = displaymode.frequency,
	}
	self._gfxOriginalOptions = gfxOrigins
	self._gfxCurrentOptions = util.tcopy( gfxOrigins )
	self._gfxAppliedOptions = util.tcopy( gfxOrigins )

	initGfxPane( self )

	refresh( self, self._currentSettings )

	--add a global event listener
	self._listenerID = addGlobalEventListener( function(name,value) onGlobalEvent(self,name,value) end )
end

function options_dialog:hide()
	--remove the global event listener
	delGlobalEventListener( self._listenerID )
	self._listenerID = nil

	self._screen.binder.tabs:selectTab( 1 )

	if self._screen:isActive() then
		mui.deactivateScreen( self._screen )
	end
end

return options_dialog
