----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "modules/util" )
local cdefs = include( "client_defs" )
local color = include( "modules/color" )
local resources = include( "resources" )
local mathutil = include( "modules/mathutil" )
local level = include( "sim/level" )

local PATH_COLOR = color( 1, 1, 1, 1 ) --color( 1, .1, .1, 1 )
local TRACKS_COLOR = color( 1, 1, .2, 1 )

local function refreshLineProp( boardRig, x0, y0, x1, y1, prop, clr )
	local x, y = boardRig:cellToWorld( x0, y0 )
	local nx,ny = boardRig:cellToWorld( x1, y1 )
	local dx,dy = x1 - x0, y1 - y0
	local theta = math.atan2(dy,dx)
	local scale = math.sqrt( 2*dx*dx + 2*dy*dy)

	prop:setRot( math.deg(theta) )
	prop:setScl( scale, 1 )
	prop:setLoc( (x+nx)/2, (y+ny)/2 )
	prop:setColor( clr:unpack() )
end

local function getTrackProp( pathrig )
	local prop = table.remove( pathrig._propPool )
	if prop == nil then
		prop = MOAIProp2D.new()
		prop:setDeck( resources.find( "Footprint" ) )
		prop:setColor( 1, 1, 0, 1 )
	end

	pathrig._layer:insertProp( prop )

	return prop
end

---------------------------------------------------------------

local pathrig = class()

function pathrig:init( boardRig, layer )
	self._boardRig = boardRig
	self._layer = layer
	self._tracks = {} -- Table of unitID -> track props
	self._plannedPaths = {}
	self._plannedPathProps = {} -- Table of unitID -> path props
	self._propPool = {}
end

function pathrig:freeTracks( props )
	for i, trackProp in ipairs( props ) do
		self._layer:removeProp( trackProp )
		table.insert( self._propPool, trackProp )
	end
end

function pathrig:regeneratePath( unitID )

	local sim = self._boardRig:getSim()
	local simquery = sim:getQuery()
	local unit = sim:getUnit( unitID )

	local st = os.clock()

	if not unit:isValid() or not unit:getPather() or not unit:getBrain():getDestination() or unit:getTraits().cloaked or unit:getBrain():getDestination().unit or (not unit:getTraits().patrolObserved and not unit:getTraits().tagged )then
		self._plannedPaths[ unitID ] = nil
	else
		local plannedPath = {}
		local movePoints = unit:getTraits().mpMax
		local path = unit:getPather():getPath(unit)
		if path and path.path then
			table.insert( plannedPath, {x=path.path.startNode.location.x, y=path.path.startNode.location.y, alwaysSeen = true } )
			for i = 1, #path.path:getNodes() do
				local prevPathNode = plannedPath[#plannedPath]
				local node = path.path:getNodes()[i]
				if movePoints and node and prevPathNode then
					local moveCost = simquery.getMoveCost(prevPathNode, node.location)
					movePoints = movePoints - moveCost
					if movePoints < 0 then
						break	--that's all the path we have movement for
					end
				end
				table.insert( plannedPath, { x = node.location.x, y = node.location.y, alwaysSeen = true } )
			end
		end
		self._plannedPaths[ unitID ] = plannedPath
	end
	-- Refresh props
	self:refreshPlannedPath( unitID )
end

function pathrig:refreshPlannedPath( unitID )
	self._plannedPathProps[ unitID ] = self._plannedPathProps[ unitID ] or {}

	self:refreshProps( self._plannedPaths[ unitID ], self._plannedPathProps[ unitID ], PATH_COLOR )
end

function pathrig:refreshTracks( unitID )
	if config.NO_AI_TRACKS then
		return
	end

	local localPlayer = self._boardRig:getLocalPlayer()
	local tracks = localPlayer ~= nil and localPlayer:getTracks( unitID )

	if tracks or self._tracks[ unitID ] then
		self._tracks[ unitID ] = self._tracks[ unitID ] or {}
		self:refreshProps( tracks, self._tracks[ unitID ], TRACKS_COLOR )
	end
end


function pathrig:refreshProps( cells, props, clr )
	-- Update extant tracks
	local localPlayer = self._boardRig:getLocalPlayer()
	local j = 1
	if cells then
		for i = 2, #cells do
			local prevCell, cell = cells[i-1], cells[i]
			local isSeen
			if cell.alwaysSeen then
				-- Show track as long as long as the cell isn't blacked out
				isSeen = localPlayer == nil or localPlayer:getCell( cell.x, cell.y ) ~= nil
			else
				-- Show track only if currently seen or previously seen/heard
				isSeen = cell.isSeen or cell.isHeard or self._boardRig:canPlayerSee( cell.x, cell.y ) 
			end
			if isSeen then
				if self._boardRig._game.hud then
					self._boardRig._game:dispatchScriptEvent( level.EV_HUD_SHOW_PATH )	
				end
				props[j] = props[j] or getTrackProp( self )
				refreshLineProp( self._boardRig, prevCell.x, prevCell.y, cell.x, cell.y, props[j], clr )
				j = j + 1
			end
		end
	end

	-- Free the unused props.
	while j <= #props and #props > 0 do
		local prop = table.remove( props )
		self._layer:removeProp( prop )
		table.insert( self._propPool, prop )
	end
end

function pathrig:refreshAllTracks( )
	local localPlayer = self._boardRig:getLocalPlayer() or self._boardRig:getSim():getPC()
	for unitID, track in ipairs( localPlayer:getTracks() ) do
		if self._tracks[ unitID ] == nil then
			self._tracks[ unitID ] = {}
		end
	end

	for unitID, trackProps in pairs( self._tracks ) do
		self:refreshTracks( unitID )
	end

	for unitID, pathProps in pairs( self._plannedPaths ) do
		self:refreshPlannedPath( unitID )
	end

end

function pathrig:destroy()
	for unitID, trackProps in pairs( self._tracks ) do
		self:freeTracks( trackProps )
	end
	for unitID, pathProps in pairs( self._plannedPathProps ) do
		self:freeTracks( pathProps )
	end

	self._tracks = nil
	self._plannedPathProps = nil
	self._trackPool = nil
end


-----------------------------------------------------
-- Interface functions

return
{
	rig = pathrig
}
