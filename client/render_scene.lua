include( "class" )

local KLEIRenderSceneClass = class()

local function smootherstep( edge0, edge1, t )
	if (t <= edge0) then
		return 0.0
	elseif t >= edge1 then
		return 1.0
	else
		t = (t - edge0) / (edge1 - edge0)
		return t*t*t*(t*(t*6 - 15) + 10)
	end
end

function KLEIRenderSceneClass:init()
	--Render tables
	self._gameTbl = {}
	self._hudTbl = {}
	self._mouseCursor = {}
	--Render parameters
	self._DaltonizationType = 0
	self._UIEasePulseTimers = {}

	self.easeDriver = function()
		local ease = 0
		for i,timer in ipairs( self._UIEasePulseTimers ) do
			--controls the ease-in and ease-out of the pulse
			local pp = timer:getTime()
			local pl = timer:getPeriod()
			--local  ramp = math.min( 1.0, 1.0 - math.pow( math.cos( 2 * math.pi * pp / pl ), 3.0) );
			--local ramp = math.cos( 10*2*math.pi * pp / pl )/2 + 0.5
			local ramp = smootherstep( 0.0, 1.0, pp/pl )
			ease = ease + ramp
		end
		ease = math.min( ease, 1.0 )
		self._PP._pp:getUniforms():setUniformFloat( 'ease', ease )
	end

	self.easeFinishedFunc = function( timer, executed )
		for i,v in ipairs(self._UIEasePulseTimers) do
			if v == timer then
				table.remove( self._UIEasePulseTimers, i )
				if #self._UIEasePulseTimers == 0 then
					self:setup()
				end
				return
			end
		end
		assert(false)
	end
end
function KLEIRenderSceneClass:initRT()
	local post_process_manager = include( "post_process_manager" )
	self._RT = CreateRenderTarget()
	self._RT:setClearColor( 0, 0, 0, 0 )
	self._RT:setClearStencil( 0 )
	self._RT:setClearDepth( true )
	self._PP = post_process_manager.create_post_process( self._RT )
end

function KLEIRenderSceneClass:resizeRenderTargets()
	for _,rt in pairs(self._gameTbl) do
		if rt.init and not rt.bConstSize then
			rt:init( VIEWPORT_WIDTH, VIEWPORT_HEIGHT, MOAITexture.GL_RGBA8, MOAITexture.GL_DEPTH_COMPONENT16 )
		end
	end
	self._RT:init( VIEWPORT_WIDTH, VIEWPORT_HEIGHT, MOAITexture.GL_RGBA8, MOAITexture.GL_DEPTH_COMPONENT16 )
end

function KLEIRenderSceneClass:setGameRenderTable( tbl )
	self._gameTbl = tbl or {}
	self:setup()
end
function KLEIRenderSceneClass:setHudRenderTable( tbl )
	self._hudTbl = tbl or {}
	self:setup()
end
function KLEIRenderSceneClass:setMouseCursor( renderable )
	self._mouseCursor = { renderable }
end
function KLEIRenderSceneClass:setDaltonizationType( type )
	assert( type == 0 or type == 1 or type == 2 or type == 3 )
	self._DaltonizationType = type
	self:setup()
end

function KLEIRenderSceneClass:pulseUIFuzz( period )
	local timer = MOAITimer.new ()
	timer:setSpan ( period )
	timer:setMode ( MOAITimer.NORMAL )
	timer:setListener ( MOAITimer.EVENT_TIMER_END_SPAN, self.easeFinishedFunc )	
	timer:start()

	table.insert( self._UIEasePulseTimers, timer )

	self._EaseType = 0

	self:setup()
end

function KLEIRenderSceneClass:pulseUIAscii( period )
	local timer = MOAITimer.new ()
	timer:setSpan ( period )
	timer:setMode ( MOAITimer.NORMAL )
	timer:setListener ( MOAITimer.EVENT_TIMER_END_SPAN, self.easeFinishedFunc )	
	timer:start()

	table.insert( self._UIEasePulseTimers, timer )	

	self._EaseType = 1

	self:setup()
end

function KLEIRenderSceneClass:pulseUIShutter( period, shutter_distance )
	local timer = MOAITimer.new ()
	timer:setSpan ( period )
	timer:setMode ( MOAITimer.NORMAL )
	timer:setListener ( MOAITimer.EVENT_TIMER_END_SPAN, self.easeFinishedFunc )	
	timer:start()

	table.insert( self._UIEasePulseTimers, timer )	

	self._EaseType = 2
	self._Params = {shutter_distance=shutter_distance}

	self:setup()
end

function KLEIRenderSceneClass:setup()
	local renderTable

	if self._DaltonizationType > 0 and #self._UIEasePulseTimers > 0 and self._EaseType == 0 then
		--Daltonize and Fuzz
		self._RT:setRenderTable( { self._gameTbl, self._hudTbl } )
		self._PP:daltonize_fuzz( self._DaltonizationType, self.easeDriver )
		renderTable = { self._RT, self._PP:getRenderable(), self._mouseCursor }
	elseif self._DaltonizationType > 0 and #self._UIEasePulseTimers > 0 and self._EaseType == 1 then
		--Daltonize and Ascii
		self._RT:setRenderTable( { self._gameTbl, self._hudTbl } )
		self._PP:daltonize_ascii( self._DaltonizationType, self.easeDriver )
		renderTable = { self._RT, self._PP:getRenderable(), self._mouseCursor }
	elseif self._DaltonizationType > 0 then
		--Only daltonization
		self._RT:setRenderTable( { self._gameTbl, self._hudTbl } )
		self._PP:daltonize( self._DaltonizationType )
		renderTable = { self._RT, self._PP:getRenderable(), self._mouseCursor }
	elseif #self._UIEasePulseTimers > 0 and self._EaseType == 0 then
		--Fuzz only
		self._RT:setRenderTable( { self._gameTbl, self._hudTbl } )
		self._PP:fuzz( self.easeDriver )
		renderTable = {  self._RT, self._PP:getRenderable(), self._mouseCursor }
	elseif #self._UIEasePulseTimers > 0 and self._EaseType == 1 then
		--Ascii only
		self._RT:setRenderTable( { self._gameTbl, self._hudTbl } )
		self._PP:ascii( self.easeDriver )
		renderTable = { self._RT, self._PP:getRenderable(), self._mouseCursor }
	elseif #self._UIEasePulseTimers > 0 and self._EaseType == 2 then
		--Shutter only
		self._RT:setRenderTable( { self._gameTbl, self._hudTbl } )
		self._PP:shutter( self.easeDriver, self._Params.shutter_distance )
		renderTable = { self._RT, self._PP:getRenderable(), self._mouseCursor }
	else
		--This is a passthrough
		self._RT:setRenderTable( { self._gameTbl, self._hudTbl, self._mouseCursor } )
		self._PP:passthrough()
		renderTable = { self._RT, self._PP:getRenderable() }
	end

	MOAIRenderMgr.setRenderTable( renderTable )
end

return KLEIRenderSceneClass
