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
local agentrig = include( "gameplay/agentrig" )
local coverrig = include( "gameplay/coverrig" )
local world_hud = include( "hud/hud-inworld" )
local flagui = include( "hud/flag_ui" )
local simdefs = include( "sim/simdefs" )
local simquery = include( "sim/simquery" )

--------------------------------------------------------------------
-- dronerig

local dronerig = class( agentrig.rig )

function dronerig:init( boardRig, unit )
	agentrig.rig.init( self, boardRig, unit )

	self._HUDscan = self:createHUDProp("kanim_hud_drone_scan", "character", "idle", boardRig:getLayer("ceiling"), self._prop )	
	self._HUDscan:setVisible(false)	
end

function dronerig:destroy()
	agentrig.rig.destroy( self )
	self._boardRig:getLayer("ceiling"):removeProp( self._HUDscan )
end

function dronerig:onSimEvent( ev, eventType, eventData )
	if eventType == simdefs.EV_UNIT_RELOADED then
		return true -- Drones don't do a reload sequence.
	elseif eventType == simdefs.EV_UNIT_LOOKAROUND then
		return true -- Drones don't do a lookaround.
	elseif eventType == simdefs.EV_UNIT_PEEK then
		return true -- Drones don't do a peek sequence.
	elseif eventType == simdefs.EV_UNIT_STOP_WALKING and self:getUnit():getTraits().camera_drone then
		return true -- Caemera drones don`t stop walking
	end

	agentrig.rig.onSimEvent( self, ev, eventType, eventData )
end

function dronerig:refresh()
	agentrig.rig.refresh( self )

	local unit = self:getUnit()

	if unit:getTraits().isAiming then
		if  not unit:getPlayerOwner():isPC()  then		
			self._HUDscan:setSymbolModulate("camera_ol1",1, 0.5, 0.5, 1 )
			self._HUDscan:setSymbolModulate("camera_ol_line",1, 0, 0, 1 )
		else
			self._HUDscan:setSymbolModulate("camera_ol1",0.5, 1, 1, 1 )
			self._HUDscan:setSymbolModulate("camera_ol_line",0, 1, 1, 1 )
		end	

		local orientation = self._boardRig._game:getCamera():getOrientation()* 2
		local facing = unit:getFacing() - orientation 
		if facing < 0 then 
			facing = facing - 8
		end
		self._HUDscan:setVisible(true)

		self._HUDscan:setCurrentAnim("idle_"..facing)

	else
		self._HUDscan:setVisible(false)
	end
end

return
{
	rig = dronerig,
}

