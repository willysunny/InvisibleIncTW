----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources" )
local unitrig = include( "gameplay/unitrig" )
local doorrig2 = include( "gameplay/doorrig2" )
local zonerig = include( "gameplay/zonerig" )
local itemrig = include( "gameplay/itemrig" )
local wallrig2 = include( "gameplay/wallrig2" )
local wall_vbo = include( "gameplay/wall_vbo" )
local postrig = include( "gameplay/postrig" )
local cellrig = include( "gameplay/cellrig" )
local coverrig = include( "gameplay/coverrig" )
local pathrig = include( "gameplay/pathrig" )
local agentrig = include( "gameplay/agentrig" )
local decorig = include( "gameplay/decorig" )
local lightrig = include( "gameplay/lightrig" )
local particlerig = include( "gameplay/particlerig" )
local overlayrigs = include( "gameplay/overlayrigs" )
local sound_ring_rig = include( "gameplay/sound_ring_rig" )
local scan_line_rig = include( "gameplay/scan_line_rig" )
local world_sounds = include( "gameplay/world_sounds" )
local fxbackgroundrig = include( "gameplay/fxbackgroundrig" )
local util = include( "modules/util" )
local mathutil = include( "modules/mathutil" )
local array = include( "modules/array" )
local animmgr = include( "anim-manager" )
local cdefs = include( "client_defs" )
local serverdefs = include( "modules/serverdefs" )
local simdefs = include( "sim/simdefs" )
local simquery = include( "sim/simquery" )
local level = include( "sim/level" )


-----------------------------------------------------
-- Local

local boardrig = class( )

--------------------------------------------
-- refresh sub rigs

function boardrig:getUnitRig( unitID )
	local unitRig = self._unitRigs[ unitID ]
	if unitRig and unitRig:getUnit() == nil then
		unitRig:destroy()
		self._unitRigs[ unitID ] = nil
		unitRig = nil
	elseif unitRig == nil then
		local unit = self:getLastKnownUnit( unitID )
		if unit then
			unitRig = self:createUnitRig( unit ) -- Lazy rig creation.
		end
	end

	return unitRig
end

function boardrig:getDoorRig( cell, dir )
	-- Lookup the door rig that is visible (a given door rig can be identified by one of two cell/dir pairs)
	if dir == simdefs.DIR_W or dir == simdefs.DIR_S then
		cell = cell.exits[ dir ].cell
		dir = dir - 4
	end

	for i,doorRig in ipairs(self._doorRigs) do
		local x, y = doorRig:getLocation1()
		if dir == doorRig:getFacing1() and x == cell.x and y == cell.y then
			return doorRig
		end
	end
end

function boardrig:refreshBackgroundFX()
	local currentPlayer = self:getSim():getCurrentPlayer()
	self._backgroundFX:refresh( currentPlayer and currentPlayer:isPC() )
end

function boardrig:refreshUnits( )
	local sim = self._game.simCore
	-- Need to create rigs for units that should exist.
	for unitID, unit in pairs(sim:getAllUnits()) do
		if self._unitRigs[ unitID ] == nil and unit:getLocation() then
			self:createUnitRig( unit )
		end
	end

	-- Similarily, destroy rigs for units that no longer exist; or refresh those that do
	for unitID, unitRig in pairs(self._unitRigs) do
		if unitRig:getUnit() == nil then
			unitRig:destroy()
			self._unitRigs[ unitID ] = nil
		else
			unitRig:refresh()
		end
	end
end

function boardrig:refreshWalls( )
	for i,wallRig in ipairs(self._wallRigs) do
		wallRig:refresh( )
	end
end

function boardrig:refreshDoors( )
	for i,doorRig in ipairs(self._doorRigs) do
		doorRig:refresh( )
	end
end

function boardrig:refreshDecor( )
	self._decorig:refresh( )
end

function boardrig:refreshCells( cells )
	local updateRigs = {}
	for _, cellRig in pairs( cells or self._cellRigs ) do
		cellRig:refresh()
		cellRig:addDependentRigs( updateRigs )
	end
	for k, rig in pairs( updateRigs ) do
		rig:refresh()
	end
end

function boardrig:queryCellOcclusion( unit, x, y )

--[[
	local camera = self._game:getCamera()
	local dx, dy = camera:orientVector(1,1)
	local orientation = camera:getOrientation()*2
	
	local sim = self:getSim()
	local simquery = sim:getQuery()
	local simdefs = sim:getDefs()

	local coverPattern =
	{
		{ x+0*dx, y+0*dy, {simdefs.DIR_N, simdefs.DIR_E} },
		{ x+1*dx, y+0*dy, {simdefs.DIR_N} },
		{ x+0*dx, y+1*dy, {simdefs.DIR_E} },
		{ x+1*dx, y+1*dy, {simdefs.DIR_N, simdefs.DIR_E } },
		--{ x+2*dx, y+1*dy, {simdefs.DIR_N} },
		--{ x+1*dx, y+2*dy, {simdefs.DIR_E} },
		--{ x+2*dx, y+2*dy, {simdefs.DIR_N, simdefs.DIR_E } },
	}

	for _,p in ipairs( coverPattern ) do
		local x,y,dirs = unpack( p )
		local cell = x and self:getLastKnownCell( x, y )
		if cell then
			for _,d in ipairs( dirs ) do
				local isCover = simquery.checkIsCover( sim, cell, camera:orientDirection( d ) )
				if isCover then
					return true
				end
			end
		end
	end	
]]
	if unit:isNPC() then
		return false
	end
	
	local sim = self:getSim()
	local simquery = sim:getQuery()
	local simdefs = sim:getDefs()
	local camera = self._game:getCamera()
	local dx, dy = camera:orientVector(1,1)

	local cell = x and self:getLastKnownCell( x, y )
	if cell then
		--half cover close to me
		if 	simquery.checkIsHalfWall( sim, cell, camera:orientDirection( simdefs.DIR_N ) ) or 
			simquery.checkIsHalfWall( sim, cell, camera:orientDirection( simdefs.DIR_S ) ) or 
			simquery.checkIsHalfWall( sim, cell, camera:orientDirection( simdefs.DIR_W ) ) or 
			simquery.checkIsHalfWall( sim, cell, camera:orientDirection( simdefs.DIR_E ) ) then
			return true
		end

		--door close to me
		if simquery.checkIsDoor( sim, cell, camera:orientDirection( simdefs.DIR_N ) ) or simquery.checkIsDoor( sim, cell, camera:orientDirection( simdefs.DIR_E ) ) then
			return true
		end

		--corners
		for _, dir in ipairs( simdefs.DIR_SIDES ) do
			if simquery.agentShouldLean(sim, cell, dir) then
				return true
			end
		end
		--[[
		--wall 2 tiles away from me
		if simquery.checkIsWall( sim, self:getLastKnownCell( x + dx, y ), camera:orientDirection( simdefs.DIR_N ) ) or simquery.checkIsWall( sim, self:getLastKnownCell( x + dx, y ), camera:orientDirection( simdefs.DIR_E ) ) then
			return true
		end

		--wall 2 tiles away from me
		if simquery.checkIsWall( sim, self:getLastKnownCell( x, y + dy ), camera:orientDirection( simdefs.DIR_E ) ) then
			return true
		end
		]]

	end
	return false
end

function boardrig:displaySoundRing( x0, y0, maxRange )
	local soundRingRig = sound_ring_rig( self, x0, y0, maxRange, 1.0, {140/255, 255/255, 255/255, 0.3} )
	table.insert( self._dynamicRigs, soundRingRig )
end

function boardrig:refreshLOSCaster( seerID )
	local seer = self._game.simCore:getUnit( seerID )

	-- The hasLOS condition needs to (unfortunately) be matched with whatever is determined in sim:refreshUnitLOS in order
	-- to correctly reflect the sim state.
	local hasLOS = seer and seer:getLocation() ~= nil
	hasLOS = hasLOS and seer:getTraits().hasSight and not seer:isKO()
	hasLOS = hasLOS and (not seer:getTraits().cloaked or seer:getPlayerOwner() == self:getLocalPlayer())
	
	if hasLOS then
		local localPlayer = self:getLocalPlayer()
		local unitRig = self:getUnitRig( seerID )
		if unitRig == nil or unitRig.refreshLOSCaster == nil or not unitRig:refreshLOSCaster( seerID ) then
			local x0, y0 = self:cellToWorld( seer:getLocation())			

			local losArc = simquery.getLOSArc( seer )
			assert( losArc >= 0, losArc )

			local bAgentLOS = (seer:getPlayerOwner() == localPlayer)
			local bEnemyLOS = not bAgentLOS and not seer:isPC()
			local arcStart = seer:getFacingRad() - losArc/2
			local arcEnd = seer:getFacingRad() + losArc/2
			local range = seer:getTraits().LOSrange and self:cellToWorldDistance( seer:getTraits().LOSrange )

			--[[ Sample code to put in animated LOS angles
			local arcHalf = (arcEnd + arcStart)/2
			
			local function lerp( a, b, t )
				return a*(1-t) + t*b
			end

			local arcEndCurve = MOAIAnimCurve.new ()
			arcEndCurve:reserveKeys ( 4 )
			arcEndCurve:setKey ( 1, 0.0, lerp( arcEnd, arcHalf, 0.000 ) )
			arcEndCurve:setKey ( 2, 0.5, lerp( arcEnd, arcHalf, 0.125 ) )
			arcEndCurve:setKey ( 3, 2.5, lerp( arcEnd, arcHalf, 0.375 ) )
			arcEndCurve:setKey ( 4, 3.0, lerp( arcEnd, arcHalf, 0.500 ) )
			local arcEndCurveTimer = MOAITimer.new ()
			arcEndCurveTimer:setSpan ( 0, arcEndCurve:getLength ())
			arcEndCurveTimer:setMode( MOAITimer.PING_PONG )
			arcEndCurve:setAttrLink ( MOAIAnimCurve.ATTR_TIME, arcEndCurveTimer, MOAITimer.ATTR_TIME )
			arcEndCurveTimer:start()

			local arcStartCurve = MOAIAnimCurve.new ()
			arcStartCurve:reserveKeys ( 4 )
			arcStartCurve:setKey ( 1, 0.0, lerp( arcStart, arcHalf, 0.000 ) )
			arcStartCurve:setKey ( 2, 0.5, lerp( arcStart, arcHalf, 0.125 ) )
			arcStartCurve:setKey ( 3, 2.5, lerp( arcStart, arcHalf, 0.375 ) )
			arcStartCurve:setKey ( 4, 3.0, lerp( arcStart, arcHalf, 0.500 ) )
			local arcStartCurveTimer = MOAITimer.new ()
			arcStartCurveTimer:setSpan ( 0, arcStartCurve:getLength ())
			arcStartCurveTimer:setMode( MOAITimer.PING_PONG )
			arcStartCurve:setAttrLink ( MOAIAnimCurve.ATTR_TIME, arcStartCurveTimer, MOAITimer.ATTR_TIME )
			arcStartCurveTimer:start()
			local type = bAgentLOS and KLEIShadowMap.ALOS_DIRECT or KLEIShadowMap.ELOS_DIRECT or KLEIShadowMap.ELOS_PERIPHERY
			self._game.shadow_map:insertLOS( type, seerID, arcStartCurve, arcEndCurve, 64.0, x0, y0 )
			--]]

			if bAgentLOS then
				self._game.shadow_map:insertLOS( KLEIShadowMap.ALOS_DIRECT, seerID, arcStart, arcEnd, range, x0, y0 )
			elseif bEnemyLOS then
				self._game.shadow_map:insertLOS( KLEIShadowMap.ELOS_DIRECT, seerID, arcStart, arcEnd, range, x0, y0 )
				if seer:getTraits().LOSperipheralArc then
					local range = seer:getTraits().LOSperipheralRange and self:cellToWorldDistance( seer:getTraits().LOSperipheralRange )
					local losArc = seer:getTraits().LOSperipheralArc
					local arcStart = seer:getFacingRad() - losArc/2
					local arcEnd = seer:getFacingRad() + losArc/2

					self._game.shadow_map:insertLOS( KLEIShadowMap.ELOS_PERIPHERY, seerID + simdefs.SEERID_PERIPHERAL, arcStart, arcEnd, range, x0, y0 )
				end
			end
		end
	else
		self._game.shadow_map:removeLOS( seerID )
		self._game.shadow_map:removeLOS( seerID + simdefs.SEERID_PERIPHERAL )
	end
end

function boardrig:checkForAppearedSounds(cellrig)
	local cell = self:getSim():getCell(cellrig._x, cellrig._y)
	
	if cell and self:canPlayerSee(cellrig._x, cellrig._y) then
		local x0,y0 = cell.x,cell.y
		for i,unit in ipairs(cell.units) do
			if unit:getSounds().appeared and not unit:getTraits()._appearedSoundTriggered then
				
				self:getUnitRig( unit:getID() ):addAnimFx( "fx/item_revealed", "whole", "idle", true )
				self._world_sounds:playSound( unit:getSounds().appeared, nil, x0, y0 )

				unit:getTraits()._appearedSoundTriggered = true
			end
		end
	end
end

function boardrig:refreshLOS( x0, y0, losCoords )
	-- Update the actual viz cells based on LOS info
	local updateCells = {}

	for i = 1, #losCoords, 2 do
		local x, y = losCoords[i], losCoords[i+1]
		local cellviz = self:getClientCellXY( x, y )
		table.insert( updateCells, cellviz )
	end

	if x0 and y0 then
		table.sort( updateCells,
			function( l, r )
				local distl = math.abs( l._x - x0 ) + math.abs( l._y - y0 )
				local distr = math.abs( r._x - x0 ) + math.abs( r._y - y0 )
				return distl < distr
			end )
	end

	local REVEAL_TIME = 30 -- 0.5 second.
	local revealStep = math.ceil( #updateCells / REVEAL_TIME )
	local updateRigs = {}
	for i, cellrig in ipairs(updateCells) do
		cellrig:refresh()		
		cellrig:addDependentRigs( updateRigs )
		for k, rig in pairs(updateRigs) do
			rig:refresh()
			updateRigs[ k ] = nil
		end

		self._decorig:refreshCell( cellrig._x, cellrig._y )


		self:checkForAppearedSounds(cellrig)

		if x0 and y0 and i % revealStep == 0 then
			coroutine.yield()
		end
	end
end

function boardrig:updateShadowMap()
	local segs = self:getSim():getLOS():getSegments()

	-- All we need to do is transform the coordinates to world-space.
	for i = 1, #segs, 2 do
		segs[i], segs[i+1] = self:cellToWorld( segs[i], segs[i+1] )
	end

	self._game.shadow_map:setSegments( segs )

	self._game.shadow_map:disableALOS( self:getLocalPlayer() == nil )
end

function boardrig:createWallRigs( )
	assert( self._wallVBO == nil )

	local st = os.clock()	
	self._wallVBO = wall_vbo.generate3DWalls( self )
	log:write( "generate3DWalls() -- took %.1f ms", (os.clock() - st) * 1000 )
	self._game.shadow_map:setWorldInfo( cdefs.BOARD_TILE_SIZE * self._boardWidth, cdefs.BOARD_TILE_SIZE * self._boardHeight )
	self:updateShadowMap()

	local simCore = self._game.simCore
	local VALID_DIRS = { simdefs.DIR_N, simdefs.DIR_E }

	-- Create viz cells such that there is an outer buffer (wall generation requires it...)
	for i, cellviz in pairs(self._cellRigs ) do
		local wallOffsets = cellviz._wallGeoInfo
		local doorOffsets = cellviz._doorGeoInfo
		local postOffsets = cellviz._postGeoInfo

		for _,dir in pairs( VALID_DIRS ) do
			if wallOffsets and wallOffsets[ dir ] then
				local wallRig = wallrig2( self, cellviz._x, cellviz._y, dir, self._wallVBO )
				table.insert( self._wallRigs, wallRig )
			end
			if doorOffsets and doorOffsets[ dir ] then
				local doorRig = doorrig2( self, cellviz._x, cellviz._y, dir, self._wallVBO )
				table.insert( self._doorRigs, doorRig )
			end
		end
		local postRig = postrig( self, cellviz._x, cellviz._y, self._wallVBO )
		if postRig:isValid() then
			table.insert( self._wallRigs, postRig )
		else
			postRig:destroy()
		end
	end
end

function boardrig:createLightRigs( levelData )
	if levelData.lights then
		for i, lightInfo in ipairs( levelData.lights ) do
			table.insert( self._lightRigs, lightrig( self, lightInfo ))
		end
	end
end

function boardrig:createUnitRig( unit )
	if ( self._unitRigs[ unit:getID() ] ) then
		return self._unitRigs[ unit:getID() ]
	end

	local sim = self._game.simCore
	local new_rig = nil

	if unit:getUnitData().rig then
		-- Allow units that specify for NO rig by using the empty string.
		if #unit:getUnitData().rig > 0 then
			local somerig = include( "gameplay/" .. unit:getUnitData().rig )
			new_rig = somerig.rig( self, unit )
		end
	elseif sim:getQuery().isAgent( unit ) then
		new_rig = agentrig.rig( self, unit )
	elseif sim:getQuery().isItem( unit ) then
		new_rig = itemrig.createItemRig( self, unit )
	end

	if new_rig then
		self._unitRigs[ unit:getID() ] = new_rig
		new_rig:refresh()
	end

	return new_rig
end

function boardrig:createCells( )
	local sim = self:getSim()
	for y=0,self._boardHeight+1 do
		for x=0,self._boardWidth+1 do
			local scell = sim:getCell( x, y )
			if scell == nil then
				for dir = 0, simdefs.DIR_MAX-1 do
					local dx, dy = simquery.getDeltaFromDirection( dir )
					scell = sim:getCell( x + dx, y + dy )
					if scell then
						break
					end
				end
			end
			if scell then
				local cellID = simquery.toCellID( x, y )
				self._cellRigs[cellID] = cellrig( self, x, y )
			end
		end
	end
end


function boardrig:createHUDProp(kanimName, symbolName, anim, layer, unitProp, x, y, facing)
	local prop, kanim = animmgr.createPropFromAnimDef( kanimName )

	prop:setCurrentSymbol(symbolName)

	if anim then	
		prop:setCurrentAnim( anim )
	end

	if unitProp then
		prop:setAttrLink( MOAIProp.INHERIT_LOC, unitProp, MOAIProp.TRANSFORM_TRAIT)
		prop:setAttrLink( MOAIProp.ATTR_VISIBLE, unitProp, MOAIProp.ATTR_VISIBLE)
	else
		if x and y then
			prop:setLoc( x, y )	
		end
	end

	animmgr.refreshIsoBounds( prop, kanim, facing )

	if (layer == true or layer == false) and unitProp then
		unitProp:insertProp( prop, layer )
	else
		layer:insertProp( prop )
	end

	return prop
end

function boardrig:hideFlags( isHidden )
	for unitID, unitRig in pairs( self._unitRigs ) do
		if unitRig.hideFlags then
			unitRig:hideFlags( isHidden )
		end
	end
end

local function handleEmittedSound( boardRig, x0, y0, range, sound, altVisTiles )
	local sim = boardRig:getSim()
	local closestUnit, closestRange = nil, math.huge

	if boardRig:getLocalPlayer() then
		closestUnit, closestRange = simquery.findClosestUnit( boardRig:getLocalPlayer():getUnits(), x0, y0, simquery.canHear )
	end

	local hasListener = closestUnit ~= nil and closestRange <= range
	local canSeeSource = boardRig:canPlayerSee( x0, y0 ) 
	--altVisTiles is for doors.. the sound might originate from an unseen tile even though the door can be seen.
	if altVisTiles and not canSeeSource then
		for i,tile in ipairs(altVisTiles) do
			if boardRig:canPlayerSee( tile.x, tile.y ) then
				canSeeSource = true
				break
			end
		end
	end

	-- sound and listener, play the audio
	if sound and (hasListener or canSeeSource) then
		boardRig._world_sounds:playSound( sound, nil, x0, y0 )
	end

	-- listener or player's unit, show rings
	if range > 0 then
		boardRig._world_sounds:playRattles( x0, y0, range )

		if  hasListener or canSeeSource then  --boardRig:getSim():getCurrentPlayer() == boardRig._game:getLocalPlayer() or
			boardRig._game.viz:spawnViz( function() boardRig:displaySoundRing( x0, y0, range ) end ):unblock()
		end
	end
end


local function handleSpeechEvent( self, unit, speech )
		
	if unit:isValid() and speech then
		local x0,y0 = unit:getLocation()
		if unit:getTraits().voice then
			speech = string.gsub(speech, "<voice>", unit:getTraits().voice)
		end
		MOAIFmodDesigner.playSound( speech, nil, nil, {x0,y0, 0}, nil )
	end	
	
end

function boardrig:showFloatText( x0, y0, txt, color, sound )
	if config.RECORD_MODE then
		return
	end

	local x1, y1 = self:cellToWorld( x0, y0 )	

	if self:canPlayerSee( math.floor(x0 + 0.5), math.floor(y0 + 0.5) ) then	
		local fxmgr = self._game.fxmgr
		fxmgr:addFloatLabel( x1, y1, txt, 3, color, 0, nil)				                     
	end
end

function boardrig:showFloatTextCPU( x0, y0, x1, y1, txt, color )
	local x2, y2 = self:cellToWorld( x0, y0 )	
	local fxmgr = self._game.fxmgr
	fxmgr:addFloatLabelToPoint( x2, y2, x1, y1, txt, 3, color, 0)				                     
end

-----------------------------------------------------
-- Interface functions

function boardrig:getLayer( name )
	if name ~= nil then
		return self._layers[name] or self._game.backgroundLayers[name]
	else
		return self._layer
	end
end
		
function boardrig:getLayers( )
	return self._layers
end

function boardrig:getSim( )
	return self._game.simCore
end

function boardrig:getWorldSize( )
	return self._boardWidth * cdefs.BOARD_TILE_SIZE, self._boardHeight * cdefs.BOARD_TILE_SIZE
end

function boardrig:worldToCell( x, y )
				
	x, y = self._grid:worldToModel( x, y )

	x = math.floor(x / cdefs.BOARD_TILE_SIZE) + 1
	y = math.floor(y / cdefs.BOARD_TILE_SIZE) + 1

	if x > 0 and y > 0 and x <= self._boardWidth and y <= self._boardHeight then
		return x, y
	end
end

function boardrig:worldToSubCell( x, y )
				
	x, y = self._grid:worldToModel( x, y )

	x = x / cdefs.BOARD_TILE_SIZE + 1
	y = y / cdefs.BOARD_TILE_SIZE + 1

	return x, y
end

function boardrig:cellToWorld( cellx, celly )
	
	local x = cellx * cdefs.BOARD_TILE_SIZE - 0.5 * cdefs.BOARD_TILE_SIZE
	local y = celly * cdefs.BOARD_TILE_SIZE - 0.5 * cdefs.BOARD_TILE_SIZE

	x, y = self._grid:modelToWorld( x, y )

	return x, y
end

function boardrig:cellToWnd( cellx, celly )
	local world_x, world_y = self:cellToWorld( cellx, celly )
	local wnd_x, wnd_y = self._layer:worldToWnd( world_x, world_y, 0 )
	return wnd_x, wnd_y
end

function boardrig:cellToWorldDistance( dist )
	local x0, y0 = self:cellToWorld( 0, 0 )
	local x1, y1 = self:cellToWorld( dist, 0 )
	return mathutil.dist2d( x0, x0, x1, y1 )
end

function boardrig:generateTooltip( debugMode, cellx, celly )	
	local tooltip = ""
	local cell = cellx and celly and self:getLastKnownCell( cellx, celly )
	if cell then
		for i,unit in ipairs(cell.units) do
			local unitRig = self._unitRigs[ unit:getID() ]
			if unitRig and unitRig.generateTooltip then
				tooltip = tooltip .. unitRig:generateTooltip( debugMode ) .. "\n"
			end
		end
	end

	return tooltip
end

function boardrig:getClientCellXY( x, y )
	if x and y then
		local cellID = simquery.toCellID( x, y )
		return self._cellRigs[ cellID ]
	end
end
	
function boardrig:getClientCell( cell )
	if cell then
		return self:getClientCellXY( cell.x, cell.y )
	end
end

function boardrig:canPlayerHear( x, y, range )
	local localPlayer = self._game:getLocalPlayer()
	if not localPlayer then
		return true -- Spectator
	else
		local closestUnit, closestRange = simquery.findClosestUnit( self:getLocalPlayer():getUnits(), x, y, simquery.canHear )
		return closestUnit and closestRange <= range
	end
end

function boardrig:canPlayerSee( x, y )
	local localPlayer = self:getLocalPlayer()
	if not localPlayer then
		return true -- Spectator
	else
		return self:getSim():canPlayerSee( localPlayer, x, y )
	end
end

function boardrig:canPlayerSeeUnit( unit )
	local localPlayer = self:getLocalPlayer()
	if not localPlayer then
		return true -- Spectator
	else
		return self:getSim():canPlayerSeeUnit( localPlayer, unit )
	end
end

function boardrig:chainCells( cells, clr, duration, dashed )
	local id = self._chainCellID or 1
	self._chainCellID = id + 1

	local localPlayer = self:getLocalPlayer()
	local dotTex, lineTex = resources.find( "dot" ), resources.find( "line" )

	if dashed then
		lineTex = resources.find( "line_dashed" )		
	end

	local props = {}
	local defaultColor = util.color.fromBytes( 140, 255, 255 )

	for i,cell in ipairs(cells) do
		local x,y = self:cellToWorld( cell.x, cell.y )
		local ncell = cells[i+1]
		
		local prop = MOAIProp2D.new ()
		prop:setDeck ( dotTex )
		prop:setLoc( x, y )
		
		if clr then
			prop:setColor(clr.r,clr.g,clr.b,clr.a)
		else
			local isWatched = localPlayer and simquery.isCellWatched( self:getSim(), localPlayer, cell.x, cell.y )
			if isWatched == simdefs.CELL_WATCHED then
				prop:setColor( cdefs.COLOR_WATCHED:unpack() )
			elseif isWatched == simdefs.CELL_NOTICED then
				prop:setColor( cdefs.COLOR_NOTICED:unpack() )
			else
				prop:setColor(defaultColor.r,defaultColor.g,defaultColor.b,defaultColor.a)
			end
		end

		table.insert(props, 1, prop)

		if ncell then
			local nx,ny = self:cellToWorld( ncell.x, ncell.y )
			local dx,dy = ncell.x-cell.x, ncell.y-cell.y

			local theta = math.atan2(dy,dx)
			local scale = math.sqrt( 2*dx*dx + 2*dy*dy)

			local prop = MOAIProp2D.new ()
			prop:setRot( math.deg(theta) )
			prop:setScl( scale, 1 )
			prop:setDeck ( lineTex )
			prop:setLoc( (x+nx)/2, (y+ny)/2 )
			if clr then
				prop:setColor(clr.r,clr.g,clr.b,clr.a)
			else
				local isWatched = localPlayer and simquery.isCellWatched( self:getSim(), localPlayer, ncell.x, ncell.y )
				if isWatched == simdefs.CELL_WATCHED then
					prop:setColor( cdefs.COLOR_WATCHED:unpack() )
				elseif isWatched == simdefs.CELL_NOTICED then
					prop:setColor( cdefs.COLOR_NOTICED:unpack() )
				else
					prop:setColor(defaultColor.r,defaultColor.g,defaultColor.b,defaultColor.a)
				end
			end

			table.insert(props, 1, prop)			
		end
	end

	local layer = self._layers["floor"]
	for _,prop in ipairs(props) do
		layer:insertProp(prop)
	end

	self._chainCells[ id ] = {props=props,duration=duration}

	return id
end
function boardrig:unchainCells( chain_id )
	local chain = self._chainCells[ chain_id ]
	if chain then
		self._chainCells[ chain_id ] = nil
		for _,prop in pairs( chain.props ) do
			self._layers["floor"]:removeProp ( prop )
		end
	end
end

function boardrig:hiliteCells( cells, clr, duration )
	return self._zoneRig:hiliteCells( cells, clr, duration )	
end

function boardrig:unhiliteCells( hiliteID )
	if hiliteID then
		self._zoneRig:unhiliteCells( hiliteID )
	end
end

function boardrig:selectUnit( unit )
	if unit ~= self.selectedUnit then
		if self.selectedUnit and self.selectedUnit:isValid() then
			local unitRig = self:getUnitRig( self.selectedUnit:getID() )
			if unitRig.selectedToggle then
				unitRig:selectedToggle( false )
			end
		end
		if unit and unit:isValid() and unit:getTraits().isAgent then	
			local unitRig = self:getUnitRig( unit:getID() )
			if unitRig.selectedToggle then
				unitRig:selectedToggle( true )
			end
		end
	end
	self.selectedUnit = unit
end

function boardrig:refreshFlags( cell )
	if cell then
		for i, cellUnit in ipairs( cell.units ) do
            local rig = self:getUnitRig( cellUnit:getID() )
            if rig and rig.refreshHUD then
                rig:refreshHUD( cellUnit )
            end
		end
	end
end

function boardrig:getSelectedUnit()
	return self.selectedUnit
end

function boardrig:getForeignPlayer( )
	return self._game:getForeignPlayer()
end

function boardrig:getLocalPlayer( )
	return self._game:getLocalPlayer()
end

function boardrig:getTeamColour( player )
	return self._game:getTeamColour( player )
end

function boardrig:getLastKnownCell( x, y )
	local localPlayer = self._game:getLocalPlayer()
	if localPlayer == nil then
		-- If there is no local player, just reveal everything (ie. the raw sim data)
		return self._game.simCore:getCell( x, y )
	else
		return localPlayer:getLastKnownCell( self._game.simCore, x, y )
	end
end

function boardrig:getLastKnownUnit( unitID )
	local localPlayer = self._game:getLocalPlayer()
	if localPlayer == nil then
		-- If there is no local player, just reveal everything (ie. the raw sim data)
		return self._game.simCore:getUnit( unitID )
	else
		return localPlayer:getLastKnownUnit( self._game.simCore, unitID )
	end
end

function boardrig:onTooltipCell( cellx, celly, oldx, oldy )
	local localPlayer = self._game:getLocalPlayer()
	if localPlayer then
		local oldcell = oldx and localPlayer:getCell( oldx, oldy )
		if oldcell then
			for i, unit in ipairs(oldcell.units) do
				local unitRig = self:getUnitRig( unit:getID() )
				if unitRig and unitRig.stopTooltip then
					unitRig:stopTooltip()
				end
			end
		end

		local cell = cellx and localPlayer:getCell( cellx, celly )
		if cell then
			for i, unit in ipairs(cell.units) do
				local unitRig = self:getUnitRig( unit:getID() )
				if unitRig and unitRig.startTooltip then
					unitRig:startTooltip()
				end
			end
		end
	end

	self._coverRig:refresh( cellx, celly )
	self._coverRig:setLocation( cellx, celly )
end

function boardrig:cameraFit( ... )
	self._game:getCamera():fitOnscreen( ... )
end

function boardrig:cameraLock( prop )
	self._game:getCamera():lockTo( prop )
end

function boardrig:cameraCentre()
	local units
	if self:getLocalPlayer() then
		units = self:getLocalPlayer():getUnits()
	else
		units = self._game.simCore:getAllUnits()
	end

	local cx, cy = simquery.calculateCentroid( self._game.simCore, units )
	if cx and cy then
		self._game:getCamera():zoomTo( 0.4 )
		self._game:cameraPanToCell( cx, cy )	
		KLEIRenderScene:pulseUIFuzz( 0.3 )
	end
end

function boardrig:wait( frames )
	while frames > 0 do
		frames = frames - 1
		coroutine.yield()
	end
end

function boardrig:onSimEvent( ev, eventType, eventData )

	local simdefs = self._game.simCore:getDefs()

	if eventType == simdefs.EV_UNIT_SPAWNED then
		assert( self._unitRigs[ eventData.unit:getID() ] == nil )

	elseif eventType == simdefs.EV_START then
		self:cameraCentre()

	elseif eventType == simdefs.EV_UNIT_DESPAWNED then
		local unitRig = self:getUnitRig(  eventData.unitID )
		if unitRig then
			unitRig:refresh()
		end	

	elseif eventType == simdefs.EV_UNIT_REFRESH or
		   eventType == simdefs.EV_UNIT_CAPTURE or
		   eventType == simdefs.EV_UNIT_DEACTIVATE or
		   eventType == simdefs.EV_UNIT_LOOKAROUND or
		   eventType == simdefs.EV_UNIT_SHOW_LABLE or
		   eventType == simdefs.EV_UNIT_KO or
		   eventType == simdefs.EV_UNIT_RESET_ANIM_PLAYBACK or
		   eventType == simdefs.EV_UNIT_MELEE or
		   eventType == simdefs.EV_UNIT_DRAG_BODY or
		   eventType == simdefs.EV_UNIT_DROP_BODY or
		   eventType == simdefs.EV_UNIT_BODYDROPPED or
		   eventType == simdefs.EV_UNIT_ADD_INTEREST or
		   eventType == simdefs.EV_UNIT_DEL_INTEREST or
		   eventType == simdefs.EV_UNIT_UPDATE_INTEREST or
		   eventType == simdefs.EV_UNIT_DONESEARCHING or
		   eventType == simdefs.EV_UNIT_TURN or	
		   eventType == simdefs.EV_UNIT_HIT_SHIELD or	   
		   eventType == simdefs.EV_UNIT_PSIFX or
		   eventType == simdefs.EV_UNIT_INSTALL_AUGMENT or
		   eventType == simdefs.EV_UNIT_HEAL or
		   eventType == simdefs.EV_UNIT_PLAY_ANIM or		   
		   eventType == simdefs.EV_UNIT_UNTIE then

		local passthru = true 
		   
		if eventData.unit:isValid() then
			local unitRig = self:getUnitRig(  eventData.unit:getID() )
			if unitRig then
				unitRig:onSimEvent( ev, eventType, eventData )		
			end
		end

	elseif eventType == simdefs.EV_UNIT_SPEAK then		
		local x0, y0 = eventData.unit:getLocation()
		if self:canPlayerSee( x0, y0 ) then
			handleSpeechEvent( self, eventData.unit, eventData.speech )
		else
			local closestUnit, closestRange = simquery.findClosestUnit( self:getLocalPlayer():getUnits(), x0, y0, simquery.canHear )
			if closestUnit ~= nil and closestRange <= eventData.range then
				handleSpeechEvent( self, eventData.unit, eventData.speech )
			end
		end

	elseif eventType == simdefs.EV_UNIT_ENGAGED then
		local unitRig = self:getUnitRig( eventData.unitID )
		local unit = unitRig:getUnit()
		local x0,y0 = unit:getLocation()
		MOAIFmodDesigner.playSound("SpySociety/Actions/guard/guard_alerted", nil, nil, {x0,y0,0} )
		MOAIFmodDesigner.playSound(unit:getSounds().alert, nil, nil, {x0,y0, 0} )

	elseif eventType == simdefs.EV_UNIT_UNGHOSTED then
		if self:getLocalPlayer() and eventData.seerID == self:getLocalPlayer():getID() then
			local unitRig = self:getUnitRig( eventData.unitID )
			if unitRig then
				unitRig:onSimEvent( ev, eventType, eventData )
			end
		end

	elseif eventType == simdefs.EV_UNIT_WARPED then
		local unitID = eventData.unit:getID()
		local unitRig = self:getUnitRig( unitID )
		if unitRig then
			unitRig:onSimEvent( ev, eventType, eventData )
			if simquery.canHear( eventData.unit ) and eventData.unit:getPlayerOwner() == self:getLocalPlayer() then
				self._world_sounds:refreshSounds()
			end
		end
        
        -- Refresh flags for units at the previous and current location (for pinning indicator)
        self:refreshFlags( eventData.from_cell )
        self:refreshFlags( eventData.to_cell )

	elseif eventType == simdefs.EV_UNIT_RELOADED or
		   eventType == simdefs.EV_UNIT_DEATH then

		local unitID = eventData.unit:getID()
		local unitRig = self._unitRigs[ unitID ]
		unitRig:onSimEvent( ev, eventType, eventData )

		if eventData.to_cell and unitRig.getProp and self:canPlayerSeeUnit( unitRig:getUnit() ) then
			self:cameraLock( unitRig:getProp() )
		else
			self:cameraLock( nil )
		end

	elseif eventType == simdefs.EV_UNIT_START_WALKING or
		   eventType == simdefs.EV_UNIT_STOP_WALKING then

		local unitID = eventData.unit:getID()
		local unitRig = self._unitRigs[ unitID ]
		unitRig:onSimEvent( ev, eventType, eventData )

		if self:canPlayerSeeUnit( unitRig:getUnit() ) and eventType == simdefs.EV_UNIT_START_WALKING then
			self:cameraLock( unitRig:getProp() )
		else
			self:cameraLock( nil )
		end

	elseif eventType == simdefs.EV_UNIT_OVERWATCH or eventType == simdefs.EV_UNIT_OVERWATCH_MELEE then
		self._game.hud:showMovementRange(self._game.hud:getSelectedUnit() )

		if eventData.unit:isValid() then
			local unitRig = self:getUnitRig(  eventData.unit:getID() )
			if unitRig then
				unitRig:onSimEvent( ev, eventType, eventData )		
			end
		end

	elseif eventType == simdefs.EV_UNIT_INTERRUPTED then
		local unitRig = self:getUnitRig( eventData.unitID )
		unitRig:onSimEvent( ev, eventType, eventData )

	elseif eventType == simdefs.EV_UNIT_START_SHOOTING or
		   eventType == simdefs.EV_UNIT_THROW or
		   eventType == simdefs.EV_UNIT_STOP_SHOOTING then

		local userID = eventData.unitID		
		local unitRig = self._unitRigs[ userID ]
		
		if eventType == simdefs.EV_UNIT_START_SHOOTING or
		   eventType == simdefs.EV_UNIT_THROW then
			
		
			local unit = unitRig:getUnit()
			if not unit:isGhost() then
				self._game:cameraPanToCell( unitRig:getLocation() )
				self:wait( 30 )
			end
		end

		unitRig:onSimEvent( ev, eventType, eventData )
		
		if eventType == simdefs.EV_UNIT_STOP_SHOOTING then
			local unit = unitRig:getUnit()
			if unit:isGhost() then
				self._game:cameraPanToCell( unitRig:getLocation() )
				self:wait( 60 )
			end
		end


	elseif eventType == simdefs.EV_UNIT_SHOT then
		self._unitRigs[ eventData.unitID ]:onSimEvent( ev, eventType, eventData )
		
	elseif eventType == simdefs.EV_UNIT_HIT or eventType == simdefs.EV_UNIT_BLOCKED then
		local unitRig = self:getUnitRig( eventData.unit:getID() )
		unitRig:onSimEvent( ev, eventType, eventData )		

	elseif eventType == simdefs.EV_UNIT_PEEK then
		self._unitRigs[ eventData.unitID ]:onSimEvent( ev, eventType, eventData )
		
	elseif eventType == simdefs.EV_UNIT_USEDOOR or eventType == simdefs.EV_UNIT_USEDOOR_PST then
		self._unitRigs[ eventData.unitID ]:onSimEvent( ev, eventType, eventData )

	elseif eventType == simdefs.EV_UNIT_PICKUP then
		self._unitRigs[ eventData.unitID ]:onSimEvent( ev, eventType, eventData )

	elseif eventType == simdefs.EV_UNIT_USECOMP then
		self._unitRigs[ eventData.unitID ]:onSimEvent( ev, eventType, eventData )
		
	elseif eventType == simdefs.EV_UNIT_FLOAT_TXT then
		local x0,y0 = eventData.x, eventData.y
		if eventData.unit and not x0 and not y0 then
			x0, y0 = eventData.unit:getLocation()
		end

		self:showFloatText( x0, y0, eventData.txt, eventData.color, eventData.sound , eventData.target)
		if eventData.sound then
			MOAIFmodDesigner.playSound( eventData.sound, nil, nil, {x0,y0,0}, nil )
		end

	elseif eventType == simdefs.EV_UNIT_MAINFRAME_UPDATE then	
		local zoom = self._game:getCamera():getZoom()	

		if eventData.reveal and zoom < 1 then	
			self._game:getCamera():zoomTo( 1 ) 			
		end

		local sort = {}
		for i,unitID in pairs(eventData.units) do
			local unit = self:getSim():getUnit(unitID)
			local cell = self:getSim():getCell(unit:getLocation())
			local x0,y0 =self._game:cellToWnd(cell.x,cell.y)
			table.insert(sort,{x=x0,y=y0,item=unit:getID()})
		end

		table.sort( sort, function(l,r) return l.x < r.x end )

		local sorted = {}
		for i,set in ipairs(sort) do
			table.insert(sorted,set.item)
		end
		
		for i,unitID in ipairs( sorted )do	
			self._unitRigs[ unitID ]:onSimEvent( ev, eventType, eventData )
			if #sorted > 1 then
				self:wait( 30 )
			end
		end
		if eventData.reveal then
			self._game:getCamera():zoomTo( zoom )
		end
	
	elseif eventType == simdefs.EV_UNIT_WIRELESS_SCAN then
		self._unitRigs[ eventData.unitID ]:onSimEvent( ev, eventType, eventData )				
	
	elseif eventType == simdefs.EV_UNIT_APPEARED then	
		self._unitRigs[ eventData.unitID ]:onSimEvent( ev, eventType, eventData )

	elseif eventType == simdefs.EV_SOUND_EMITTED then
		handleEmittedSound( self, eventData.x, eventData.y, eventData.range, eventData.sound, eventData.altVisTiles )
				
	elseif ev.eventType == simdefs.EV_SCANRING_VIS then
		if ev.eventData.unit == nil or (ev.eventData.unit:getPlayerOwner() == self:getSim():getCurrentPlayer() and self:getSim():getCurrentPlayer() == self:getLocalPlayer()) then
			local cells =  simquery.rasterCircle( self:getSim(), ev.eventData.x, ev.eventData.y, ev.eventData.range)
			self:hiliteCells( cells, {0.3,0.0,0.0,0.3}, 60 ) 
		end

	elseif ev.eventType == simdefs.EV_OVERLOAD_VIZ then 
		local cells = simquery.rasterCircle( self:getSim(), ev.eventData.x, ev.eventData.y, ev.eventData.range )				

		self._game:cameraPanToCell( ev.eventData.x, ev.eventData.y )
		self:hiliteCells( cells, {0.3,0.0,0.0,0.3}, 120 ) 
		self:wait( 60 )

		if ev.eventData.fx and ev.eventData.fx == "EMP" then
			handleEmittedSound( self, ev.eventData.x, ev.eventData.y, ev.eventData.range, "SpySociety/Actions/EMP_explo" )
			
			local wx, wy = self:cellToWorld( ev.eventData.x, ev.eventData.y )
			self._game.fxmgr:addAnimFx( { kanim = "fx/emp_explosion", symbol = "character", anim = "active", x = wx, y = wy, facingMask = KLEIAnim.FACING_W } )
		end

	elseif ev.eventType == simdefs.EV_PULSESCAN_VIZ then
		self._game:cameraPanToCell( ev.eventData.x, ev.eventData.y )
		for i = 1, #eventData.cells, 4 do -- step 4, to only show fx every other cell
			local wx, wy = self:cellToWorld( eventData.cells[i], eventData.cells[i+1] )
			self._game.fxmgr:addAnimFx( { kanim = "fx/psi_teleport_fx", symbol = "effect", anim = "idle", x = wx, y = wy, z = 42, layer = self._layer } )
			coroutine.yield()
		end

	elseif ev.eventType == simdefs.EV_ELECTRIC_SHOCK then
		if #eventData > 0 then
			self._game:cameraPanToCell( eventData[1].x, eventData[1].y )
		end

		for i, cell in ipairs(eventData) do
			local wx, wy = self:cellToWorld( cell.x, cell.y )
			self._game.fxmgr:addAnimFx( { kanim = "fx/door_shock_trap", symbol = "sock_trap", anim = "explode", x = wx, y = wy, facingMask = KLEIAnim.FACING_W } )
			coroutine.yield()
		end

	elseif eventType == simdefs.EV_EXIT_MODIFIED then
		if eventData then
			local doorRig = self:getDoorRig( eventData.cell, eventData.dir )
			if doorRig then
				doorRig:refresh()
			end
		else
			self:refreshDoors()
		end
		self._world_sounds:refreshSounds()
		self:updateShadowMap()

	elseif ev.eventType == simdefs.EV_UNIT_GOALS_UPDATED then
		self._pathRig:regeneratePath( eventData.unitID )

	elseif eventType == simdefs.EV_MAINFRAME_DANGER then
		local wx, wy = self:cellToWorld( eventData.x0, eventData.y0 )
		MOAIFmodDesigner.playSound( "SpySociety/Actions/mainframe_deterrent_action", nil, nil, {wx, wy,0} )
		self._game:cameraPanToCell( eventData.x0, eventData.y0 )
		self:refreshLOS( eventData.x0, eventData.y0, eventData.cells )
		self:wait( 30 )

	elseif eventType == simdefs.EV_LOS_REFRESH then
		if eventData.seer and eventData.seer:getPlayerOwner() == self:getLocalPlayer() then
			if #eventData.cells > 0 then
				local x0, y0 = eventData.seer:getLocation()
				self._game.viz:spawnViz( function() self:refreshLOS( x0, y0, eventData.cells ) end ):unblock()
				self._pathRig:refreshAllTracks()
			end

		elseif eventData.seer and eventData.seer:getPlayerOwner() ~= self:getLocalPlayer() then			
			self:refreshLOS( nil, nil, eventData.oldcells )
			self:refreshLOS( nil, nil, eventData.newcells )
		
		elseif (eventData.player and eventData.player == self:getLocalPlayer()) or eventData.player == nil then
			self:refreshLOS( nil, nil, eventData.newcells )
		end

		if eventData.seer then
			self:refreshLOSCaster( eventData.seer:getID() )
		end

	elseif eventType == simdefs.EV_HUD_REFRESH then
		self:refreshUnits()

	elseif eventType == simdefs.EV_WALL_REFRESH then
		self:refreshWalls()

	elseif eventType == simdefs.EV_TURN_END then		
		
		self:refreshUnits( )
		self._pathRig:refreshAllTracks()
	end
end

function boardrig:getSounds()
	return self._world_sounds
end

function boardrig:startSpotSounds( )
	assert( self._levelData.sounds )
	for i = 1, #self._levelData.sounds do
		local sound = self._levelData.sounds[i]
		if not sound.rattleRange then
			self._world_sounds:playSound( "SpySociety/"..sound.name, string.format("spot-%d", i ), sound.x, sound.y )
		end
	end
end

function boardrig:destroy( )
	self._world_sounds:destroy()

	self._layers["floor"]:removeProp( self._grid )
	self._layers["floor"]:removeProp( self._dangerGrid )

	self._overlayRigs:destroy()
	self._overlayRigs = nil

	self._coverRig:destroy()
	self._coverRig = nil

	self._zoneRig:destroy()
	self._zoneRig = nil

	self._pathRig:destroy()
	self._pathRig = nil

	self._backgroundFX:destroy()

	while #self._dynamicRigs > 0 do
		table.remove( self._dynamicRigs ):destroy()
	end

	for id, cellRig in pairs(self._cellRigs) do
		cellRig:destroy()
	end
	self._cellRigs = nil

	for unitID,unitRig in pairs(self._unitRigs) do
		unitRig:destroy()
	end
	self._unitRigs = nil

	for i,wallRig in ipairs(self._wallRigs) do
		wallRig:destroy()
	end
	self._wallRigs = nil
	
	for i,doorRig in ipairs(self._doorRigs) do
		doorRig:destroy()
	end
	self._doorRigs = nil

	self._decorig:destroy()
	self._decorig = nil

	for i,lightRig in ipairs(self._lightRigs) do
		lightRig:destroy()
	end
	self._lightRigs = nil

	util.fullGC()
end

function boardrig:onUpdate()
	local frames = MOAISim.getElapsedFrames()
	local idx = math.floor( frames / 60 ) % #cdefs.DANGERTILES_PARAMS.files
	self._dangerDeck:setTexture( cdefs.DANGERTILES_PARAMS.files[ idx + 1 ] )
	
	for i = #self._dynamicRigs,1,-1 do
		local dynamicRig = self._dynamicRigs[i]

		if not dynamicRig:onFrameUpdate() then
			dynamicRig:destroy()
			table.remove( self._dynamicRigs, i )
		end
	end

	self._backgroundFX:update()
end

function boardrig:onStartTurn( isPC )
	self._game.boardRig._backgroundFX:transitionColor( isPC, 60 )
end

function boardrig:spawnScanLine( start_points, end_points )
	local scanLineRig = scan_line_rig( self, start_points, end_points, 2, {255/255, 0/255, 0/255, 0.25} )
	
	table.insert( self._dynamicRigs, scanLineRig )
end

function boardrig:refresh( )
	local gfxOptions = self._game:getGfxOptions()
	if gfxOptions.bMainframeMode then
		self._grid:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.FLOOR_SHADER ) )
	else
		self._grid:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.FLOOR_SHADOW_SHADER ) )
	end

	self._world_sounds:refreshSounds()
	self:updateShadowMap()

	self:refreshBackgroundFX()
	self:refreshUnits( )
	self:refreshCells( )
	self:refreshDecor( )
	self._pathRig:refreshAllTracks()
end

function boardrig:setFocusCell( x, y )
	self._decorig:setFocusCell( x, y )
end

function boardrig:clearMovementTiles( )
	self._zoneRig:clearMovementTiles( )
end

function boardrig:setMovementTiles( tiles, grad, line )
	self._zoneRig:setMovementTiles( tiles, grad, line )
end

function boardrig:getPathRig()
	return self._pathRig
end

-----------------------------------------------------
-- create the boardRig

function createGridProp( game, simCore, params )
	local boardWidth, boardHeight = simCore:getBoardSize()

	local grid = MOAIGrid.new ()
	grid:initRectGrid ( boardWidth, boardHeight, cdefs.BOARD_TILE_SIZE, cdefs.BOARD_TILE_SIZE )

	local tileDeck = MOAITileDeck2D.new ()
	local prop = MOAIProp2D.new ()

	if params.file then
		local mt = MOAIMultiTexture.new()
		mt:reserve( 4 )
		mt:setTexture( 1, params.file )
		mt:setTexture( 2, game.shadow_map )
		mt:setTexture( 3, "data/images/los_full.png" )
		mt:setTexture( 4, "data/images/los_partial.png" )

		tileDeck:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.FLOOR_SHADER ) )
		tileDeck:setTexture ( mt )

	end
	tileDeck:setSize ( unpack(params) )
	tileDeck:setRect( -0.5, -0.5, 0.5, 0.5 )
	tileDeck:setUVRect( -0.5, -0.5, 0.5, 0.5 )

	
	prop:setDeck ( tileDeck )
	prop:setGrid ( grid )
	prop:setLoc( -boardWidth * cdefs.BOARD_TILE_SIZE / 2, -boardHeight * cdefs.BOARD_TILE_SIZE / 2)
	prop:setPriority( cdefs.BOARD_PRIORITY )
	prop:setDepthTest( MOAIProp.DEPTH_TEST_LESS )

	prop:forceUpdate ()
	return prop, tileDeck
end

function boardrig:init( layers, levelData, game )
	local layer = layers["main"]   
	local simCore = game.simCore
	local boardWidth, boardHeight = simCore:getBoardSize()

	local sx,sy = 1.0 / (boardWidth * cdefs.BOARD_TILE_SIZE), 1.0 / (boardHeight * cdefs.BOARD_TILE_SIZE)
	local dx,dy = 0.5, 0.5
	MOAIGfxDevice.setShadowTransform( sx, sy, dx, dy )
	
	local grid = createGridProp( game, simCore, cdefs.LEVELTILES_PARAMS )
	layers["floor"]:insertProp ( grid )

	local dangerGrid, dangerDeck = createGridProp( game, simCore, cdefs.DANGERTILES_PARAMS )
	layers["floor"]:insertProp( dangerGrid )

	levelData = levelData:parseViz()

	self.BOARD_TILE_SIZE = cdefs.BOARD_TILE_SIZE
	self._levelData = levelData
	self._layers = layers
	self._layer = layer
	self._grid = grid
	self._dangerGrid = dangerGrid
	self._dangerDeck = dangerDeck
	self._game = game
	self._orientation = game:getCamera():getOrientation()
	self._zoneRig = nil
	self._unitRigs = {}
	self._wallRigs = {}
	self._doorRigs = {}
	self._lightRigs = {}
	self._cellRigs = {}
	self._chainCells = {}
	self._boardWidth = boardWidth
	self._boardHeight = boardHeight

	self._dynamicRigs = {}
			

	self:createCells( )
	self:createWallRigs( )	

	self._zoneRig = zonerig( layers["floor"], self )
	self._coverRig = coverrig.rig( self, layers["ceiling"] )
	self._pathRig = pathrig.rig( self, layers["floor"] )

	self:createLightRigs( levelData )

	self._decorig = decorig( self, levelData, game.params )

	self._overlayRigs = overlayrigs( self, levelData )

	self._world_sounds = world_sounds( self )

	self._backgroundFX = fxbackgroundrig( self )

	-- Create rigs for pre-spawned units
	-- NOTE: the only reason we need to add this here is because there are
	-- units prespawned in sim:init(), before the rigs/viz is created, and therefore
	-- we cannot handle events as normal to initialize these guys.
	for unitID, unit in pairs(simCore:getAllUnits()) do
		local unitRig = self:createUnitRig( unit )
	end
	
	-- Initialize board rig
	self:refresh()	

end

return boardrig
