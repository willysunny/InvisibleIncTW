----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources" )
local animmgr = include( "anim-manager" )
local cdefs = include( "client_defs" )
local util = include( "modules/util" )
local simdefs = include( "sim/simdefs" )

-----------------------------------------------------
-- Local

local wall_rig = class( )

function wall_rig:init( boardRig, x1, y1, simdir_1, wallVBO )
	local N,E,S,W = simdefs.DIR_N, simdefs.DIR_E, simdefs.DIR_S, simdefs.DIR_W
	
	local x2, y2 = x1, y1
	local simdir_2
	if simdir_1 == E then
		x2 = x1+1
		simdir_2 = W
	elseif simdir_1 == N then
		y2 = y1+1
		simdir_2 = S
	else
		assert( false )
	end

	local cellviz_1 = boardRig:getClientCellXY( x1, y1 )
	local geoOffsets_1 = cellviz_1._wallGeoInfo or {}
	table.insert( cellviz_1._dependentRigs, self )

	local cellviz_2 = boardRig:getClientCellXY( x2, y2 )
	local geoOffsets_2 = cellviz_2._wallGeoInfo or {}
	table.insert( cellviz_2._dependentRigs, self )

	self._boardRig = boardRig
	self._x1, self._y1 = x1, y1
	self._x2, self._y2 = x2, y2
	
	self._game = boardRig._game

	self._layer = boardRig:getLayer()

	local wallUV1 = (cellviz_1.tileIndex and cdefs.MAPTILES[ cellviz_1.tileIndex ].zone.wallUV) or cdefs.WALL_EXTERNAL
	local wallUV2 = (cellviz_2.tileIndex and cdefs.MAPTILES[ cellviz_2.tileIndex ].zone.wallUV) or cdefs.WALL_EXTERNAL

	local zx, zy = boardRig:cellToWorld( -0.5, -0.5 )

	local pieces = {}
	table.insert( pieces, { x = x1, y = y1, geoOffsets = geoOffsets_1[simdir_1], UVInfo = wallUV1 } )
	table.insert( pieces, { x = x2, y = y2, geoOffsets = geoOffsets_2[simdir_2], UVInfo = wallUV2 } )
	

	local mt = MOAIMultiTexture.new()
	mt:reserve( 2 )
	mt:setTexture( 1, cdefs.WALLTILES_FILE )
	mt:setTexture( 2, self._game.shadow_map )

	for _,piece in pairs(pieces) do
		local mesh = MOAIMesh.new()
		mesh:setTexture( mt )
		mesh:setVertexBuffer( wallVBO )
		mesh:setPrimType( MOAIMesh.GL_TRIANGLES )
		mesh:setElementOffset( 0 )
		mesh:setElementCount( 0 )

		local prop = MOAIProp.new()
		prop:setDeck( mesh )
		prop:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.WALL_SHADER ) )
		prop:setDepthTest( MOAIProp.DEPTH_TEST_ALWAYS )
		prop:setDepthMask( false )
		prop:setCullMode( MOAIProp.CULL_NONE )
		prop:setLoc( zx, zy )

		self:setUVTransform( prop, piece.UVInfo )

		self._layer:insertProp( prop )
		piece.prop = prop
		piece.mesh = mesh
	end

	self._pieces = pieces
end

function wall_rig:setUVTransform( prop, uvInfo )
	local u,v,U,V = unpack( uvInfo )
	local uvTransform = MOAITransform.new()
	uvTransform:setScl( 1,1 )
	uvTransform:addLoc( 0,0 )

	prop:setUVTransform( uvTransform )
end

function wall_rig:setRenderFilter( x, y, filter )
	local rf = cdefs.RENDER_FILTERS[filter]
	for _,piece in pairs( self._pieces ) do
		if rf and piece.x == x and piece.y == y then
			self:setShader( piece.prop, rf.shader, rf.r, rf.g, rf.b, rf.a, rf.lum )
		elseif piece.x ==x and piece.y == y then
			self:setShader( piece.prop )
		end
	end
end

function wall_rig:setShader( prop, type, r, g, b, a, l )
	prop:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.WALL_SHADER) )
	local uniforms = prop:getShaderUniforms()
	uniforms:setUniformColor( "Modulate", r, g, b, a )
	uniforms:setUniformFloat( "Luminance", l )
	uniforms:setUniformFloat( "Opacity", 1 )
	uniforms:setUniformInt( "Type", type and type or 0 )
end


function wall_rig:getLocation1()
	return self._x1, self._y1
end
function wall_rig:getLocation2()
	return self._x2, self._y2
end

function wall_rig:refreshRenderFilterHelper( x, y )
	local gfxOptions = self._game:getGfxOptions()
	local cell = self._boardRig:getLastKnownCell( x, y )
	local render_filter = gfxOptions.bMainframeMode and "default" or "shadowlight"
	if cell then
		local cellrig = self._boardRig:getClientCellXY( x, y )		
		local render_filter
		if gfxOptions.bMainframeMode then
			render_filter = 'default'
		else
			render_filter = cdefs.MAPTILES[ cellrig.tileIndex ].render_filter.dynamic or "shadowlight"
		end
	end
	self:setRenderFilter( x, y, render_filter )
end
function wall_rig:refreshRenderFilter()
	self:refreshRenderFilterHelper( self:getLocation1() )
	self:refreshRenderFilterHelper( self:getLocation2() )
end

function wall_rig:destroy()
	for _,piece in pairs( self._pieces ) do
		self._layer:removeProp( piece.prop )
	end
	self._pieces = nil
end

function wall_rig:generateTooltip( )
end

function wall_rig:refreshProp()
	-- Determine if wall should be rendered half-size and/or transparently.
	local gfxOptions = self._game:getGfxOptions()
	local offsetIdx = gfxOptions.bMainframeMode and "mainframe" or "normal"
	local camera_orientation = self._boardRig._game:getCamera():getOrientation()

	local cell = self._boardRig:getLastKnownCell( self:getLocation1() ) or self._boardRig:getLastKnownCell( self:getLocation2() )

	if  self._boardRig._game.simCore._showOutline then
		local cell1 = self._boardRig._game.simCore:getCell( self:getLocation1() )
		local cell2 = self._boardRig._game.simCore:getCell( self:getLocation2() )

		if not cell and (not cell1 or not cell2) then 
			cell = true
			offsetIdx = "mainframe"
		end
	end

	if cell then
		local uvInfoOverload
		if offsetIdx == 'mainframe' then
			uvInfoOverload = cdefs.WALL_MAINFRAME
		end
		for _,piece in pairs(self._pieces) do
			local prop, mesh = piece.prop, piece.mesh
			local offset,count = 0, 0
			if piece.geoOffsets and piece.geoOffsets[offsetIdx] then
				offset,count = unpack( piece.geoOffsets[offsetIdx] )
			end
			--if offsetIdx == "normal" then offset,count = 0,0 end
			mesh:setElementOffset( offset )
			mesh:setElementCount( count )
			
			self:setUVTransform( prop, uvInfoOverload or piece.UVInfo )

			prop:scheduleUpdate()
		end
	else
		for _,piece in pairs(self._pieces) do
			local prop, mesh = piece.prop, piece.mesh
			mesh:setElementOffset( 0 )
			mesh:setElementCount( 0 )
			prop:scheduleUpdate()
		end
	end

	self:refreshRenderFilter()
end

function wall_rig:refresh( )
	self:refreshProp()	
end

-----------------------------------------------------
-- Interface functions

return wall_rig
