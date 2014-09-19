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
local agentrig = include( "gameplay/agentrig" )
local viz_thread = include( "gameplay/viz_thread" )

local function defaultHandler( thread, ev )
	local viz = thread.viz
	-- HUD needs first shot at events, because it handles switching mainframe mode.
	local result = viz.game.hud:onSimEvent( ev )
	viz.game.boardRig:onSimEvent( ev, ev.eventType, ev.eventData )
end

---------------------------------------------------------------------------
-- Viz manager.  Coordinates visualization upon handling events from the sim.

local EVENT_MAP = {}

EVENT_MAP[ simdefs.EV_PLAY_SOUND ] = function( viz, eventData )	
	if eventData.x then
		MOAIFmodDesigner.playSound( eventData.sound, nil, nil, {eventData.x,eventData.y,0}, nil )
	else
		MOAIFmodDesigner.playSound( eventData )
	end
	return false
end

EVENT_MAP[ simdefs.EV_HUD_MPUSED ] = function( viz, eventData )
	local rig = viz.game.boardRig:getUnitRig( eventData:getID() )
	if rig then
		rig:refreshHUD( eventData )
	end
	viz.game.hud._home_panel:refreshAgent( eventData )
end

EVENT_MAP[ simdefs.EV_CAM_PAN ] = function( viz, eventData )
	viz.game:cameraPanToCell( eventData[1], eventData[2] )
end

EVENT_MAP[ simdefs.EV_SHOW_WARNING ] = function( viz, eventData )
	if eventData.sound then
		MOAIFmodDesigner.playSound( eventData.sound )
	end
	if eventData.speech then
		MOAIFmodDesigner.playSound( eventData.speech )
	end	
	local txt = string.format(eventData.txt,eventData.variable)
	viz.game.hud:showWarning( txt,eventData.color, nil, nil, eventData.mainframe, eventData.icon_flash, eventData.ability, eventData.showModal, eventData.txt2,eventData.num,eventData.num2)
end

EVENT_MAP[ simdefs.EV_SHOW_OBJECTIVE ] = function( viz, eventData )
	viz.game.hud:refreshObjectives()
end

EVENT_MAP[ simdefs.EV_UNIT_ALERTED ] = function( viz, eventData )

	local rig = viz.game.boardRig:getUnitRig( eventData.unitID )
	if rig and rig.onUnitAlerted then
		rig:onUnitAlerted( viz, eventData )
	end
end

EVENT_MAP[ simdefs.EV_UNIT_CLOAK_CHANGED ] = function( viz, eventData )
	local rig = viz.game.boardRig:getUnitRig( eventData )
	if rig then
		rig:refresh()
		-- Need to update LOS cells because danger-status may change.
		local coords = {}
		local cells = {}
		viz.game.simCore:getLOS():getVizCells( eventData, coords )
		for i = 1, #coords, 2 do
			local x, y = coords[i], coords[i+1]
			table.insert( cells, viz.game.boardRig:getClientCellXY( x, y ) )
		end
		viz.game.boardRig:refreshCells( cells )
	end
end

EVENT_MAP[ simdefs.EV_UNIT_REFRESH_TRACKS ] = function( viz, eventData )
	viz.game.boardRig:getPathRig():refreshTracks( eventData )
end

---------------------------------------------------------------------------
-- Viz manager.  Coordinates visualization upon handling events from the sim.

local viz_manager = class()

viz_manager.viz_thread = viz_thread

function viz_manager:init( game )
	self.game = game
	self.threads = {}
	self.eventMap = {}
	self.eventCounter = {}
	for eventType, v in pairs(EVENT_MAP) do
		self.eventMap[ eventType ] = { v }
	end
end

function viz_manager:registerHandler( eventType, handler )
	assert( type(handler) == "function" or handler.processViz ~= nil )

	if self.eventMap[ eventType ] == nil then
		self.eventMap[ eventType ] = {}
	end

	table.insert( self.eventMap[ eventType ], handler )
end

function viz_manager:unregisterHandler( eventType, handler )
	array.removeElement( self.eventMap[ eventType ], handler )
end

function viz_manager:destroy()
	while #self.threads > 0 do
		self:removeThread( self.threads[1] )
	end
end

function viz_manager:removeThread( thread )
	array.removeElement( self.threads, thread )
	for eventType, handlers in pairs( self.eventMap ) do
		if array.find( handlers, thread ) then
			array.removeElement( handlers, thread )
		end
	end
end

function viz_manager:addThread( thread )
	table.insert( self.threads, thread )
end

function viz_manager:spawnViz( fn, ev )
	local thread = viz_thread( self, fn )
	self:addThread( thread )
	self:registerHandler( simdefs.EV_FRAME_UPDATE, thread )
	thread:processViz( ev )
	return thread
end

function viz_manager:processViz( ev )
	assert( ev )

	-- Simply to allow handlers to easily access the viz subsystem.
	ev.viz = self

	self.eventCounter[ ev.eventType ] = (self.eventCounter[ ev.eventType ] or 0) + 1

	local handlers = self.eventMap[ ev.eventType ]
	if handlers then
		for i = #handlers, 1, -1 do
			if type(handlers[i]) == "function" then
				handlers[i]( self, ev.eventData )
			else
				handlers[i]:processViz( ev.eventData )
			end
		end

	elseif ev.eventType ~= simdefs.EV_FRAME_UPDATE then
		-- defaultHandler could be removed if all handled events are added to the eventMap.
		self:spawnViz( defaultHandler, ev )
	end

	local isBlocking = false
	local i = 1
	while i <= #self.threads do
		local thread = self.threads[i]
		if not thread:isRunning() then
			self:removeThread( thread )
		else
			i = i + 1
			isBlocking = isBlocking or thread:isBlocking()
		end
	end

	return not isBlocking
end

function viz_manager:print()
	for i, thread in ipairs(self.threads) do
		log:write( "%d]\n%s", i, debug.traceback( thread.thread ))
	end
end

return viz_manager