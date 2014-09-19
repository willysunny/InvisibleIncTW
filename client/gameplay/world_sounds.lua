----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local array = include( "modules/array" )
local mathutil = include( "modules/mathutil" )
local astar = include( "modules/astar" )
local util = include( "client_util" )
local simquery = include( "sim/simquery" )
local simdefs = include( "sim/simdefs" )
local astar_handlers = include( "sim/astar_handlers" )

---------------------------------------------------------------------------
-- Calculates occlusion parameters for a sound.

local function calculateOcclusion( boardRig, x0, y0 )
	if not config.SOUND_OCCLUSION then
		return nil
	end

	local player = boardRig:getLocalPlayer()
	if player == nil then
		return 0
	end

	local stime = os.clock()

	local MAX_HEARD_DIST = 20
	local sim = boardRig:getSim()
	local st = sim:getCell( x0, y0 )
	local punits = {}

	for i, unit in pairs( player:getUnits() ) do
		if simquery.isAgent( unit ) and unit:getLocation() and not unit:isKO() then
			table.insert( punits, unit )
		end
	end

	table.sort( punits, function( u1, u2 ) return mathutil.distSqr2d( st.x, st.y, u1:getLocation() ) <
												  mathutil.distSqr2d( st.x, st.y, u2:getLocation() ) end )

	local handler = astar_handlers.sound_handler:new( sim, MAX_HEARD_DIST )
	local pather = astar.AStar:new( handler )
	local minHeard = MAX_HEARD_DIST
	for i, unit in ipairs( punits ) do
		local ft = sim:getCell( unit:getLocation() )
		if ft == st then
			minHeard = 0
			break
		else
			handler:setMaxDist( minHeard )
			local path = pather:findPath( st, ft )
			if path and path:getTotalMoveCost() < minHeard then
				minHeard = path:getTotalMoveCost()
			end
		end
	end

	--print( "OCCLUSION: ", minHeard / MAX_HEARD_DIST, "TOOK:", (os.clock() - stime) * 1000 )
	return minHeard / MAX_HEARD_DIST
end

---------------------------------------------------------------------------
-- Manages persistent in-world sounds.  These sounds have their occlusion
-- parameters updated according to the local player.

local world_sounds = class()

function world_sounds:init( boardRig )
	self._boardRig = boardRig
	self._sounds = {}
end

function world_sounds:destroy()
	while #self._sounds > 0 do
		MOAIFmodDesigner.stopSound( table.remove( self._sounds ).alias )
	end
end

function world_sounds:refreshSounds()
	-- Refresh sound parameters for all sounds.
	for i, sound in ipairs( self._sounds ) do
		local occlusion = calculateOcclusion( self._boardRig, sound.x, sound.y )
		MOAIFmodDesigner.setSoundProperties( sound.alias, nil, nil, occlusion )
		--log:write("REFRESH SOUND: '%s' (%d, %d); OCCLUSION: %.2f", sound.alias, sound.x, sound.y, occlusion )
	end
end

-- Track an in-world sound.
function world_sounds:playSound( soundPath, soundAlias, x0, y0 )
	local occlusion = calculateOcclusion( self._boardRig, x0, y0 )
	MOAIFmodDesigner.playSound( soundPath, soundAlias, nil, { x0, y0, 0 }, occlusion )
	--log:write("WORLD SOUND: '%s' (%d, %d); OCCLUSION: %.2f", soundPath, x0, y0, occlusion )

	if soundAlias then
		table.insert( self._sounds, { alias = soundAlias, x = x0, y = y0 } )
	end
end

-- Plays the nearest rattle sound within range of <x0, y0>
function world_sounds:playRattles( x0, y0, range )
	-- Find nearby rattle sounds.
	if self._boardRig._levelData.sounds then
		local closestRattle, closestRange = nil, range * range
		for i, sound in ipairs(self._boardRig._levelData.sounds) do
			local dist = mathutil.distSqr2d( sound.x, sound.y, x0, y0 )
			if dist < closestRange and dist < (sound.rattleRange or 0) * (sound.rattleRange or 0) then
				closestRattle, closestRange = sound, dist
			end
		end
		if closestRattle then
			--log:write( "RATTLE SOUND: <%s, %d, %d> due to <%d, %d>", closestRattle.name, closestRattle.x, closestRattle.y, x0, y0 )
			self:playSound( closestRattle.name, nil, closestRattle.x, closestRattle.y )
		end
	end
end

-- Stop a previously played sound
function world_sounds:stopSound( soundAlias )
	MOAIFmodDesigner.stopSound( soundAlias )

	for i, sound in ipairs( self._sounds ) do
		if sound.alias == soundAlias then
			table.remove( self._sounds, i )
			break
		end
	end
end

-- Dynamically update a sound position
function world_sounds:updateSound( soundAlias, x0, y0 )
	for i, sound in ipairs( self._sounds ) do
		if sound.alias == soundAlias then
			if sound.x ~= x0 or sound.y ~= y0 then
				sound.x, sound.y = x0, y0
				local occlusion = calculateOcclusion( self._boardRig, x0, y0 )
				MOAIFmodDesigner.setSoundProperties( soundAlias,nil,{sound.x,sound.y,0}, occlusion )
				--log:write("UPDATE SOUND: '%s' (%d, %d); OCCLUDE: %.2f", sound.alias, sound.x, sound.y, occlusion )
			end
			break
		end
	end
end

return world_sounds
