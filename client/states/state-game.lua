----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local boardrig = include( "gameplay/boardrig" )
local gameobj = include( "modules/game" )
local util = include( "modules/util" )
local array = include( "modules/array" )
local serverdefs = include( "modules/serverdefs" )
local cdefs = include( "client_defs" )
local camhandler = include( "gameplay/camhandler" )
local hud = include( "hud/hud" )
local modalDialog = include( "states/state-modal-dialog" )
local stateDebug = include( "states/state-debug" )
local mui_defs = include( "mui/mui_defs" )
local fxmgr = include( "gameplay/fx_manager" )
local serializer = include( "modules/serialize" )
local simguard = include( "modules/simguard" )
local simdefs = include( "sim/simdefs" )
local viz_manager = include( "gameplay/viz_manager" )

local post_process_manager = include( "post_process_manager" )

-----------------------------------------------------------------

local SOUNDCAM_VELOCITY = {0, 0, 0}
local SOUNDCAM_FWD = {1/-1.4142135623730950488016887242097, 1/-1.4142135623730950488016887242097, 0}
local SOUNDCAM_UP = {0, 0, -1}

local OVERLAY_DIMS = 256

local game = {}

-- refs to MOAI rendering layers
game.layers = nil

-- the main window for the game HUD
game.hud = nil

-- mode for debug rendering
game.debugMode = cdefs.DBG_NONE

-- refs to the rigs representing the game board itself
game.boardRig = nil

-- fx system
game.fxmgr = nil

-- ref to the client-side game simulation logic and state
game.simCore = nil
-- history of sim actions, for playback
game.simHistory = nil
-- index into current location of simHistory (index represents the last action applied to simCore)
game.simHistoryIdx = 0

-- sim coroutine
game.simThread = nil

----------------------------------------------------------------

local function event_error_handler( err )
	moai.traceback( "sim:goto() failed with err:\n" ..err )
	return err
end

function game:generateTooltip( x, y )
	if self.debugMode ~= cdefs.DBG_NONE then
		local wx, wy = self.layers["main"]:wndToWorld2D ( x, y )
		local cellx, celly = self:worldToCell( wx, wy )
		local tooltipTxt = self.boardRig:generateTooltip( self.debugMode, cellx, celly )
	
		if cellx and celly then
			tooltipTxt = tooltipTxt .. string.format("c(%d, %d) w(%.1f, %.1f)\n", tostring(cellx), tostring(celly), wx, wy )
		end
		return tooltipTxt
	end
end

local function processSim( self )
	if self.simThread == nil then
		return nil

	else
		simguard.start()
		local result, ev = coroutine.resume( self.simThread )
		if not result then
			moai.traceback( "Sim returned:\n" .. tostring(ev), self.simThread )
			ev = nil
		end
		simguard.finish()

		if ev == nil then
			-- Done processing the simulation!  No more events to process.
			self.simThread = nil
			self.simCore:getEvents():setThread( nil  )
			self:onPlaybackDone()

		elseif ev.eventType == simdefs.EV_CHECKPOINT then
			self:saveCheckpoint()

		elseif ev.eventType == simdefs.EV_RESTORE_CHECKPOINT then
			self.restore = true -- Don't restore here, we're still in the middle of processing the sim.
		end

		return ev
	end
end

function game:saveCheckpoint()
	if #self.simHistory > 0 then
		self.simHistory[ #self.simHistory ].checkpoint = true
	end
	log:write( "CHECKPOINT: %d", #self.simHistory )
end

function game:restoreCheckpoint()
	-- Clear out the actions after the latest checkpoint, then goto.
	while #self.simHistory > 0 and not self.simHistory[ #self.simHistory ].checkpoint do
		table.remove( self.simHistory )
	end

	log:write( "RESTORE CHECKPOINT: %d", #self.simHistory )

	if #self.simHistory > 0 then
		self.simHistory[ #self.simHistory ].retries = (self.simCore:getTags().retries or 0) + 1
	end

	self:goto( #self.simHistory )

	self.hud:selectUnit( self.simCore:getPC():getUnits()[1] )
end

game.dispatchScriptEvent = function( self, eventType, eventData )
	if self.simCore:getLevelScript() then
		self.simCore:getLevelScript():queueScriptEvent( eventType, eventData )
	end
end

local function refreshViz( game )
	game.boardRig:refresh()
	if game.hud then
		game.hud:refreshHud()
		if game.hud._tutorialPanel then
			game.hud._tutorialPanel:clear()
		end
	end
	game:getCamera():disableControl( false ) -- In case viz events locked the camera, make sure its unlocked
end

local function validateReplay( game )
	local old_crc = game.simCore:getCRC()
	local old_sim = game.simCore

	local tmpSim = gameobj.constructSim( game.params, game.levelData )
	local simHistoryIdx = 0
	
	simguard.start()
	while simHistoryIdx < #game.simHistory do
		simHistoryIdx = simHistoryIdx + 1
		local res, err = xpcall( function() tmpSim:applyAction( game.simHistory[simHistoryIdx] ) end, event_error_handler )
		if not res then
			log:write( "[%d/%d] %s returned %s:\n",
				simHistoryIdx, #game.simHistory, game.simHistory[simHistoryIdx].name, err )
		end
	end
	simguard.finish()

	local new_crc = tmpSim:getCRC()

	assert( old_crc == new_crc or error( string.format( "%d ~= %d", old_crc, new_crc )))
end

----------------------------------------------------------------

game.getLocalPlayer = function( self )
	return self.simCore:getPlayers()[ self.playerIndex ]
end

game.getForeignPlayer = function( self )

	for i,player in ipairs(self.simCore:getPlayers()) do
		if i ~= self.playerIndex then 
			return player
		end
	end
end

game.isLocal = function( self )
	-- True if this is a local game (not online).
	return true
end

game.cellToWorld = function( self, x, y )
	return self.boardRig:cellToWorld( x, y )
end

game.worldToCell = function( self, x, y )
	return self.boardRig:worldToCell( x, y )
end

game.worldToSubCell = function( self, x, y )
	return self.boardRig:worldToSubCell( x, y )
end

game.wndToSubCell = function( self, x, y )
	if x and y then
		x, y = self.layers["main"]:wndToWorld2D ( x, y )
		return self.boardRig:worldToSubCell( x, y )
	end
end

game.wndToCell = function( self, x, y )
	if x and y then
		x, y = self.layers["main"]:wndToWorld2D ( x, y )
		return self.boardRig:worldToCell( x, y )
	end
end

game.cellToWnd = function( self, x, y )
	x, y = self.boardRig:cellToWorld( x, y )
	return self.layers["main"]:worldToWnd( x, y )
end

game.worldToWnd = function( self, x, y, z )
	return self.layers["main"]:worldToWnd( x, y, z )
end

game.wndToWorld = function( self, x, y )
	if x and y then
		return self.layers["main"]:wndToWorld2D ( x, y )
	end
end

game.cameraPanToCell = function( self, x, y )
	local camera = self:getCamera()
	local x, y = self:cellToWorld( x, y )
	camera:panTo( x, y )
end

game.getGfxOptions = function( self )
	return self._gfxOptions
end

game.setLocalPlayer = function( self, simplayer )

	local playerIndex = util.indexOf( self.simCore:getPlayers(), simplayer )

	if self.playerIndex ~= playerIndex then
		self.playerIndex = playerIndex

		self.hud:selectUnit( nil )

		refreshViz( self )
	end
end

game.getTeamColour = function( self, simplayer )
	if not simplayer then
		return cdefs.TEAMCLR_NEUTRAL
	elseif simplayer == self:getLocalPlayer() then
		return cdefs.TEAMCLR_SELF
	else
		return cdefs.TEAMCLR_ENEMY
	end
end


game.play = function( self )
	if self.debugStep then
		return
	end

	assert( self.simHistoryIdx < #self.simHistory )
	assert( self.simThread == nil )

	self.simHistoryIdx = self.simHistoryIdx + 1

	self.simThread = coroutine.create( 
		function()
			local action = self.simHistory[ self.simHistoryIdx ]
			assert( action )
			self.simCore:applyAction( action )
		end )

	debug.sethook( self.simThread,
		function()
			error( "INFINITE LOOP DETECTED" )
		end, "", 1000000000 ) -- 1 billion instructions is... too much.

	self.simCore:getEvents():setThread( self.simThread )

	self.hud:transitionReplay( true )
	if self.replayPanel then
		self.replayPanel:updatePanel()
	end
end

game.doAction = function( self, actionName, ... )
	if self:isReplaying() then
		log:write("WARNING: attempting action '%s' during replay", actionName )
		self:skip()

	elseif self.simCore:isGameOver() then
		log:write("WARNING: attempting action '%s' during game over", actionName )
		return

	elseif self.simHistoryIdx < #self.simHistory then
		log:write("WARNING: Overwrite simhistory at %d/%d", self.simHistoryIdx, #self.simHistory )
		while self.simHistoryIdx < #self.simHistory do
			table.remove( self.simHistory )
		end
	end

	-- Construct the serialiable action table and dispatch it.
	local action = { name = actionName, crc = self.simCore:getCRC(), playerIndex = self.simCore:getTurn(), ... }

	-- Queue it in the rewind history.
	table.insert( self.simHistory, action )

	-- Play!
	if self.debugStep ~= nil then
		self.debugStep = false
	end
	self:play()
end

function game:stepBack()
	self:goto( math.max( 1, self.simHistoryIdx - 1 ))
	self.debugStep = true
end

function game:step()
	self.debugStep = false
end

game.skip = function( self )
	if self.simThread then
		self.viz:destroy()

		local ev = self.simCore:getEvents():getCurrentEvent()
		while self.simThread and (ev == nil or ev.eventType ~= simdefs.EV_CHOICE_DIALOG) do
			ev = processSim( self )
		end

		-- Either sim thread completed, or we aborted due to an interrupt event.
		refreshViz( self )

		if self.simThread then
			self.viz:processViz( ev )
			return false -- Interrupted, did not fully skip.
		end
	end

	return true
end

game.goto = function( self, idx )
	assert( idx >= 0 and idx <= #self.simHistory )
	local startTime = os.clock()
	local oldIdx = self.simHistoryIdx

	if oldIdx ~= idx then
		self.hud:destroyHud()
		self.hud = nil
	end
		
	self:skip()

	if self.simHistoryIdx > idx then
		-- We are goto'ing some action in the past.  Regenerate the sim to the origin.
		self.simCore, self.levelData = gameobj.constructSim( self.params, self.levelData )
		self.simHistoryIdx = 0
	end
	
	if self.simHistoryIdx < idx then
		-- We are goto'ing some action in the future.
		simguard.start()
		while self.simHistoryIdx < idx do
			self.simHistoryIdx = self.simHistoryIdx + 1
			local res, err = xpcall( function() self.simCore:applyAction( self.simHistory[self.simHistoryIdx] ) end, event_error_handler )
			if not res then
				log:write( "[%d/%d] %s returned %s:\n",
					self.simHistoryIdx, #self.simHistory, self.simHistory[self.simHistoryIdx].name, err )
			end
		end
		simguard.finish()
	end

	if oldIdx ~= idx then
		self.viz:destroy()
		self.fxmgr:destroy()
		self.boardRig:destroy()
		self.boardRig = boardrig( self.layers, self.levelData, self )
		self.hud = hud.createHud( self, self.players )

		self:onPlaybackDone()
	end

	util.fullGC()
	log:write( "Goto %d from %d (%d actions).  Took %.2f ms", idx, oldIdx, #self.simHistory, (os.clock() - startTime) * 1000.0 )
end

game.fastForward = function( self, idx )
	self:goto( idx or #self.simHistory )
end

function game:isReplaying()
	return self.simThread ~= nil
end

function game:onPlaybackDone()
	if self.hud then -- During a goto, the hud has been destroyed.
		self.hud:transitionReplay( false )
	end
	if self.replayPanel then
		self.replayPanel:updatePanel()
	end
end

----------------------------------------------------------------
game.onInputEvent = function ( self, event )

	if event.eventType == mui_defs.EVENT_KeyUp and event.key == mui_defs.K_SNAPSHOT then
		local image = MOAIImage.new()
		local function callback()
			local path = KLEIPersistentStorage.getScreenCaptureFolder() .. "/snapshot_" .. os.date('%d-%m-%Y-%H-%M-%S') .. ".png"
			image:writePNG(path)
		end
		if event.controlDown then
			self.diffuse_rt:grabNextFrame( image, callback )
		else
			MOAIRenderMgr.grabNextFrame( image, callback )
		end
	end

	return self.hud and self.hud:onInputEvent( event )
end

local function createLayer( viewPort, debugName )
	local layer = MOAILayer.new ()
	layer:setViewport ( viewPort )
	layer:setDebugName( debugName )
	return layer
end

function game:setupRenderTable( settings )
	local userSettings = settings or savefiles.getSettings( "settings" ).data
	
	local wireframeProps = {}
	local function beginWireframePass()
		local props = self.layers["wireframeProp"]:propList() or {}
		for _,prop in ipairs( props ) do
			prop:setWireframe( true )
			table.insert( wireframeProps, prop )
		end
	end
	local function endWireframePass()
		for _,prop in ipairs( wireframeProps ) do
			prop:setWireframe( false )
		end
		wireframeProps = {}
	end

	local diffuse_rt_table =
		{	self.layers["background"],
			self.layers["floor"],
			self.layers["main"],
			beginWireframePass, self.layers["wireframeProp"], endWireframePass,
			self.layers["ceiling"] }

	if userSettings.enableBackgroundFX then
		table.insert( diffuse_rt_table, 1, self.layers["void_fx2"] )
		table.insert( diffuse_rt_table, 1, self.backgroundLayers["void_fx1"] )
	end

	self.diffuse_rt = self.diffuse_rt or CreateRenderTarget()							--render target used for composing the diffuse texture used in bloom and color cube post process effects	
	self.diffuse_rt:setRenderTable( diffuse_rt_table )
	self.diffuse_rt:setClearColor( 0, 0, 0, 0 )
	self.diffuse_rt:setClearStencil( 0 )
	self.diffuse_rt:setClearDepth( true )

	self.shadow_map = self.shadow_map or CreateShadowMap()
	--self.shadow_map.bConstSize = true

	if self.post_process then
		self.post_process:destroy()
		self.post_process = nil
	end
	util.tclear( self.renderTable )

	if userSettings.enableLightingFX then
		local overlay_rt_table = { self.layers['overlay'] }
		self.overlay_rt = self.overlay_rt or CreateRenderTarget( OVERLAY_DIMS, OVERLAY_DIMS )
		self.overlay_rt.bConstSize
		 = true -- the overlay RT doesn't resize
		self.overlay_rt:setRenderTable( overlay_rt_table )
		self.overlay_rt:setClearColor( 0.5, 0.5, 0.5, 1.0 )
		self.overlay_rt:setClearStencil( 0 )
		self.overlay_rt:setClearDepth( true )

		self.post_process = post_process_manager.create_post_process( self.diffuse_rt, self.overlay_rt );

		self.renderTable[1] = self.shadow_map
		self.renderTable[2] = self.diffuse_rt
		self.renderTable[3] = self.overlay_rt
		self.renderTable[4] = self.post_process:getRenderable()
	else
		self.post_process = post_process_manager.create_post_process( self.diffuse_rt );

		self.renderTable[1] = self.shadow_map
		self.renderTable[2] = self.diffuse_rt
		self.renderTable[3] = self.post_process:getRenderable()
	end
end

function game:insertWireframeProp( prop )
	self.layers["wireframeProp"]:insertProp( prop )
end
function game:removeWireframeProp( prop )
	self.layers["wireframeProp"]:removeProp( prop )
end
----------------------------------------------------------------
game.onLoad = function ( self, playerIndex, params, simCore, levelData, simHistory, simHistoryIdx, uiMemento )
	self.simCore = simCore
	self.levelData = levelData
	self.onLoadTime = os.time()
	self.playerIndex = playerIndex or self.simCore:getTurn()
	self.params = params
	self.players = {}
	self.debugMode = stateDebug.mode

	local userSettings = savefiles.getSettings( "settings" ).data

	self._gfxOptions =
	{
		bMainframeMode = false,
		bFOWEnabled = true,				--Option used by board_rig to toggle FOW rendering
		FOWFilter = "fog_of_war",		--Currently selected render filter to apply to rigs in FOW (not in LOS)
		KAnimFilter = "default",		--Currently selected render filter to apply to rigs when not in FOW or FOW is disabled
		enableOptionalDecore = userSettings.enableOptionalDecore,
	}
			
	for i,playerSlot in ipairs(self.levelData.players) do
		local playerData = array.findIf( params.players, function( p ) return p.slot == playerSlot.slot end )
		if playerData then
			table.insert( self.players, { name = playerData.name, rewards = playerData.rewards, agency = playerData.agency } )
		else
			table.insert( self.players, { name = playerSlot.name } )
		end
	end
	inputmgr.addListener( self )

	local largeView = MOAIViewport.new()
	largeView:setSize( VIEWPORT_WIDTH, VIEWPORT_HEIGHT )
	largeView:setScale( VIEWPORT_WIDTH, 0 )

	local overlayView = MOAIViewport.new()
	overlayView:setSize( OVERLAY_DIMS, OVERLAY_DIMS )
	overlayView:setScale( VIEWPORT_WIDTH, 0 )

	self._eventID = addGlobalEventListener(
		function(name, val)
			if name == "resolutionChanged" then
				largeView:setSize( val[1], val[2] )
				largeView:setScale( val[1], 0 )
				overlayView:setScale( val[1], val[2] )
			elseif name == "gfxmodeChanged" then
				self:getCamera():enableEdgePan( val )
			end
		end
		)

	do
		local camera2D = MOAICamera2D.new()
		camera2D:setScl( 1, 1 )
		camera2D:setLoc( 0, 0 )
		camera2D:forceUpdate()

		local layer = MOAILayer2D.new ()
		layer:setDebugName( "void_fx1_layer" )
		layer:setViewport ( largeView )
		layer:setCamera( camera2D )

		self.backgroundLayers = {}
		self.backgroundLayers["void_fx1"] = layer
		self.backgroundLayers["void_fx1"]:setParallax( 0, 0, 0 )
	end

	self.layers = {}
	self.layers["background"] = createLayer ( largeView, "background_layer" )
	self.layers["floor"] = createLayer ( largeView, "floor_layer" )
	self.layers["main"] = createLayer ( largeView, "main_layer" )
	self.layers["main"]:setSortMode( MOAILayer.SORT_ISO )
	self.layers["ceiling"] = createLayer ( largeView, "ceiling_layer" )
	self.layers["overlay"] = createLayer ( overlayView, "overlay_layer" )

	self.layers["void_fx2"] = createLayer ( largeView, "void_fx2_layer" )
	self.layers["void_fx2"]:setParallax( 0.7, 0.7, 1 )

	self.layers["wireframeProp"] = createLayer( largeView, "wireframeProp" )


	
	
	self.renderTable = {}
	KLEIRenderScene:setGameRenderTable( self.renderTable )
	self:setupRenderTable()

	self.simHistory = simHistory or {}
	self.simHistoryIdx = simHistoryIdx or #self.simHistory
	self.debugStep = self.simHistoryIdx < #self.simHistory

	self.fxmgr = fxmgr( self.layers["ceiling"] )

	self.boardRig = boardrig( self.layers, self.levelData, self )
	self.boardRig:startSpotSounds()
	
	self.hud = hud.createHud( self, self.players )

	self.viz = viz_manager( self )

	if uiMemento then
		if uiMemento.cameraState then
			self:getCamera():setMemento( uiMemento.cameraState )
		end
		self.hud:selectUnit( self.simCore:getUnit( uiMemento.selectedUnitID ) )
	end

	self.boardRig:refresh() -- ccc: NARSTY.  boardRig has a couple dependencies on hud, but is created before the hud.
end

----------------------------------------------------------------
game.onUnload = function ( self )

	if self.cameraHandler then
		self.cameraHandler:destroy()
		self.cameraHandler = nil
	end

	if self._eventID then
		delGlobalEventListener( self._eventID )
		self._eventID = nil
	end
	inputmgr.removeListener( self )
	if self.hud then
		self.hud:destroyHud()
		self.hud = nil
	end

	if self.replayPanel then
		self.replayPanel:destroy()
		self.replayPanel = nil
	end

	self.fxmgr:destroy()
	self.fxmgr = nil

	self.boardRig:destroy()
	self.boardRig = nil

	self.layers = nil

	self.simThread = nil
	if self.viz then
		self.viz:destroy()
		self.viz = nil
	end

	self.simCore = nil

	self.players = nil
	self.simHistory = nil
	self.simHistoryIdx = 0

	util.tclear( self.renderTable )
	if self.post_process then
		self.post_process:destroy()
		self.post_process = nil
	end
	self.overlay_rt, self.diffuse_rt = nil, nil

	MOAIFmodDesigner.stopAllSounds()
end


game.updateSound = function( self )
	local framesSampled = 30
	local samplesPerFrame = 20
	local ambientCellSamples = self.ambientCellSamples or { }
	local ambientIdx = self.ambientIdx or -1
	ambientIdx = (ambientIdx + 1) % framesSampled
	
	local samples = {}
	for i=1,samplesPerFrame do
		local x,y = math.random(0,1280), math.random(0, 720)
		local cellrig = self.boardRig:getClientCellXY( self:wndToCell( x, y ) )
		if cellrig ~= nil and cellrig.tileIndex ~= nil then
			local ambientSoundType = cdefs.MAPTILES[ cellrig.tileIndex ].ambientSound
			samples[ ambientSoundType ] = 1 + (samples[ ambientSoundType ] or 0)
		else
			samples[ 0 ] = 1 + ( samples[ 0 ] or 0 )
		end
	end
	
	ambientCellSamples[ambientIdx+1] = samples
	
	local counts = {}
	for _,v in ipairs( ambientCellSamples ) do
		for t,c in pairs( v ) do 
			counts[t] = c + (counts[t] or 0)
		end
	end
	
	self.ambientCellSamples = ambientCellSamples
	self.ambientIdx = ambientIdx
	
	local avg = 1/(framesSampled*samplesPerFrame)
	
	if self.hud._isMainframe == true then
		MOAIFmodDesigner.setVolume( "AMB1", 0 )
		MOAIFmodDesigner.setVolume( "AMB2", 1 )
	else
		MOAIFmodDesigner.setVolume( "AMB1", avg*(counts[1] or 0 ) )
		MOAIFmodDesigner.setVolume( "AMB2", 0 )
	end
	
	local x, y = self:getCamera():getLoc()
	local cx, cy = self:worldToSubCell(x,y)
	self.prevCam = self.prevCam or {-1, -1}
	if cx and cy and cx ~= self.prevCam[1] and cy ~= self.prevCam[2] then
		self.prevCam[1], self.prevCam[2] = cx, cy
		MOAIFmodDesigner.setCameraProperties( { cx, cy, -10 }, SOUNDCAM_VELOCITY, SOUNDCAM_FWD, SOUNDCAM_UP )
	end
	--print( avg*(counts[0] or 0), avg*(counts[1] or 0), avg*(counts[2] or 0), avg*(counts[3] or 0) )
end
----------------------------------------------------------------

local FRAME_EV = { eventType = simdefs.EV_FRAME_UPDATE }

game.onUpdate = function ( self )

	local ev = FRAME_EV
	while not self.debugStep and ev and self.viz:processViz( ev ) do
		-- Ok.  viz is non-blocking.  Simulate if necessary.
		ev = processSim( self )

		if ev and self.debugStep ~= nil and self.replayPanel then --SIMEVENT
			-- log:write( ">%s: %s", simdefs:stringForEvent(ev.eventType), util.debugPrintTable( ev, 2 ) )
			-- log:write( debug.traceback( self.simThread ))
			self.debugStep = true
			self.replayPanel:addEvent(ev, debug.traceback( self.simThread ) )
			self.replayPanel:updatePanel()
			self.viz:processViz( ev )
			break
		end
	end

	self.fxmgr:updateFx()
	
	self:updateSound()
	
	self:getCamera():onUpdate()

	if not self:isReplaying() then
		if self.simHistoryIdx < #self.simHistory then
			self:play()

		elseif self.restore then
			self.restore = nil
			local stateLoading = include( "states/state-loading" )
			statemgr.activate( stateLoading, function() self:restoreCheckpoint() end )

		elseif self.simCore:getLevelScript() then
			self.simCore:getLevelScript():dispatchScriptEvents( self )

		end
	end

	self.boardRig:onUpdate()

	self.hud:updateHud()
end

return game
