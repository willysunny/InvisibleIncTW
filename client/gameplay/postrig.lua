----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources" )
local animmgr = include( "anim-manager" )
local cdefs = include( "client_defs" )
local util = include( "modules/util" )

-----------------------------------------------------
-- Local

local post_rig = class( )

function post_rig:init( boardRig, x, y, wallVBO )

	local cellrig = boardRig:getClientCellXY( x, y )
	local geoInfo = cellrig and cellrig._capsGeoInfo

	self._x = x
	self._y = y
	self._boardRig = boardRig
	self._valid = geoInfo and true
	self._game = boardRig._game
	self._layer = boardRig:getLayer()
	self._locations = { {x=x,y=y}, {x=x,y=y+1}, {x=x+1,y=y+1}, {x=x+1,y=y} }
	self._capsGeoInfo = geoInfo
	
	if geoInfo then
		local zx, zy = boardRig:cellToWorld( -0.5, -0.5 )
	
		local mt = MOAIMultiTexture.new()
		mt:reserve( 2 )
		mt:setTexture( 1, cdefs.WALLTILES_FILE )
		mt:setTexture( 2, self._game.shadow_map )

		local mesh = MOAIMesh.new()
		mesh:setTexture( mt )
		mesh:setVertexBuffer( wallVBO )
		mesh:setPrimType( MOAIMesh.GL_TRIANGLES )
		mesh:setElementOffset( 0 )
		mesh:setElementCount( 0 )

		local prop = MOAIProp.new()
		prop:setDeck( mesh )
		prop:setDepthTest( MOAIProp.DEPTH_TEST_ALWAYS )
		prop:setDepthMask( false )
		prop:setCullMode( MOAIProp.CULL_NONE )
		prop:setLoc( zx, zy )
		prop:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.WALL_SHADER ) )				

		self._layer:insertProp( prop )

		self:setUVTransform( prop, cdefs.POST_DEFAULT )

		self._prop = prop
		self._mesh = mesh

		for _,location in pairs( self._locations ) do
			local cellrig = boardRig:getClientCellXY( location.x, location.y )
			assert( cellrig )
			table.insert( cellrig._dependentRigs, self )
		end
	end
end

function post_rig:isValid()
	return self._valid
end

function post_rig:setRenderFilter( prop, filter, po )
	local rf = cdefs.RENDER_FILTERS[filter]
	self:setShader( prop, rf.shader, rf.r, rf.g, rf.b, rf.a, rf.lum, po )
end

function post_rig:setShader( prop, type, r, g, b, a, l, po )
	prop:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.WALL_SHADER) )
	local uniforms = prop:getShaderUniforms()
	uniforms:setUniformColor( "Modulate", r, g, b, a )
	uniforms:setUniformFloat( "Luminance", l )
--	uniforms:setUniformFloat( "Opacity", 1 - po / 100 )
	uniforms:setUniformInt( "Type", type and type or 0 )
end

function post_rig:refreshRenderFilter( po )
	local ghost = true
	local tileIndex
	for _,location in ipairs( self._locations ) do
		local cell = self._boardRig:getLastKnownCell( location.x, location.y )
		ghost = ghost and (not cell or cell.ghostID)
		tileIndex = tileIndex or cell and cell.tileIndex
	end
	local gfxOptions = self._game:getGfxOptions()
	local renderFilter
	if gfxOptions.bMainframeMode then
		renderFilter = 'default'
	else
		renderFilter = (tileIndex and cdefs.MAPTILES[ tileIndex ].render_filter.dynamic) or "shadowlight"
	end
	self:setRenderFilter( self._prop, renderFilter, po )
end

function post_rig:destroy()
	if self._prop then self._layer:removeProp( self._prop ) end
	self._prop = nil
	self._mesh = nil
end

function post_rig:generateTooltip( )
end

function post_rig:refreshProp()
	-- Determine if wall should be rendered half-size and/or transparently.
	local gfxOptions = self._game:getGfxOptions()
	local boardRig = self._boardRig
	local mode = gfxOptions.bMainframeMode and "mainframe" or "normal"
	local camera_orientation = boardRig._game:getCamera():getOrientation()

	local po = 0
	local vis_mask = 0
	for i,location in ipairs( self._locations ) do
		local cell = boardRig:getLastKnownCell( location.x, location.y )
		if cell then
			vis_mask = vis_mask + 2^(i-1)
		end

		cell = boardRig:getClientCellXY( location.x, location.y )
		if cell then
			for obstruction,value in pairs( cell._obstruction_values ) do
			if obstruction:isVisible() then
				po = (value.p > po) and value.p or po
			end
		end
	end
	end

	local camGeoInfo = self._capsGeoInfo[vis_mask]
	if camGeoInfo then
		local geoInfo = camGeoInfo[ camera_orientation + 1 ]
		assert( geoInfo, "missing GeoInfo", self._x, self._y, vis_mask, camera_orientation )
		self._mesh:setElementOffset( geoInfo[mode][1] )
		self._mesh:setElementCount( geoInfo[mode][2] )
		self:refreshRenderFilter( po )
		self._prop:scheduleUpdate()
	else
		self._mesh:setElementOffset( 0 )
		self._mesh:setElementCount( 0 )
		self._prop:scheduleUpdate()
	end
end

function post_rig:setUVTransform( prop, uvInfo )
	local u,v,U,V = unpack( uvInfo )
	local uvTransform = MOAITransform.new()
	uvTransform:setScl( 1, 1 )
	uvTransform:addLoc( 0, 0 )

	prop:setUVTransform( uvTransform )
end

function post_rig:refresh( )
	self:refreshProp()	
end

-----------------------------------------------------
-- Interface functions

return post_rig
