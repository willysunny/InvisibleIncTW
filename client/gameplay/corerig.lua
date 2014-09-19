----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources" )
local animmgr = include( "anim-manager" )
local util = include( "client_util" )
local cdefs = include( "client_defs" )
local mathutil = include( "modules/mathutil" )
local binops = include( "modules/binary_ops" )
local unitrig = include( "gameplay/unitrig" )
include("class")

-----------------------------------------------------------------------------------
-- Local

local simdefs = nil -- Lazy initialized after the sim is mounted.
local simquery = nil -- Lazy initialized after the sim is mounted.

-------------------------------------------------------------

local idle_state = class( unitrig.base_state )

function idle_state:init( rig )
	unitrig.base_state.init( self, rig, "idle" )
end

function idle_state:onEnter()
	local unit = self._rig:getUnit()
	local state = "idle"

	if unit:getTraits().open and unit:getTraits().open == true then
		state = "open"
	elseif unit:getTraits().mainframe_status == "off" then
		state = "idle_off"
	end

	self._rig:setCurrentAnim( state )
end

local corerig = class( unitrig.rig )

function corerig:init( boardRig, unit )
	self:_base().init( self, boardRig, unit )

	simdefs = boardRig:getSim():getDefs()
	simquery = boardRig:getSim():getQuery()

	self._idleState = idle_state( self )
	self:transitionUnitState( self._idleState )

	self._prop:setSymbolVisibility( "glow", "red", false )		
end

function corerig:onSimEvent( ev, eventType, eventData )
	self:_base().onSimEvent( self, ev, eventType, eventData )
end

function corerig:refresh()
	self:transitionUnitState( nil )
	self:transitionUnitState( self._idleState )
	self:_base().refresh( self )

	local unit = self._boardRig:getLastKnownUnit( self._unitID )
	local playerOwner = unit:getPlayerOwner()

	local artifact = false

	for i,childunit in ipairs (unit:getChildren()) do
		if childunit:getName() == "Cultural Artifact" then
			artifact= true
		end
	end

	if artifact == true then
		self._prop:setSymbolVisibility( "loot", true )
	else
		self._prop:setSymbolVisibility( "loot", false )
	end


	if unit:getTraits().mainframe_status == "off" then
		if self._HUDIce then
			self._HUDIce:setVisible(false)
		end

		self._prop:setSymbolVisibility( "red", "internal_red", "ambientfx", "teal", false )
	else
		if playerOwner == nil or playerOwner:isNPC() then		
			self._prop:setSymbolVisibility( "red", true )
			self._prop:setSymbolVisibility( "teal", false )
		else
			self._prop:setSymbolVisibility( "red", false )
			self._prop:setSymbolVisibility( "teal", true )
		end	
	end	
end

return
{
	rig = corerig,
}

