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
local simdefs = include( "sim/simdefs" )
include("class")

-----------------------------------------------------------------------------------
-- Local

local idle_state = class( unitrig.base_state )

function idle_state:init( rig )
	unitrig.base_state.init( self, rig, "idle" )
end

function idle_state:onEnter()
	local unit = self._rig:getUnit()  
	
	local state = "idle"
	
	if unit:getTraits().mainframe_status == "off" then
		state = "idle_off"
	end

	self._rig:setCurrentAnim( state )	
end

-------------------------------------------------------------

local consolerig = class( unitrig.rig )

function consolerig:init( boardRig, unit )
	self:_base().init( self, boardRig, unit )

	self._idleState = idle_state( self )
	self:transitionUnitState( self._idleState )
	
end

function consolerig:refresh()
	self:transitionUnitState( nil )
	self:transitionUnitState( self._idleState )

	unitrig.rig.refresh(self)
	local unit = self:getRawUnit()

	if unit then

		local dir = unit:getFacing()
		local orientation = self._boardRig._game:getCamera():getOrientation()
		if self._actionhilite then
			--self._actionhilite:setCurrentFacingMask( 2^((dir - orientation*2) % simdefs.DIR_MAX) )
		end
 
		if self._spotSound and (unit:getTraits().cpus <= 0 or unit:getTraits().mainframe_status == "off" or (unit:getTraits().mainframe_console_lock and unit:getTraits().mainframe_console_lock > 0))  then
			self:refreshSpotSound(true)
		end

		if unit:getTraits().mainframe_status == "off" then
			self._prop:setSymbolVisibility( "red", false )
			self._prop:setSymbolVisibility( "teal", false )
		elseif unit:getTraits().mainframe_console_lock and unit:getTraits().mainframe_console_lock > 0 then
			self._prop:setSymbolVisibility( "red", false )
			self._prop:setSymbolVisibility( "teal", false )
		else
			-- If has CPUs, the console is "red" because it's hackable
			if unit:getTraits().cpus > 0 then  
				self._prop:setSymbolVisibility( "red", true )
				self._prop:setSymbolVisibility( "teal", false )	
			else
			--	self._actionhilite:setVisible(false)
				self._prop:setSymbolVisibility( "red", false )
				self._prop:setSymbolVisibility( "teal", true )
			end		
		end

	end
end


return
{
	rig = consolerig,
}

