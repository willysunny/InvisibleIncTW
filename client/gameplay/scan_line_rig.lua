----------------------------------------------------------------
-- Copyright (c) 2014 Klei Entertainment Inc.
-- All Rights Reserved.
-- Invisible Inc.
----------------------------------------------------------------

local resources = include( "resources" )
local util = include( "client_util" )
local cdefs = include( "client_defs" )
local mathutil = include( "modules/mathutil" )
include("class")

local function createScanLineMesh( boardRig, start_points, end_points )
	local P =
	{
		S = { {boardRig:cellToWorld( unpack( start_points[1] ) )}, {boardRig:cellToWorld( unpack( start_points[2] ) )} },
		E = { {boardRig:cellToWorld( unpack( end_points[1] ) )}, {boardRig:cellToWorld( unpack( end_points[2] ) )} },
	}

	print( 's[1]', P.S[1][1], P.S[1][2] )
	print( 's[2]', P.S[2][1], P.S[2][2] )

	print( 'e[1]', P.E[1][1], P.E[1][2] )
	print( 'e[2]', P.E[2][1], P.E[2][2] )
	
	local h = cdefs.BOARD_TILE_SIZE * 2.25

	local vertexFormat = MOAIVertexFormat.new()
	vertexFormat:declareCoord	( 1, MOAIVertexFormat.GL_FLOAT, 3 )
	vertexFormat:declareUV		( 2, MOAIVertexFormat.GL_FLOAT, 3 )
	vertexFormat:declareUV		( 3, MOAIVertexFormat.GL_FLOAT, 2 )

	local vbo = MOAIVertexBuffer.new()
	vbo:setFormat( vertexFormat )
	vbo:reserveVerts( 6 )

		vbo:writeFloat( P.S[1][1], P.S[1][2], 0 )
		vbo:writeFloat( P.E[1][1], P.E[1][2], 0 )
		vbo:writeFloat( 0, 0 )

		vbo:writeFloat( P.S[2][1], P.S[2][2], 0 )
		vbo:writeFloat( P.E[2][1], P.E[2][2], 0 )
		vbo:writeFloat( 1, 0 )

		vbo:writeFloat( P.S[2][1], P.S[2][2], h )
		vbo:writeFloat( P.E[2][1], P.E[2][2], h )
		vbo:writeFloat( 1, 1 )

		vbo:writeFloat( P.S[1][1], P.S[1][2], 0 )
		vbo:writeFloat( P.E[1][1], P.E[1][2], 0 )
		vbo:writeFloat( 0, 0 )

		vbo:writeFloat( P.S[2][1], P.S[2][2], h )
		vbo:writeFloat( P.E[2][1], P.E[2][2], h )
		vbo:writeFloat( 1, 1 )

		vbo:writeFloat( P.S[1][1], P.S[1][2], h )
		vbo:writeFloat( P.E[1][1], P.E[1][2], h )
		vbo:writeFloat( 0, 1 )

	vbo:bless()

	local mesh = MOAIMesh.new()
	mesh:setVertexBuffer( vbo )
	mesh:setPrimType( MOAIMesh.GL_TRIANGLES )

	return mesh
end

local scan_line_rig = class()

function scan_line_rig:init( boardRig, start_points, end_points, life_span, color)

	local mesh = createScanLineMesh( boardRig, start_points, end_points )

	local prop = MOAIProp.new()
	prop:setDeck( mesh )
	prop:setDepthTest( MOAIProp.DEPTH_TEST_ALWAYS )
	prop:setDepthMask( false )
	prop:setCullMode( MOAIProp.CULL_NONE )
	prop:setBlendMode( MOAIProp.BLEND_ADD )
	prop:setShader( MOAIShaderMgr.getShader( MOAIShaderMgr.SCAN_SHADER ) )

	self._boardRig = boardRig
	self._prop = prop
	self._lifeSpan = life_span
	self._startTime = MOAISim.getElapsedTime()
	self._color = color or {140/255, 255/255, 255/255, 0.75}

	self._layer = boardRig:getLayer( 'ceiling' )
	self._layer:insertProp( prop )
end

function scan_line_rig:destroy()
	self._layer:removeProp( self._prop )
	
	self._boardRig = nil
	self._prop = nil
	self._layer = nil
end

function scan_line_rig:onFrameUpdate()
	local localTime = MOAISim.getElapsedTime() - self._startTime

	localTime = localTime / self._lifeSpan

	if localTime > 1 then
		return false
	end

	--print( localTime )

	local uniforms = self._prop:getShaderUniforms()
	uniforms:setUniformVector4( 'params', localTime, 0.0, 0.0, 1.0 )
	uniforms:setUniformColor( 'color', unpack( self._color ) )

	return true
end

return scan_line_rig