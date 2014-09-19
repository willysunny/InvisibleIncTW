----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local cdefs = include( "client_defs" )
local array = include( "modules/array" )
local mathutil = include( "modules/mathutil" )
local simdefs = include( "sim/simdefs" )
local simquery = include( "sim/simquery" )

---------------------------------------------------------------------------
-- Local shit

local viz_thread = class()

function viz_thread:init( viz, fn )
	assert( fn )
	self.thread = coroutine.create( fn )
	self.viz = viz
	self.blocking = true

	debug.sethook( self.thread,
		function()
			error( "INFINITE LOOP DETECTED" )
		end, "", 1000000000 ) -- 1 billion instructions is... too
end

function viz_thread:onStop()
	self.viz:removeThread( self )
end

function viz_thread:isRunning()
	return coroutine.status( self.thread ) ~= "dead"
end

function viz_thread:block()
	self.blocking = true
end

function viz_thread:unblock()
	self.blocking = false
end

function viz_thread:isBlocking()
	return self.blocking and self:isRunning()
end

function viz_thread:waitForEvent( eventType )
	self:unblock()
	self.viz:registerHandler( eventType, self )
	local thread, ev = coroutine.yield()
	self.viz:unregisterHandler( eventType, self )
	self:block()
	return ev
end

function viz_thread:waitForDuration( duration )
	self.viz:registerHandler( 0, self )
	coroutine.yield()
	self.viz:unregisterHandler( 0, self )
end

function viz_thread:processViz( ev )
	if ev then
		ev.thread = self
	end
	local ok, err = coroutine.resume( self.thread, self, ev )
	if not ok then
		-- val will contain the error message if result is false
		moai.traceback( "Viz traceback:\n".. tostring(err), self.thread )
		moai.traceback( "Event source:\n"..tostring(err), self.viz.game.simThread )
	end
end

return viz_thread
