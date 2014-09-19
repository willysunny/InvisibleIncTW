----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources" )
local array = include( "modules/array" )
local util = include( "modules/util" )
local cdefs = include( "client_defs" )
local animmgr = include( "anim-manager" )
local binops = include( "modules/binary_ops" )
local simdefs = include( "sim/simdefs" )
local simquery = include( "sim/simquery" )
local walltypes = include( "sim/walltypes" )

local cell_rig = class( )

function cell_rig:init( boardRig, x, y )
	local game = boardRig._game
	local layer = boardRig:getLayer("floor")
	local cell = game.simCore:getCell( x, y )

	self._boardRig = boardRig
	self._layer = layer
	self._game = game
	self._x, self._y = x, y
	self._dependentRigs = {} -- the wall, post, and door rigs inside this cell
	self._obstruction_values = {}

	if cell == nil then
		self._sides = {}
		for _, dir in ipairs( simdefs.DIR_SIDES ) do
			local dx, dy = simquery.getDeltaFromDirection( dir )
			local acell = game.simCore:getCell( x + dx, y + dy )
			local rdir = simquery.getReverseDirection( dir )
			if acell then
				self._sides[ dir ] = acell.sides[ rdir ]
			end
		end
	else
		self._sides = cell.sides
	end

	self.tileIndex = cell and cell.tileIndex

	if cell and ((cell.exitID ~= nil and cell.exitID ~= simdefs.EXITID_VENT) or cell.ventID ~= nil) then

		self._exitProp = self._boardRig:createHUDProp("kanim_exit_arrow", "character", "idle", self._boardRig:getLayer(), nil, self._x, self._y )

		self._dir = 0		
		local walls = {}


		if not cell.exits[0] then
			table.insert(walls,4)
		end
		if not cell.exits[2] then
			table.insert(walls,6)
		end
		if not cell.exits[4] then
			table.insert(walls,0)
		end
		if not cell.exits[6] then
			table.insert(walls,2)
		end

		if #walls == 1 then
			self._dir = walls[1]				
		elseif #walls == 2 then
			local cell2 = cell.exits[walls[1]].cell
			local exit2 = cell2.exits[walls[1]]

			local cell3 = cell.exits[walls[2]].cell
			local exit3 = cell2.exits[walls[2]]			

			if not exit2 then
				self._dir = walls[1]
			else
				self._dir = walls[2]
			end
		end


		local orientation = self._boardRig._game:getCamera():getOrientation()
		self._exitProp:setCurrentFacingMask( 2^((self._dir - orientation*2) % simdefs.DIR_MAX) )

		if cell.ventID then
			self._exitProp:setDebugName("VENT"..tostring(x)..","..tostring(y))
			self._exitProp:setDeck( resources.find( "VentSquare" ) )
		else
			self._exitProp:setDebugName("EXIT"..tostring(x)..","..tostring(y))
			self._exitProp:setDeck( resources.find( "ExitSquare" ) )
		end
		self._exitProp:setLoc( self._boardRig:cellToWorld( x, y ) )
		self._exitProp:setVisible( false )

	end	
end


function cell_rig:destroy( )
	if self._deployProp then
		self._layer:removeProp( self._deployProp )
		self._deployProp = nil
	end
	if self._exitProp then
		self._boardRig:getLayer():removeProp( self._exitProp )
		self._exitProp = nil
	end	
end

function cell_rig:getSides()
	return self._sides
end

function cell_rig:getSide( dir )
	return self._sides[ dir ]
end

function cell_rig:addDependentRigs( updateRigs )
	for _, wallRig in ipairs(self._dependentRigs) do
		updateRigs[ wallRig ] = wallRig
	end
end

function cell_rig:refresh( )
	local scell = self._boardRig:getLastKnownCell( self._x, self._y )

	if self._deployProp and scell ~= nil then
		self._deployProp:setVisible( true ) 
	end
	
	if self._exitProp and scell ~= nil then
		self._exitProp:setVisible( true )
	end	

	local rawcell = self._game.simCore:getCell( self._x, self._y )
	if rawcell ~= nil then
		if (rawcell.danger or 0) > 0 then
			self._boardRig._dangerGrid:getGrid():setTile( self._x, self._y, cdefs.MAINFRAME_DANGER_CELL )
		elseif (rawcell.psidanger or 0) > 0 then
			self._boardRig._dangerGrid:getGrid():setTile( self._x, self._y, cdefs.PSI_DANGER_CELL )
		else
			self._boardRig._dangerGrid:getGrid():setTile( self._x, self._y, 0 )
		end

		local orientation = self._boardRig._game:getCamera():getOrientation()

		local idx = cdefs.BLACKOUT_CELL
		local flags = 0

		local gfxOptions = self._game:getGfxOptions()
   		if gfxOptions.bMainframeMode then
   			if scell == nil then
   				idx = cdefs.BLACKOUT_CELL
				flags = MOAIGridSpace.TILE_HIDE
			else
				idx = cdefs.MAINFRAME_CELL + orientation
   			end
		else
			local mapTile = cdefs.MAPTILES[ rawcell.tileIndex ]
			idx = mapTile.tileStart + (self._x-1 + self._y-1) % mapTile.patternLen

			if rawcell.tileIndex ~= cdefs.TILE_UNKNOWN and scell == nil then
				idx = cdefs.BLACKOUT_CELL -- BLACK OUT BABY (never visible)
				flags = MOAIGridSpace.TILE_HIDE
			end
		end
		self._boardRig._grid:getGrid():setTile( self._x, self._y, idx )
		self._boardRig._grid:getGrid():setTileFlags( self._x, self._y, flags )

		if self._exitProp then
			self._exitProp:setCurrentFacingMask( 2^((self._dir - orientation*2) % simdefs.DIR_MAX) )	
		end
	end
end

return cell_rig


