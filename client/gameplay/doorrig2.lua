----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "modules/util" )
local cdefs = include( "client_defs" )
local simdefs = include("sim/simdefs")

----------------------------------------------------------------

local door_rig = class(  )

function door_rig:init( boardRig, x1, y1, simdir1, VBO )
	local N,E,S,W = simdefs.DIR_N, simdefs.DIR_E, simdefs.DIR_S, simdefs.DIR_W
	
	local x2, y2 = x1, y1
	local simdir2
	if simdir1 == E then
		x2 = x1+1
		simdir2 = W
	elseif simdir1 == N then
		y2 = y1+1
		simdir2 = S
	else
		assert( false )
	end

	local cellviz_1 = boardRig:getClientCellXY( x1, y1 )
	table.insert( cellviz_1._dependentRigs, self )

	local cellviz_2 = boardRig:getClientCellXY( x2, y2 )
	table.insert( cellviz_2._dependentRigs, self )
	
	self._wallUVs = cellviz_1:getSide( simdir1 ).wallUVs

	self._boardRig = boardRig
	self._x1, self._y1 = x1, y1
	self._x2, self._y2 = x2, y2
	self._simdir1, self._simdir2 = simdir1, simdir2
	
	self._game = boardRig._game
	self._simdefs = simdefs
	self._layer = boardRig:getLayer()



	local mesh = MOAIMesh.new()
	mesh:setVertexBuffer( VBO )
	mesh:setPrimType( MOAIMesh.GL_TRIANGLES )
	mesh:setElementOffset( 0 )
	mesh:setElementCount( 0 )

	local zx, zy = boardRig:cellToWorld( -0.5, -0.5 )

	local prop = MOAIProp.new()
	prop:setDeck( mesh )
	prop:setDepthTest( MOAIProp.DEPTH_TEST_ALWAYS )
	prop:setDepthMask( false )
	prop:setCullMode( MOAIProp.CULL_NONE )
	prop:setLoc( zx, zy )
	prop:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.WALL_SHADER) )
	--prop:getShaderUniforms():setUniformColor( "Modulate", 1, 1, 1, 1 )
	--prop:getShaderUniforms():setUniformFloat( "Luminance", 1 )
	prop:getShaderUniforms():setUniformInt( "Type", 0 )

	self._layer:insertProp( prop )
	self._prop = prop
	self._mesh = mesh
	self._offsets = cellviz_1._doorGeoInfo[simdir1]

	self._secure = cellviz_1:getSide( simdir1 ).secure
	if self._secure then		

		local l1x,l1y = boardRig:cellToWorld( x1, y1 )
		local facing = 0
		if x1 == x2 then
			if y1 > y2 then
				facing = 6
			else
				facing = 2
			end
		else
			if x1 > x2 then
				facing = 4
			else
				facing = 0
			end
		end		
		self.lock1 = self._boardRig:createHUDProp("kanim_door_lock", "sock_trap", "idle", self._boardRig:getLayer(), nil, l1x, l1y, facing )
		self.lock1._facing = facing	
		
		local l2x,l2y = boardRig:cellToWorld( x2, y2 )

		local facing2 = self.lock1._facing + 4
		if facing2 >7 then
			facing2 = facing2 - 8
		end			
		self.lock2 = self._boardRig:createHUDProp("kanim_door_lock", "sock_trap", "idle", self._boardRig:getLayer(), nil, l2x, l2y, facing2  )		
		self.lock2._facing = self.lock1._facing + 4
		if self.lock2._facing >7 then
			self.lock2._facing = self.lock2._facing - 8
		end		
		
	end
end

function door_rig:destroy()

	if self.lock1 then		
		self._boardRig:getLayer():removeProp( self.lock1 )
	end
	if self.lock2 then		
		self._boardRig:getLayer():removeProp( self.lock2 )
	end

	self._layer:removeProp( self._prop )
	self._prop = nil
	self._mesh = nil

end

function door_rig:setUVTransform( uvInfo )
	local u,v,U,V = unpack( uvInfo )
	local uvTransform = MOAITransform.new()
	uvTransform:setScl( U-u, V-v )
	uvTransform:addLoc( u, v )

	self._mesh:setTexture( cdefs.WALLTILES_FILE )
	self._prop:setUVTransform( uvTransform )
end

function door_rig:getLocation1()
	return self._x1, self._y1
end
function door_rig:getLocation2()
	return self._x2, self._y2
end
function door_rig:getFacing1()
	return self._simdir1
end
function door_rig:getFacing2()
	return self._simdir2
end


function door_rig:refreshProp()
	local gfxOptions = self._game:getGfxOptions()
	local boardRig = self._boardRig
	local simdefs = boardRig._game.simCore:getDefs()
	local bMainFrameMode = gfxOptions.bMainframeMode

	local x1,y1 = self:getLocation1()
	local x2,y2 = self:getLocation2()

	local ex, ey, EX, EY
	local nx, ny, NX, NY

	if x2-x1 == 1 then
		ex, ey = self._boardRig:cellToWorld( x1 + 0.5, y1 - 0.5 )
		EX, EY = self._boardRig:cellToWorld( x1 + 0.5, y1 + 0.5 )
		nx,ny = 0,1
		NX,NY = 0,-1
	elseif x1-x2 == 1 then
		ex, ey = self._boardRig:cellToWorld( x2 + 0.5, y2 - 0.5 )
		EX, EY = self._boardRig:cellToWorld( x2 + 0.5, y2 + 0.5 )
		nx,ny = 0,-1
		NX,NY = 0,1
	elseif y2-y1 == 1 then
		ex, ey = self._boardRig:cellToWorld( x1 - 0.5, y1 + 0.5 )
		EX, EY = self._boardRig:cellToWorld( x1 + 0.5, y1 + 0.5 )
		nx,ny = 1,0
		NX,NY = -1,0
	elseif y1-y2 == 1 then
		ex, ey = self._boardRig:cellToWorld( x1 - 0.5, y2 + 0.5 )
		EX, EY = self._boardRig:cellToWorld( x1 + 0.5, y2 + 0.5 )
		nx,ny = -1,0
		NX,NY = 1,0
	else
		crash()
	end

	local ccell_1 = boardRig:getLastKnownCell( x1,y1 )
	local ccell_2 = boardRig:getLastKnownCell( x2,y2 )

	local offset, count = 0, 0

	if ccell_1 or ccell_2 then

		--cell1 is not exit and cell2 is exit then 

		local exit1 = ccell_1 and ccell_1.exits[ self._simdir1 ]
		local exit2 = ccell_2 and ccell_2.exits[ self._simdir2 ]

		-- This is slightly complicated by the fact that either either of cell or to_cell may be ghosted (or non-existent)
		-- We want to use the *most up to date* information (eg. the non-ghosted info, or most recent newest ghosted info).
		assert( ccell_1 or ccell_2 ) -- One of these MUST be non-nil, otherwise we shouldn't be visible.
		local showClosed, showLocked
		if ccell_1 and not ccell_1.ghostID then
			showClosed, showLocked = exit1.closed, exit1.locked
		elseif ccell_2 and not ccell_2.ghostID then
			showClosed, showLocked = exit2.closed, exit2.locked
		elseif not ccell_1 then
			showClosed, showLocked = exit2.closed, exit2.locked
		elseif not ccell_2 then
			showClosed, showLocked = exit1.closed, exit1.locked
		elseif ccell_1.ghostID > ccell_2.ghostID then
			showClosed, showLocked = exit1.closed, exit1.locked
		else
			showClosed, showLocked = exit2.closed, exit2.locked
		end

		if bMainFrameMode then
			if self._offsets and self._offsets['mainframe'] then
				offset, count = unpack( self._offsets['mainframe'] )
			end
			self:setUVTransform( cdefs.WALL_MAINFRAME )
		elseif showClosed and showLocked then
			if self._offsets and self._offsets['locked'] then
				offset, count = unpack( self._offsets['locked'] )
			end
			self:setUVTransform( self._wallUVs.locked )
		elseif showClosed then
			if self._offsets and self._offsets['unlocked'] then
				offset, count = unpack( self._offsets['unlocked'] )
			end
			self:setUVTransform( self._wallUVs.unlocked )
		end

		if self.lock1 then
			local orientation = self._boardRig._game:getCamera():getOrientation()

			self.lock1:setCurrentFacingMask( 2^((self.lock1._facing - orientation*2) % simdefs.DIR_MAX) )
			self.lock2:setCurrentFacingMask( 2^((self.lock2._facing - orientation*2) % simdefs.DIR_MAX) )

			if bMainFrameMode then
				self.lock1:setVisible(false)
				self.lock2:setVisible(false)
			elseif showClosed then
				self.lock2:setVisible(true)
				self.lock2:setVisible(true)
			else
				self.lock1:setVisible(false)
				self.lock2:setVisible(false)
			end

			if showLocked then
				self.lock1:setCurrentAnim( "idle" )
				self.lock2:setCurrentAnim( "idle" )
			else
				self.lock1:setCurrentAnim( "idle_unlocked" )
				self.lock2:setCurrentAnim( "idle_unlocked" )
			end			
		end		
	end

	local prop, mesh = self._prop, self._mesh
	mesh:setElementOffset( offset )
	mesh:setElementCount( count )
	
	local po = 0
	local cell_1 = boardRig:getClientCellXY( x1,y1 )
	local cell_2 = boardRig:getClientCellXY( x2,y2 )
	for obstruction,value in pairs( cell_1._obstruction_values ) do
		if obstruction:isVisible() then
			po = (value.p > po) and value.p or po
		end
	end
	for obstruction,value in pairs( cell_2._obstruction_values ) do
		if obstruction:isVisible() then
			po = (value.p > po) and value.p or po
		end
	end
	prop:getShaderUniforms():setUniformFloat( "Opacity", 1 - po / 100 )
	prop:scheduleUpdate()
end

function door_rig:refresh( )
	self:refreshProp()
end

-----------------------------------------------------
-- Interface functions

return door_rig
