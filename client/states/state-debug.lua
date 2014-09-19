----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local version = include( "modules/version" )
local mui = include("mui/mui")
local mui_defs = include("mui/mui_defs")
local mui_util = include("mui/mui_util")
local cdefs = include( "client_defs" )
local modalDialog = include( "states/state-modal-dialog" )
local serializer = include( "modules/serialize" )
----------------------------------------------------------------

local statedebug =
{
	screen = nil,
	keybindings = {},

	mode = cdefs.DBG_NONE,
	soundMarkers = {},
	pathMarkers = {},
	pathReserves = {},

	roomHilites = {},

	huntHilites = {},

	-- For calculating elapsed time
 	startTime = 0,
	-- Profiler
	profiler = nil,
	-- Number of reports made.
	reportCount = 0,
}

-- A local "environment" for managing debug state
local debugenv =
{
	__index = function( t, k )
		local v = rawget(_G, k)
		if v then
			return v
		end
	end,

	getCurrentGame = function( self )
		local stateLocalGame = include( "states/state-localgame" )
		local stateCampaignGame = include( "states/state-campaigngame" )

		if statemgr.isActive( stateLocalGame ) then
			return stateLocalGame
		elseif statemgr.isActive( stateCampaignGame ) then
			return stateCampaignGame
		else
			return nil
		end
	end,

	updateEnv = function( self )
		self.game = self:getCurrentGame()
		self.boardRig = self.game and self.game.boardRig
		self.sim = self.game and self.game.simCore
		self.simquery = self.sim and self.sim:getQuery()
		self.simdefs = self.sim and self.sim:getDefs()
		self.currentPlayer = self.sim and self.sim:getCurrentPlayer()
		self.localPlayer = self.game and self.game:getLocalPlayer()
		self.statedebug = statedebug

		setmetatable( self, self )
	end,
}

local function generateShortcutString( binding )
	local keyCode, shiftDown, controlDown = binding[1], binding[2], binding[3]
	return string.format( "%s%s%s", controlDown and "CTRL-" or "", shiftDown and "SHIFT-" or "", mui_util.getKeyName( keyCode ))
end

local function toggleVisible()
	if statedebug.screen:isActive() then
		for cellID, fx in pairs( statedebug.soundMarkers ) do
			fx:destroy()
		end
		statedebug.soundMarkers = {}
		mui.deactivateScreen( statedebug.screen )
	else
		statedebug.startTime = MOAISim.getDeviceTime ()
		statedebug.screen:setPriority( math.huge )
		mui.activateScreen( statedebug.screen )
	end
end

local function toggleUI()
	log:write("Toggling UI visibility!")
	mui.setVisible( not mui.isVisible() )
end

local function unlockAllRewards()
	local user = savefiles.getCurrentGame()
	local metadefs = include( "sim/metadefs" )

	user.data.xp = metadefs.GetXPCap()
	user:save()

	return "Unlocked all rewards!"
end

local function testScanLineRig()
	if not game then
		return
	end
	local boardRig = game.boardRig
	local simCore = game.simCore
	local W,H = simCore:getBoardSize()

	boardRig:spawnScanLine( {{0,0}, {W+1,0}}, {{0,H+1}, {W+1,H+1}} )
end

local function reloadConfig()
	log:write("-Reloading config.lua------------")
	local res, err = pcall( dofile, "config.lua" )
	if not res then
		log:write( "ERR: %s", err )
	else
		updateConfig()
	end
	log:write("-DONE-----------------------")
end

local function gameReset()
	if game then
		reloadConfig()
	
		-- Oh, and reload the mission_panel for kicks.
		reinclude( "hud/mission_panel" )

		game:goto( 0 )
		game.simHistory = { game.simHistory[1] } -- Keep 'reserve' action only.
	end
end

local function printMemoryUsage()
	local usage = MOAISim.getMemoryUsage()

	log:write("=== MEMORY USAGE ===")
	log:write( "Lua Objects : " .. MOAISim.getLuaObjectCount() )

	for k,v in pairs(usage) do
		log:write( k .. " : " ..v )
	end
end

local function reportLeaks()
	MOAISim.reportLeaks()
end

local function copyToClipboard()
	-- Save the current campaign game progress, if the game isn't over, and this isn't a 'debug' level.
	if game and game.params.campaignHours ~= nil and not sim:isGameOver() then
		local res, err = pcall(
			function()
				local user = savefiles.getCurrentGame()
				local playTime = os.time() - game.onLoadTime
				local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]
				campaign.sim_history = serializer.serialize( game.simHistory )
				campaign.play_t = campaign.play_t + playTime
				user:save()
			end )
		if not res then
			log:write( "Failed to save game:\n%s", err )
		end
	end

	local str = util.formatGameInfo( game and game.params )
	MOAISim.copyToClipboard( str )

	-- Copy to debug location
	if config.DEV then
		local gamePath = KLEIPersistentStorage.getGameFolder()
		local targetPath = string.format( [[X:\klei\InvisibleInc\%s-%s-%d]], MOAIEnvironment.UserID, APP_GUID, statedebug.reportCount )
		statedebug.reportCount = statedebug.reportCount + 1
		MOAILogMgr.flush()
		MOAIFileSystem.affirmPath( targetPath )
		local filesCopied = MOAIFileSystem.copy( gamePath, targetPath )
		log:write( "COPY: '%s' to '%s' (%s)", gamePath, targetPath, tostring( filesCopied ) )
		cloud.sendSlackTask( string.format( "%s (%s)\n%s", APP_GUID, filesCopied and "Files copied" or "No files", str ))
	end

	return "Copied to clipboard:\n" .. str
end

local function toggleWorldBounds()
	if not game then
		return
	end

	statedebug.showWorldBounds = not statedebug.showWorldBounds

	--MOAIDebugLines.setStyle ( MOAIDebugLines.PARTITION_CELLS, 1, 1, 1, 1 )
	--MOAIDebugLines.setStyle ( MOAIDebugLines.PARTITION_PADDED_CELLS, 1, 0.5, 0.0, 0.5 )
	MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_MODEL_BOUNDS, 1, 0.0, 0.75, 0.75 )
	MOAIDebugLines.showStyle ( MOAIDebugLines.PROP_MODEL_BOUNDS, true )
	--MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_MODEL_BOUNDS, 1, 0.5, 0.5, 0.75 )
	--MOAIDebugLines.showStyle ( MOAIDebugLines.PROP_MODEL_BOUNDS, true )
	--MOAIDebugLines.setStyle ( MOAIDebugLines.PROP_MODEL_BOUNDS, 1, 0.0, 0.0, 0.75 )

	game.boardRig:getLayer():showDebugLines( statedebug.showWorldBounds )
	game.boardRig:getLayer("floor"):showDebugLines( statedebug.showWorldBounds )
	game.boardRig:getLayer("ceiling"):showDebugLines( statedebug.showWorldBounds )
end

local function printThreads()
	if game and game.simThread then
		print( "### SIM THREAD" )
		print( debug.traceback( game.simThread ))
	end
	
	if game and game.viz then
		print( "### VIZ THEAD" )
		game.viz:print()
	end
end

local function toggleProfile()
	KLEIProfiler.ToggleRecording()
	local id = KLEIProfiler.Push( "test" )
	KLEIProfiler.Pop( id )
--[[
	include( "profiler" )

	if statedebug.profiler == nil then
		log:write( "### PROFILE START")
		statedebug.profiler = newProfiler()
		statedebug.profiler:start()
	else
		statedebug.profiler:stop()
		log:write( "### PROFILE STOP")

		local outfile = io.open( "profile.txt", "w+" )
		statedebug.profiler:report( outfile )
		outfile:close()

		statedebug.profiler = nil
	end
--]]
end

local function printGarbageCollection()
	util.fullGC()
end

local function executeDbgFile()
	print( "Executing: ", config.DBG_FILE )
	if config.DBG_FILE then
		local f,e = loadfile( config.DBG_FILE )
		if not f then error(e, 2) end
		setfenv(f, getfenv())
		return f()
	end
end

local function toggleALOSDebug()
	print( 'toggleALOSDebug' )
	if game and game.shadow_map then
		statedebug.ALOS_Debug = not statedebug.ALOS_Debug
		game.shadow_map:enableALOSDebug( statedebug.ALOS_Debug )
	end
end
local function toggleELOSDebug()
	print( 'toggleELOSDebug' )
	if game and game.shadow_map then
		statedebug.ELOS_Debug = not statedebug.ELOS_Debug
		game.shadow_map:enableELOSDebug( statedebug.ELOS_Debug )
	end
end

local function showLogFolder()
	MOAISim.showLogFolder()
end

local function cycleLocalPlayer()
	if sim and not game:isReplaying() then
		if game:getLocalPlayer() == nil then
			game:setLocalPlayer( sim:getPlayers()[1] )
		else
			local nextPlayer = sim:getPlayers()[ game.playerIndex + 1 ]
			-- nextPlayer may wrap to nil; this means watch as an observer
			game:setLocalPlayer( nextPlayer )
		end
	end
end

local function cycleDebugMode()
	statedebug:setDebugMode( (statedebug.mode + 1) % cdefs.DBG_MAX )
end

local function addCpuPoints()
	if game then
		game:doAction( "debugAction",
			function( sim )
				sim:getPC():addCPUs(1)
			end )
		end
end

local function addMoney()
	if game then
		game:doAction( "debugAction",
			function( sim )
				sim:getPC():addCredits(100)
			end )
	end
end

local function seeEverything()
	if game then
		game:doAction( "debugAction",
			function( sim )
				local cells = {}
				sim:forEachCell(function(cell)
					sim:getCurrentPlayer():glimpseCell( sim, cell )
					table.insert( cells, cell.x )
					table.insert( cells, cell.y )
				end)
				sim:dispatchEvent( sim:getDefs().EV_LOS_REFRESH, { player = sim:getCurrentPlayer(), newcells = cells } )
			end )
	end
end

local function toggleRooms()
	if game and sim then
		local mode
		local sampleHilite = next(statedebug.roomHilites)
		if not sampleHilite then
			mode = "rooms"
		elseif statedebug.roomHilites[sampleHilite].edges then
			mode = "exits"
		elseif statedebug.roomHilites[sampleHilite].exits then
			mode = nil
		else
			mode = "edges"
		end
		if mode then
			--highlight all the rooms
			sim:forEachCell(function(cell)
				if cell.procgenRoom then
					local roomID = cell.procgenRoom.roomIndex
					if not statedebug.roomHilites[roomID] then
						statedebug.roomHilites[roomID] = {cells={} }
						statedebug.roomHilites[roomID].color = {r=math.random(), g=math.random(), b=math.random()}
					end
					if mode == "exits" then
						if not statedebug.roomHilites[roomID].exits then
							statedebug.roomHilites[roomID].exits = {}
							statedebug.roomHilites[roomID].barriers = {}
						end
						for i,exit in ipairs(cell.procgenRoom.exits) do	
							if cell.x >= exit.x0 and cell.x <= exit.x1 and cell.y >= exit.y0 and cell.y <= exit.y1 then
								if exit.barrier then
									table.insert(statedebug.roomHilites[roomID].barriers, cell)
								else
									table.insert(statedebug.roomHilites[roomID].exits, cell)
								end
								return
							end
						end
					else
						statedebug.roomHilites[roomID].exits = nil
						statedebug.roomHilites[roomID].barriers = nil
					end

					if mode == "edges" then
						if not statedebug.roomHilites[roomID].edges then
							statedebug.roomHilites[roomID].edges = {}
							statedebug.roomHilites[roomID].cells = {}
						end
						if cell.x ~= cell.procgenRoom.x0 and cell.x ~= cell.procgenRoom.x1
						 and cell.y ~= cell.procgenRoom.y0 and cell.y ~= cell.procgenRoom.y1
						 and cell.impass == 0 then
							table.insert(statedebug.roomHilites[roomID].cells, cell)
						else
							table.insert(statedebug.roomHilites[roomID].edges, cell)
						end
					else
						if statedebug.roomHilites[roomID].edges then
							statedebug.roomHilites[roomID].edges = nil
							statedebug.roomHilites[roomID].cells = {}
						end
						table.insert(statedebug.roomHilites[roomID].cells, cell)
					end
				end
			end)
		end

		for k,cellHilites in pairs(statedebug.roomHilites) do
			game.boardRig:unhiliteCells(cellHilites.cellHilites)
			if cellHilites.edgeHilites then
				game.boardRig:unhiliteCells(cellHilites.edgeHilites)
				cellHilites.edgeHilites = nil
			end
			if cellHilites.exitHilites then
				game.boardRig:unhiliteCells(cellHilites.exitHilites)
				cellHilites.exitHilites = nil
				game.boardRig:unhiliteCells(cellHilites.barrierHilites)
				cellHilites.barrierHilites = nil
			end
			if mode then
				local color = cellHilites.color
				local exitColor = {r=1, g=0, b=1, a=1}
				local barrierColor = {r=1, g=0, b=0, a=1}
				local alpha = {cells=0.4, edges=0.2, exits=1, barriers=1}
				cellHilites.cellHilites = game.boardRig:hiliteCells(cellHilites.cells, {alpha.cells*color.r, alpha.cells*color.g, alpha.cells*color.b, alpha.cells})
				if cellHilites.edges then
					cellHilites.edgeHilites = game.boardRig:hiliteCells(cellHilites.edges, {alpha.edges*color.r, alpha.edges*color.g, alpha.edges*color.b, alpha.edges})
				end
				if cellHilites.exits then
					cellHilites.exitHilites = game.boardRig:hiliteCells(cellHilites.exits, {alpha.exits*exitColor.r, alpha.exits*exitColor.g, alpha.exits*exitColor.b, alpha.exits})
					cellHilites.barrierHilites = game.boardRig:hiliteCells(cellHilites.barriers, {alpha.barriers*barrierColor.r, alpha.barriers*barrierColor.g, alpha.barriers*barrierColor.b, alpha.barriers})
				end
			else
				statedebug.roomHilites[k] = nil
			end
		end
	end
end


local function toggleReplayPanel()
	if game then
		if game.replayPanel == nil then
			local replay_panel = include( "hud/replay_panel" )
			game.replayPanel = replay_panel( game )
		else
			game.replayPanel:destroy()
			game.replayPanel = nil
		end
	end
end

local function toggleReplayPause()
	if game then
		if game.debugStep ~= nil then
			game.debugStep = nil
		else
			game.debugStep = true
		end
		if game.replayPanel then
			game.replayPanel:updatePanel()
		end
	end
end

local function teleportSelected()
	if game then
		local selectedUnitID = game.hud:getSelectedUnit() and game.hud:getSelectedUnit():getID()
		if selectedUnitID and sim:getUnit( selectedUnitID ) then
			local x, y = game:wndToCell( inputmgr:getMouseXY() )
			local function fn( sim, unitID, x, y )
				local unit = sim:getUnit( unitID )
				local cell = sim:getCell( x, y )
				if cell and cell ~= sim:getCell( unit:getLocation() ) then
					sim:warpUnit(unit, cell)
				end
				sim:processReactions(unit)
			end

			game:doAction( "debugAction", fn, selectedUnitID, x, y )
		end
	end
end

local function addXPToSelected()
	if game then
		local selectedUnitID = game.hud:getSelectedUnit() and game.hud:getSelectedUnit():getID()
		if selectedUnitID then
			local function fn( sim, unitID )
				local unit = sim:getUnit( unitID )
				unit:addXP( 5 )
			end
			game:doAction( "debugAction", fn, selectedUnitID )
		end
	end
end

local function addAlarm()
	if sim then
		game:doAction("debugAction",
			function(sim)
				sim:trackerAdvance(1)
			end)
	end
end

local function maxAlarm()
	if sim then
		game:doAction("debugAction",
			function(sim)
				sim:trackerAdvance( math.max( 1, sim.getDefs().TRACKER_MAXCOUNT - sim:getTracker() ))
			end)
	end
end

local function simNextTurn()
	if sim and not game:isReplaying() then
		local oldPlayerIndex = game.playerIndex
		game.playerIndex = sim:getTurn()	-- Bypass local player check.
		game:doAction( "endTurnAction" )
		game.playerIndex = oldPlayerIndex
	end
end

local function simWin()
	if sim and not game:isReplaying() and not sim:isGameOver() then
		if sim:getTags().isTutorial then
			-- Tutorial skip wait condition
			game:doAction( "triggerAction", simdefs.TRG_TUTORIAL_PASS )
		else
			game:doAction( "debugAction",
				function( sim )
					sim:win()
				end)
		end
	end
end

local function simLose()
	if sim and not game:isReplaying() and not sim:isGameOver() then
		game:doAction( "debugAction",
			function( sim )
				sim:lose()
			end)
	end
end

local function simKill()
	if sim then
		local x, y = game:wndToCell( inputmgr:getMouseXY() )
		local function fn( sim, x, y )
			local cell = sim:getCell( x, y )
			if cell and cell.units[1] then
				cell.units[1]:killUnit( sim )
			end
		end
		game:doAction( "debugAction", fn, x, y )
	end
end

local function simCreateInterest()
	if sim then

		local selectedUnitID = game.hud:getSelectedUnit() and game.hud:getSelectedUnit():getID()
		if selectedUnitID then

			local x, y = game:wndToCell( inputmgr:getMouseXY() )
			local function fn( sim, unitID, x, y )

				local unit = sim:getUnit( unitID )
				if unit then
					local brain = unit:getBrain()
					if brain then
						brain:getSenses():addInterest( x, y, simdefs.SENSE_SIGHT, simdefs.REASON_SHARED )
					end
					sim:processReactions(unit)
				end
			end
			game:doAction( "debugAction", fn, selectedUnitID, x, y )
		end
			
	end
end

local function simKillOthers()
	if sim then
		local x, y = game:wndToCell( inputmgr:getMouseXY() )
		local function fn( sim, x, y )
			local cell = sim:getCell( x, y )
			local survivor = cell and cell.units[1]
			if survivor then
				sim:forEachUnit(function(unit)
					if unit:getPlayerOwner() == survivor:getPlayerOwner() and unit ~= survivor then
						unit:killUnit(sim)
					end
				end)
			end
		end
		game:doAction( "debugAction", fn, x, y )
	end
end

local BINDINGS =
{
	DEV =
	{
		--{ mui_defs.K_?, ctrl, shift, alt, func },
		{ mui_defs.K_U, true, nil, nil, toggleUI },
		{ mui_defs.K_U, true, true, nil, unlockAllRewards },
		{ mui_defs.K_M, true, nil, nil, printMemoryUsage },
		{ mui_defs.K_Z, true, nil, nil, addMoney },
		{ mui_defs.K_V, true, nil, nil, addCpuPoints },
		{ mui_defs.K_V, true, true, nil, seeEverything },
		{ mui_defs.K_E, true, true, nil, reportLeaks },
		{ mui_defs.K_C, true, true, nil, reloadConfig },
		{ mui_defs.K_F1, nil, nil, nil, copyToClipboard },
		{ mui_defs.K_B, true, nil, nil, toggleWorldBounds },
		{ mui_defs.K_T, true, true, nil, printThreads },
		{ mui_defs.K_T, true, nil, nil, teleportSelected },
		{ mui_defs.K_X, true, nil, nil, addXPToSelected },
		{ mui_defs.K_A, true, nil, nil, addAlarm },
		{ mui_defs.K_A, true, true, nil, maxAlarm },
		{ mui_defs.K_P, nil, true, nil, toggleProfile },
		{ mui_defs.K_G, true, nil, nil, printGarbageCollection },
		{ mui_defs.K_D, true, nil, nil, executeDbgFile },
		{ mui_defs.K_L, true, true, nil, showLogFolder },
		{ mui_defs.K_L, true, nil, true, toggleALOSDebug },
		{ mui_defs.K_L, true, true, true,toggleELOSDebug },
		{ mui_defs.K_N, true, nil, nil, simNextTurn },
		{ mui_defs.K_W, true, nil, nil, simWin },
		{ mui_defs.K_L, true, nil, nil, simLose },
		{ mui_defs.K_K, true, nil, nil, simKill },
		{ mui_defs.K_K, true, true, nil, simKillOthers },
		{ mui_defs.K_I, true, nil, nil, simCreateInterest },
		{ mui_defs.K_ENTER, true, nil, nil, cycleLocalPlayer },
		{ mui_defs.K_E, true, nil, nil, cycleDebugMode },
		{ mui_defs.K_R, true, nil, nil, toggleReplayPanel },
		{ mui_defs.K_R, true, true, nil, toggleRooms },
		{ mui_defs.K_PAUSE, nil, nil, nil, toggleReplayPause },
		{ mui_defs.K_F2, true, nil, nil, testScanLineRig },
		{ mui_defs.K_F5, nil, nil, nil, gameReset },
	},
	RELEASE =
	{
		{ mui_defs.K_F1, nil, nil, nil, copyToClipboard },
		{ mui_defs.K_L, true, true, nil, showLogFolder },
	},
}


local function onDebugModeChanged( str, cmb )
	statedebug:setDebugMode( cdefs[ str ] )
end

----------------------------------------------------------------
-- statedebug Interface

function statedebug:addKeyBinding( key, controlDown, shiftDown, altDown, fn )
	for i, binding in ipairs( self.keybindings ) do
		if binding.key == key and binding.controlDown == controlDown and binding.shiftDown == shiftDown and binding.altDown == altDown then
			log:write("Replacing duplicate key binding: %s, %s, %s, %s", tostring(key), tostring(controlDown), tostring(shiftDown), tostring(altDown) )
			binding.fn = fn
			return
		end
	end

	table.insert( self.keybindings, { key = key, controlDown = controlDown, shiftDown = shiftDown, altDown = altDown, fn = fn } )
end

function statedebug:executeBinding( binding, event )
	log:write("-START BINDING [%s, %s, %s, %s]---", tostring(binding.key), tostring(binding.controlDown), tostring(binding.shiftDown), tostring(binding.altDown) )
	debugenv:updateEnv()
	setfenv( binding.fn, debugenv )
	local res, msg = xpcall(
		function() return binding.fn( event ) end,
		function( msg )	log:write( "ERR: %s", tostring(msg) ) log:write( debug.traceback() ) end )

	if res and msg then
		local thread = MOAICoroutine.new()
		thread:run( modalDialog.show, msg, "Debug" )
		thread:resume()
	end

	log:write("-END BINDING-----------------------")
end

function statedebug:onInputEvent( event )
	if event.eventType == mui_defs.EVENT_KeyDown then
		if event.key == mui_defs.K_TILDE and event.controlDown then
			toggleVisible()
		else
			for i, binding in ipairs( self.keybindings ) do
				if binding.key == event.key and binding.controlDown == event.controlDown and binding.shiftDown == event.shiftDown and binding.altDown == event.altDown then
					self:executeBinding( binding, event )
					return true
				end
			end
		end
	end

	if (statedebug.ALOS_Debug or statedebug.ELOS_Debug) and event.eventType == mui_defs.EVENT_MouseMove then
		local game = debugenv:getCurrentGame()
		local shadow_map = game and game.shadow_map
		if shadow_map then
			local x,y = game:wndToWorld( event.wx, event.wy )
			if x and y then
				--print( 'mouse', event.wx, event.wy, x,y )
				if statedebug.ALOS_Debug then
					shadow_map:setALOSDebugPos( x, y )
				end
				if statedebug.ELOS_Debug then
					shadow_map:setELOSDebugPos( x, y )
				end
			end
		end
	end

	return false
end

function statedebug:setDebugMode( mode )
	self.mode = mode or cdefs.DBG_NONE
	log:write( "DBG MODE: [%s]", tostring(self.mode))

	for i = 1, self.screen.binder.modeCmb:getItemCount() do
		local modeName = self.screen.binder.modeCmb:getItem( i )
		if cdefs[ modeName ] == self.mode then
			self.screen.binder.modeCmb:selectIndex( i )
			break
		end
	end

	local game = debugenv:getCurrentGame()
	if game then
		game.debugMode = statedebug.mode
	end
end

function statedebug:getBuildText()
	local game = debugenv:getCurrentGame()
	return string.format(  'BUILD TAG : %s\nBUILD DATE : %s\n%s',
		MOAIEnvironment.Build_Tag, MOAIEnvironment.Build_Date, util.formatGameInfo( game and game.params ) )
end

local function addSoundMarker( cellID, x, y, markers, oldMarkers )
	-- Create a sound marker for this badboy.
	markers[ cellID ], oldMarkers[ cellID ] = oldMarkers[ cellID ] or markers[ cellID ], nil
	if debugenv.game and markers[ cellID ] == nil then
		local wx, wy = debugenv.game:cellToWorld( x, y )
		markers[ cellID ] = debugenv.game.fxmgr:addLabel( tostring(cellID), wx, wy )
	end

end

function statedebug:updateSoundMarkers()
	if self.mode == cdefs.DBG_SOUND then
		local markers = {}
		local soundDbg = MOAIFmodDesigner.getDebugInfo()
		local simquery = include( "sim/simquery" )

		for i, event in ipairs(soundDbg) do
			if event.x and event.y then
				local cellID = simquery.toCellID( event.x, event.y )
				addSoundMarker( cellID, event.x, event.y, markers, self.soundMarkers )
			end
		end

		for i, event in ipairs(soundDbg.recent) do
			if event.x and event.y then
				local cellID = simquery.toCellID( event.x, event.y )
				addSoundMarker( cellID, event.x, event.y, markers, self.soundMarkers )
			end
		end

		-- Update sound markers.
		for cellID, fx in pairs( self.soundMarkers ) do
			fx:destroy()
		end
		self.soundMarkers = markers		
	else
		for cellID, fx in pairs( self.soundMarkers ) do
			fx:destroy()
		end
		self.soundMarkers = {}
	end
end

function statedebug:updateHunts()
	if not debugenv.game or not debugenv.sim then
		return
	end
	local aiPlayer = debugenv.sim:getNPC()
	local hunt = nil
	if self.mode == cdefs.DBG_SITUATION then
		local selectedUnitID = debugenv.game.hud:getSelectedUnit() and debugenv.game.hud:getSelectedUnit():getID()
		if selectedUnitID and debugenv.sim:getUnit( selectedUnitID ) then
			local selectedUnit = debugenv.sim:getUnit( selectedUnitID )
			if selectedUnit:getBrain() and selectedUnit:getBrain():getSituation().ClassType == debugenv.simdefs.SITUATION_HUNT then
				hunt = selectedUnit:getBrain():getSituation()
			end
		end
	end

	if hunt then
		debugenv.sim:forEachCell(function(cell)
			if cell.procgenRoom then
				local roomID = cell.procgenRoom.roomIndex
				if not self.huntHilites[roomID] then
					self.huntHilites[roomID] = {}
				end
				if hunt.openRooms[roomID] then
					if not self.huntHilites[roomID].open then
						self.huntHilites[roomID].open = {}
					end
					if not self.huntHilites[roomID].openHilites then
						table.insert(self.huntHilites[roomID].open, cell)
					end
				else
					self.huntHilites[roomID].open = nil
				end
				if hunt.closedRooms[roomID] then
					if not self.huntHilites[roomID].closed then
						self.huntHilites[roomID].closed = {}
					end
					if not self.huntHilites[roomID].closedHilites then
						table.insert(self.huntHilites[roomID].closed, cell)
					end
				else
					self.huntHilites[roomID].closed = nil
				end
			end
		end)
	end

	for k,cellHilites in pairs(self.huntHilites) do
		if hunt then
			local openColor = {r=0, g=1, b=0, a=1}
			local closedColor = {r=1, g=0, b=0, a=1}
			if cellHilites.open and not cellHilites.openHilites then
				cellHilites.openHilites = debugenv.game.boardRig:hiliteCells(cellHilites.open, {openColor.r, openColor.g, openColor.b, 1})
			elseif not cellHilites.open then
				debugenv.game.boardRig:unhiliteCells(cellHilites.openHilites)
				cellHilites.openHilites = nil
			end
			if cellHilites.closed and not cellHilites.closedHilites then
				cellHilites.closedHilites = debugenv.game.boardRig:hiliteCells(cellHilites.closed, {closedColor.r, closedColor.g, closedColor.b, 1})
			elseif not cellHilites.closed then
				debugenv.game.boardRig:unhiliteCells(cellHilites.closedHilites)
				cellHilites.closedHilites = nil
			end
		else
			if cellHilites.openHilites then
				debugenv.game.boardRig:unhiliteCells(cellHilites.openHilites)
			end
			if cellHilites.closedHilites then
				debugenv.game.boardRig:unhiliteCells(cellHilites.closedHilites)
			end
			self.huntHilites[k] = {}
		end
	end
end


function statedebug:getSoundText()
	local simquery = include( "sim/simquery" )
	local soundDbg = MOAIFmodDesigner.getDebugInfo()
	local txt = {}

	table.insert( txt, "<c:CCFFCC>MIXES: " )
	for _, mix in ipairs( FMODMixer:getMixes() ) do
		table.insert( txt, mix._name.." " )
	end
	table.insert( txt, "</>\n" )

	table.insert( txt, string.format( "<c:CCFFCC>FRAME: %d, FILTER: '%s'</>\n\n", soundDbg.frame, soundDbg.filter ))

	table.insert( txt, "<c:CCFFCC>== CURRENT SOUNDS:</>\n")
	for i, event in ipairs(soundDbg) do
		table.insert( txt, string.format( "%02d] %s [%s]\n", i, event.soundPath, event.alias ))
		if event.x and event.y then
			local cellID = simquery.toCellID( event.x, event.y )
			table.insert( txt, string.format( "    id=<c:ffffff>%d</>vol=%.2f, occ=%.2f, pos = <%d, %d>\n", cellID, event.volume, event.occlusion, event.x, event.y ))
		end
	end

	table.insert( txt, "\n<c:CCFFCC>== RECENT SOUNDS:</>\n" )

	for i, event in ipairs(soundDbg.recent) do
		if soundDbg.frame - event.frame < 60 then
			table.insert( txt, "<c:77FF77>" )
		end
		table.insert( txt, string.format( "%02d] %s\n", i, event.soundPath ))
		if event.x and event.y then
			local cellID = simquery.toCellID( event.x, event.y )
			table.insert( txt, string.format( "    id=<c:ffffff>%d</> vol=%.2f, occ=%.2f, pos=<%d, %d>, frame=%d\n", cellID, event.volume, event.occlusion, event.x, event.y, event.frame ))
		end
		if event.frame - soundDbg.frame < 60 then
			table.insert( txt, "</>" )
		end
	end

	return table.concat( txt )
end

function statedebug:updatePaths()
	if not debugenv.sim then
		return
	end
	local pather = debugenv.sim:getNPC().pather

	if self.mode == cdefs.DBG_PATHING then
		--create any new paths
		for k,v in pairs(pather._paths) do
			if v.path then
				if not self.pathMarkers[v.id] then
					local nodes = {}
					table.insert(nodes, v.path.startNode.location)
					for i,node in ipairs(v.path.nodes) do
						table.insert(nodes, node.location)
					end
					local color = {r=math.random(),g=math.random(),b=math.random(),a=1}
					self.pathMarkers[v.id] = {unit=v.unit, color=color, chain=debugenv.game.boardRig:chainCells(nodes, color) }
				end
			end
		end

		--remove any unneeded paths
		for k,v in pairs(self.pathMarkers) do
			if not v.unit:isValid() or not pather._paths[v.unit:getID()] or pather._paths[v.unit:getID()].id ~= k then
				debugenv.game.boardRig:unchainCells(v.chain)
				self.pathMarkers[k] = nil
			end
		end

		--create any new path reserves
		for k,v in pairs(pather._pathReserves) do
			if not self.pathReserves[k] then
				local wx, wy = debugenv.game:cellToWorld(v.node.location.x, v.node.location.y)
				local offset = 12
				wx, wy = wx+offset*math.sin(v.node.t*(math.pi/6)), wy+offset*math.cos(v.node.t*(math.pi/6))
				local color = self.pathMarkers[v.path.id] and self.pathMarkers[v.path.id].color
				self.pathReserves[k] = debugenv.game.fxmgr:addLabel( "t"..tostring(v.node.t), wx, wy, nil, color )
			end
		end

		--remove any unneeded path reserves
		for k,v in pairs(self.pathReserves) do
			if not pather._pathReserves[k] then
				v:destroy()
				self.pathReserves[k] = nil
			end
		end
	else
		for k,v in pairs(self.pathMarkers) do
			debugenv.game.boardRig:unchainCells(v.chain)
			self.pathMarkers[k] = nil
		end
		for k,v in pairs(self.pathReserves) do
			v:destroy()
			self.pathReserves[k] = nil
		end
	end

end


function statedebug:getPathingText()
	if not debugenv.sim then
		return
	end
	local txt = {}

	local pather = debugenv.sim:getNPC().pather

	--create any new paths
	for k,v in pairs(pather._paths) do
		table.insert(txt, string.format("(%d)> Unit:[%s]", v.id, tostring(v.unit:getID() ) ) )
		if v.path then
			table.insert(txt, string.format(" From:(%d,%d) To:(%d,%d)", v.path.startNode.location.x, v.path.startNode.location.y, v.goalx, v.goaly) )
			if v.goaldir then
				table.insert(txt, string.format(" Face:%s", debugenv.simdefs:stringForDir(v.goaldir) ) )
			end
			if v.targetUnit then
				table.insert(txt, string.format(" TargetUnit:[%d]", v.targetUnit:isValid() and v.targetUnit:getID() or -1 ) )
			end
			if v.result then
				table.insert(txt, string.format(" Result:%s", v.result ) )
			end
		end
		table.insert(txt, "\n")
	end

	return table.concat(txt)
end

function statedebug:getMissionText()
	if not debugenv.sim then
		return
	end
	local txt = {}

	local ls = debugenv.sim:getLevelScript()

	--create any new paths
	for i, hook in pairs( ls.hooks ) do
		table.insert( txt, string.format( "\n<c:ffffff>%d] %s</>\n", i, hook.name ))
		table.insert( txt, debug.traceback(hook.thread, "", 2) )
	end

	return table.concat(txt)
end

function statedebug:getDebugText(unit, debugMode)
	local unitrig = debugenv.boardRig:getUnitRig(unit:getID() )
	if not unitrig or not unit.getUnitData then
		return
	end

	local unitText = {}

	if debugMode == cdefs.DBG_PATHING then
		table.insert(unitText, self:getPathingText() )
		table.insert(unitText, "\n----------------------------------\n")
	else
		table.insert(unitText, string.format("UNIT: %s (%s)[%d]\n", unit:getUnitData().name, tostring(unit:getUnitData().class), unit:getID() ) )
		table.insert(unitText, string.format("FACING:%s\n", tostring(unit:getFacing() ) ) )
		table.insert(unitText, string.format("AP:%s MP:%s\n", tostring(unit.getAP and unit:getAP()), tostring(unit.getMP and unit:getMP() ) ) )
		table.insert(unitText, string.format("Owner:%s\n", util.debugPrintTableWithColours(unit.getPlayerOwner and unit:getPlayerOwner() ) ) )
	end

	if debugMode == cdefs.DBG_TRAITS then
		table.insert(unitText, "TRAITS:\n"..util.debugPrintTableWithColours(unit:getTraits(), 2) )
	elseif debugMode == cdefs.DBG_DATA then
		table.insert(unitText, "DATA:\n")
		for k,v in pairs(unit:getUnitData() ) do
			if k ~= "speech" and k ~= "sounds" and k ~= "traits" and k ~= "children" and k ~= "blurb" and type(k) ~= "function" then
				table.insert(unitText, tostring(k) )
				table.insert(unitText, "=")
				if type(v) == "table" then
					table.insert(unitText, util.debugPrintTableWithColours(v, 3) )
				else
					table.insert(unitText, tostring(v) )
				end
				table.insert(unitText, "\n")
			end
		end
	elseif debugMode == cdefs.DBG_RIGS then
		table.insert(unitText, "\nRIG INFO:\n"..(unitrig._state and unitrig._state:generateTooltip() or "") )
		if unitrig._prop.getCurrentAnim then
			table.insert(unitText, string.format("\nANIM:%s (%s)", unitrig._prop:getCurrentAnim(), unitrig._prop:getAnimFacing() ) )
		end
		table.insert(unitText, string.format("\nVISIBLE:%s SHOULDDRAW:%s", tostring(unitrig._prop:getVisible() ), tostring(unitrig._prop:shouldDraw() ) ) )
	elseif debugMode == cdefs.DBG_BTREE then
		if unit.getBrain and unit:getBrain() then
			table.insert(unitText, "\nBRAIN:\n"..(unit:getBrain():getBTreeString() ) )
		end
	elseif debugMode == cdefs.DBG_SITUATION then
		if unit.getBrain and unit:getBrain() then
			table.insert(unitText, string.format("Destination:%s\nTarget:%s\nInterest:%s\nSituation\n%s",
				util.debugPrintTableWithColours(unit:getBrain():getDestination() ),
				util.debugPrintTableWithColours(unit:getBrain():getTarget() ),
				util.debugPrintTableWithColours(unit:getBrain():getInterest() ),
				util.debugPrintTableWithColours(unit:getBrain():getSituation(), 3) ) )
			if unit:getBrain():getSenses() then
				if unit:getBrain():getSenses():checkDisabled() then
					table.insert(unitText, string.format("\nSENSES DISABLED\n") )
				end
				if unit:getBrain():getSenses():shouldUpdate() then
					table.insert(unitText, string.format("\nSENSES NEED UPDATE\n") )
				end
				table.insert(unitText, string.format("\n---------------\nTargets\n") )
				for k,v in pairs(unit:getBrain():getSenses().targets) do
					if v.unit == unit:getBrain():getSenses():getCurrentTarget() then
						table.insert(unitText, ">  ")
					end
					table.insert(unitText, util.debugPrintTableWithColours(v) )
					table.insert(unitText, "\n")
				end
				table.insert(unitText, string.format("\n---------------\nInterests\n") )
				for i,v in ipairs(unit:getBrain():getSenses().interests) do
					if v == unit:getBrain():getSenses():getCurrentInterest() then
						table.insert(unitText, ">  ")
					end
					table.insert(unitText, util.debugPrintTableWithColours(v) )
					table.insert(unitText, "\n")
				end
			end
		end
	elseif debugMode == cdefs.DBG_PATHING then
		local pather = unit:getPather()
		if pather then
			local path = pather:getPath(unit)
			if path then
				-- local reservations = {}
				-- table.insert(unitText, "Reservations:\n")
				-- for k,v in pairs(pather._pathReserves) do
				-- 	if v.path == path then
				-- 		table.insert(reservations, v)
				-- 	end
				-- end
				-- table.sort(reservations, function(a,b) return a.node.t < b.node.t end)
				-- for i,v in ipairs(reservations) do
				-- 	table.insert(unitText, util.debugPrintTableWithColours(v.node, 1) )
				-- 	table.insert(unitText, "\n")				
				-- end
				--table.insert(unitText, util.debugPrintTableWithColours(path.path, 3) )
				if path.path then
					local pathNodes = {}
					table.insert(unitText, "Path:\n")
					table.insert(pathNodes, path.path.startNode)
					if path.path.nodes then
						for k,v in ipairs(path.path.nodes) do
							table.insert(pathNodes, v)
						end
					end
					for i,v in ipairs(pathNodes) do
						table.insert(unitText, util.debugPrintTableWithColours(v, 1) )
						table.insert(unitText, "\n")				
					end
				end
			end
		end
	end
	return table.concat(unitText)
end

----------------------------------------------------------------
statedebug.onLoad = function ( self )

	inputmgr.addListener( self, 1 )

	self.startTime = MOAISim.getDeviceTime ()

	self.screen = mui.createScreen( "debug-panel.lua" )

	self.fpsText = self.screen:findWidget("fpsTxt")
	self.debugTxt = self.screen:findWidget("txt")
	self.debugBg = self.screen:findWidget( "txtBg" )

	self.screen.binder.modeCmb:addItem( "DBG_NONE" )
	self.screen.binder.modeCmb:addItem( "DBG_TRAITS" )
	self.screen.binder.modeCmb:addItem( "DBG_DATA" )
	self.screen.binder.modeCmb:addItem( "DBG_RIGS" )
	self.screen.binder.modeCmb:addItem( "DBG_BTREE" )
	self.screen.binder.modeCmb:addItem( "DBG_SITUATION" )
	self.screen.binder.modeCmb:addItem( "DBG_PROCGEN" )
	self.screen.binder.modeCmb:addItem( "DBG_SOUND" )
	self.screen.binder.modeCmb:addItem( "DBG_PATHING" )
	self.screen.binder.modeCmb:addItem( "DBG_MISSIONS" )
	self.screen.binder.modeCmb.onTextChanged = onDebugModeChanged
	self:setDebugMode( self.mode )

	for i, binding in ipairs( BINDINGS[config.DBG_BINDINGS] ) do
		self:addKeyBinding( unpack( binding ))
	end
end

----------------------------------------------------------------
statedebug.onUnload = function ( self )

	inputmgr.removeListener( self )
	if self.screen:isActive() then
		mui.deactivateScreen( self.screen )
	end
	self.screen = nil
	self.fpsText = nil
end

----------------------------------------------------------------
statedebug.onUpdate = function ( self )

	debugenv:updateEnv()
	self:updatePaths()
	self:updateSoundMarkers()
	self:updateHunts()
	if self.screen:isActive() then
		local elapsedSecs = MOAISim.getDeviceTime () - self.startTime
				
		local fpsText = string.format( "FPS: %.0f, T: %.2f", MOAISim.getPerformance(), elapsedSecs )
		self.fpsText:setText( fpsText )

		if self.mode == cdefs.DBG_NONE then
			self.debugTxt:setVisible(true)
			self.debugTxt:setText( self:getBuildText() )

		elseif self.mode == cdefs.DBG_SOUND then
			self.debugTxt:setVisible(true)
			self.debugTxt:setText( self:getSoundText() )

		elseif self.mode == cdefs.DBG_MISSIONS then
			self.debugTxt:setVisible(true)
			self.debugTxt:setText( self:getMissionText() )

		elseif self.mode == cdefs.DBG_PROCGEN and debugenv.game then
			local cellx, celly = debugenv.game:wndToCell( inputmgr.getMouseXY() )
			local cell = debugenv.sim:getCell( cellx, celly )
			local txt = ""
			if config.PATTERN then
				local flagStr, bits = config.PATTERN:getFlags( cellx, celly )
				txt = string.format( "FLAGS [%d]: %s\n", bits, flagStr )
			end
			if cell and cell.procgenRoom then
				if inputmgr.keyIsDown( mui_defs.K_SHIFT ) then
					txt = txt.. string.format( "Room Walls:\n%s\n", util.stringize( cell.procgenRoom.walls, 2 ) )
				elseif inputmgr.keyIsDown( mui_defs.K_CONTROL ) then
					txt = txt.. string.format( "Room Exits:\n%s\n", util.debugPrintTableWithColours(cell.procgenRoom.exits, 2) )
				else
					txt = txt.. string.format( "Zone %s: %s\n",
						tostring(cell.procgenRoom.zoneID), cell.procgenRoom.zone and cell.procgenRoom.zone.name or "nozone")
					if self.roomHilites[cell.procgenRoom.roomIndex] then
						local color = self.roomHilites[cell.procgenRoom.roomIndex].color
						txt = txt..string.format("<c:%s>Room %d (%d->%d, %d->%d):\n%s</>\n", util.stringizeRGBFloat(color.r, color.g, color.b),
						cell.procgenRoom.roomIndex, cell.procgenRoom.x0, cell.procgenRoom.x1, cell.procgenRoom.y0, cell.procgenRoom.y1,
						util.stringize( cell.procgenRoom, 1 ) )
					else
						txt = txt..string.format("Room (%d->%d, %d->%d):\n%s\n",
						cell.procgenRoom.x0, cell.procgenRoom.x1, cell.procgenRoom.y0, cell.procgenRoom.y1,
						util.stringize( cell.procgenRoom, 1 ) )
					end
					txt = txt..string.format( "Prefab: %s", util.stringize(cell.procgenPrefab) )
				end
			elseif cell then
				txt = txt .. string.format( "Prefab: %s", util.stringize(cell.procgenPrefab) )
			end
			self.debugTxt:setVisible(true)
			self.debugTxt:setText( txt )
		else
			local selectedUnit = debugenv.game and debugenv.game.hud and debugenv.game.hud:getSelectedUnit()
			if selectedUnit then
				self.debugTxt:setText(self:getDebugText(selectedUnit, self.mode ) )
				self.debugTxt:setVisible(true)
			elseif self.mode == cdefs.DBG_PATHING then
				self.debugTxt:setVisible(true)
				self.debugTxt:setText(self:getPathingText() )
			else
				self.debugTxt:setVisible(false)
			end
		end

		if self.debugTxt:isVisible() then
			local W, H = self.screen:getResolution()
			local xmin, ymin, xmax, ymax = self.debugTxt:getStringBounds()
			self.debugBg:setPosition( W * (xmax + xmin) / 2, H * (ymax + ymin) / 2 )
			self.debugBg:setSize( W * (xmax - xmin), H * (ymax - ymin) )
			self.debugBg:setVisible( true )
		else
			self.debugBg:setVisible( false )
		end
	end

end

return statedebug
