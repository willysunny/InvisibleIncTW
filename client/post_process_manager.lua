----------------------------------------------------------------
-- Copyright (c) 2013 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------


require("class")

local post_process = class()

function post_process:init( diffuse, overlay )
	self._diffuse = diffuse
	self._diffuse:setFilter( MOAITexture.GL_LINEAR, MOAITexture.GL_LINEAR )
	self._overlay = overlay
	self._pp = KLEIPostProcess.new()
	if diffuse and overlay then
		self:overlay()
	elseif diffuse then
		self:passthrough()
	else
		assert(false)
	end
end

function post_process:destroy()
	self._pp = nil
	self._diffuse = nil
	self._overlay = nil
	self._mt = nil
	self._span = nil
	self._lerp = nil
	self._timer = nil
end

function post_process:getRenderable()
	return self._pp
end

function post_process:passthrough( )
	self._pp:setEffect( KLEIPostProcess.PASS_THROUGH )
	self._pp:setTexture( self._diffuse )
	self._pp:getUniforms():setUniformDriver( nil )
	self._mt = nil
end

function post_process:overlay()
	self._mt = MOAIMultiTexture.new()
	self._mt:reserve( 2 )
	self._mt:setTexture( 1, self._diffuse )
	self._mt:setTexture( 2, self._overlay )	

	self._pp:setEffect( KLEIPostProcess.OVERLAY )
	self._pp:setTexture( self._mt )
	self._pp:getUniforms():setUniformDriver( nil )
end

function post_process:ascii( UIEaseDriver )
	self._mt = MOAIMultiTexture.new()
	self._mt:reserve( 2 )
	self._mt:setTexture( 1, self._diffuse )
	self._mt:setTexture( 2, "data/images/ascii.png" )

	self._pp:setEffect( KLEIPostProcess.ASCII )
	self._pp:setTexture( self._mt )
	self._pp:getUniforms():setUniformDriver( UIEaseDriver )
end

function post_process:fuzz( UIEaseDriver )
	assert( UIEaseDriver )
	self._pp:setEffect( KLEIPostProcess.FUZZ )
	self._pp:setTexture( self._diffuse )
	self._pp:getUniforms():setUniformDriver( UIEaseDriver )
	self._mt = nil
end

function post_process:shutter( UIEaseDriver, shutter_distance )
	assert( UIEaseDriver )
	self._pp:setEffect( KLEIPostProcess.SHUTTER )
	self._pp:setTexture( self._diffuse )
	self._pp:getUniforms():setUniformDriver( UIEaseDriver )
	self._pp:getUniforms():setUniformFloat( "shutter_distance", 32.0 )
	self._mt = nil
end

local color_correction = {
--Protanope -- Red cone deficiency
protanope = {	simulation = {	0.000000,  2.023440, -2.525810,  0.000000,
								0.000000,  1.000000,  0.000000,  0.000000,
								0.000000,  0.000000,  1.000000,  0.000000,
								0.000000,  0.000000,  0.000000,  1.000000 },
				correction = {  0.0, 0.5, 0.5, 0.0, 
								0.0, 1.0, 0.0, 0.0,
								0.0, 0.0, 1.0, 0.0,
								0.0, 0.0, 0.0, 1.0 },
			}, --protanope
--Deuteranope -- Green cone deficiency
deuteranope = { simulation = {	1.000000,  0.000000,  0.000000,  0.000000,
								0.494207,  0.000000,  1.248270,  0.000000,
								0.000000,  0.000000,  1.000000,  0.000000,
								0.000000,  0.000000,  0.000000,  1.000000 },
				correction = {	1.0, 0.0, 0.0, 0.0,
								0.5, 0.0, 0.5, 0.0,
								0.0, 0.0, 1.0, 0.0,
								0.0, 0.0, 0.0, 1.0 },
			  }, --deuteranope
--Tritanope -- Blue cone deficiency
tritanope = {	simulation = {  1.000000,  0.000000,  0.000000,  0.000000,
								0.000000,  1.000000,  0.000000,  0.000000,
							   -0.395913,  0.801109,  0.000000,  0.000000,
							    0.000000,  0.000000,  0.000000,  1.000000 },
				correction = {	1.0, 0.0, 0.0, 0.0,
								0.0, 1.0, 0.0, 0.0,
								0.5, 0.5, 0.0, 0.0,
								0.0, 0.0, 0.0, 1.0 },
			}, --tritanope
} --color_correction

function post_process:daltonize( type )
	assert( type == 1 or type == 2 or type == 3 )
	self._pp:setEffect( KLEIPostProcess.DALTONIZE )
	self._pp:setTexture( self._diffuse )
	self._pp:getUniforms():setUniformDriver( nil )
	if type == 1 then --Protanope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.protanope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.protanope.correction) )
	elseif type == 2 then --Deuteranope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.deuteranope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.deuteranope.correction) )
	elseif type == 3 then --Tritanope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.tritanope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.tritanope.correction) )
	end
	self._mt = nil
end

function post_process:daltonize_fuzz( daltonization, UIFuzzDriver )
	assert( daltonization == 1 or daltonization == 2 or daltonization == 3 )
	assert( UIFuzzDriver )
	self._pp:setEffect( KLEIPostProcess.DALTONIZE_FUZZ )
	self._pp:setTexture( self._diffuse )
	self._pp:getUniforms():setUniformDriver( UIFuzzDriver )

	if daltonization == 1 then --Protanope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.protanope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.protanope.correction) )
	elseif daltonization == 2 then --Deuteranope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.deuteranope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.deuteranope.correction) )
	elseif daltonization == 3 then --Tritanope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.tritanope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.tritanope.correction) )
	end

	self._mt = nil
end

function post_process:daltonize_ascii( daltonization, UIEaseDriver )
	assert( daltonization == 1 or daltonization == 2 or daltonization == 3 )
	assert( UIEaseDriver )

	self._mt = MOAIMultiTexture.new()
	self._mt:reserve( 2 )
	self._mt:setTexture( 1, self._diffuse )
	self._mt:setTexture( 2, "data/images/ascii.png" )

	self._pp:setEffect( KLEIPostProcess.DALTONIZE_ASCII )
	self._pp:setTexture( self._mt )
	self._pp:getUniforms():setUniformDriver( UIEaseDriver )

	if daltonization == 1 then --Protanope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.protanope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.protanope.correction) )
	elseif daltonization == 2 then --Deuteranope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.deuteranope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.deuteranope.correction) )
	elseif daltonization == 3 then --Tritanope
		self._pp:getUniforms():setUniformMat4x4( "simulation", unpack(color_correction.tritanope.simulation) )
		self._pp:getUniforms():setUniformMat4x4( "correction", unpack(color_correction.tritanope.correction) )
	end
end

function post_process:colorCubeLerp( cube1, cube2, span, mode, start, stop )
	self._mt = MOAIMultiTexture.new()
	if self._overlay then
		self._mt:reserve( 4 )
		self._mt:setTexture( 1, self._diffuse )
		self._mt:setTexture( 2, self._overlay )
		self._mt:setTexture( 3, cube1 )
		self._mt:setTexture( 4, cube2 )
	else
		self._mt:reserve( 3 )
		self._mt:setTexture( 1, self._diffuse )		
		self._mt:setTexture( 2, cube1 )
		self._mt:setTexture( 3, cube2 )
	end

	self._pp:setTexture( self._mt )

	start = start or 0
	stop = stop or 1

	local timer = MOAITimer.new()
	timer:setSpan( span )
	timer:setMode( mode )
	timer:start()
	local uniformDriver = function()
		local t = timer:getTime() / span
		self._pp:setUniformFloat( "cc_lerp", t * ( stop - start ) + start )
	end

	if self._overlay then
		self._pp:setEffect( KLEIPostProcess.COLOR_CUBE_OVERLAY )
	else
		self._pp:setEffect( KLEIPostProcess.COLOR_CUBE )
	end
	self._pp:getUniforms():setUniformDriver( uniformDriver )
end

------------------------------------------------------------------------------------------------------------

local post_process_manager = class()

function post_process_manager:init()
end

function post_process_manager:destroy()
end

function post_process_manager.create_post_process( diffuse, overlay )
	return post_process( diffuse, overlay )
end

return post_process_manager