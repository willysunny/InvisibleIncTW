----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local cdefs = include( "client_defs" )
local mathutil = include( "modules/mathutil" )
local unitrig = include( "gameplay/unitrig" )
include("class")

-----------------------------------------------------------------------------------
-- Local

local active_state = class( unitrig.base_state )

function active_state:init( rig )
	unitrig.base_state.init( self, rig, "active" )
end

function active_state:onEnter()
	self._rig:setCurrentAnim( "idle" )
	--MOAIFmodDesigner.playSound( "SpySociety/Objects/laser", tostring(self._rig._unitID), nil, { self._rig._x, self._rig._y } )
end

function active_state:onExit()
	--MOAIFmodDesigner.stopSound( tostring(self._rig._unitID) )
end

-------------------------------------------------------------

local inactive_state = class( unitrig.base_state )
    
function inactive_state:init( rig )
	unitrig.base_state.init( self, rig, "inactive" )
end

function inactive_state:onEnter()
	self._rig:setCurrentAnim( "idle" )
	--MOAIFmodDesigner.playSound( "SpySociety/Objects/laser", tostring(self._rig._unitID), nil, { self._rig._x, self._rig._y } )
end

function inactive_state:onExit()
	--MOAIFmodDesigner.stopSound( tostring(self._rig._unitID) )
end

-------------------------------------------------------------

local off_state = class( unitrig.base_state )
    
function off_state:init( rig )
	unitrig.base_state.init( self, rig, "off" )
end

function off_state:onEnter()
	self._rig:setCurrentAnim( "idle_off" )

	--MOAIFmodDesigner.playSound( "SpySociety/Objects/laser", tostring(self._rig._unitID), nil, { self._rig._x, self._rig._y } )
end

function off_state:onExit()
	--MOAIFmodDesigner.stopSound( tostring(self._rig._unitID) )
end


-------------------------------------------------------------

local laserrig = class( unitrig.rig )

function laserrig:init( boardRig, unit )
	self:_base().init( self, boardRig, unit )

	self._prop:setSymbolVisibility( "glow", false ) -- Can we remove this??

	self._activeState = active_state( self )
	self._inactiveState = inactive_state( self )
	self._offState = off_state( self )
	self:transitionUnitState( self._inactiveState )
end

function laserrig:refresh()
	self:transitionUnitState( nil )

	local unit = self._boardRig:getLastKnownUnit( self._unitID )
	local state =  self._activeState
			
	if unit:getTraits().mainframe_status  == "off" then

		if self._HUDIce then
			self._HUDIce:setVisible(false)
		end		
		state = self._offState 

	elseif unit:getTraits().mainframe_status  == "inactive" then
		state = self._inactiveState
	end


	self:transitionUnitState( state )

	self:_base().refresh( self )	
end

return
{
	rig = laserrig,
}

