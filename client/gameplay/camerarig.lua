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
	if unit:getTraits().mainframe_status == "off" then
		state = "idle_off"
	end

	self._rig:setCurrentAnim( state )
end

-------------------------------------------------------------

local camerarig = class( unitrig.rig )

function camerarig:init( boardRig, unit )
	self:_base().init( self, boardRig, unit )

	simdefs = boardRig:getSim():getDefs()
	simquery = boardRig:getSim():getQuery()

	self._idleState = idle_state( self )	
	self:transitionUnitState( self._idleState )

	self._HUDscan = self:createHUDProp("kanim_hud_fx", "camera_ol", "idle_2", boardRig:getLayer("ceiling"), self._prop )
	self._HUDalarm = self:createHUDProp("kanim_camera_overlay_alarm", "alarm_light", "alarm", boardRig:getLayer("ceiling"), self._prop )
	self._HUDalarm:setSymbolModulate("alarm_light_1",1, 0, 0, 1 )
	self._HUDalarm:setSymbolModulate("alarm_light_cone",1, 0, 0, 1 )
	self._HUDalarm:setVisible(false)
	self._HUDscan:setVisible(true)

	self._HUDthought = self:createHUDProp("kanim_hud_agent_hud", "record", "recording", boardRig:getLayer("ceiling"), self._prop )
end

function camerarig:destroy()
	self:_base().destroy( self )
	self._boardRig:getLayer("ceiling"):removeProp(self._HUDthought )
	self._boardRig:getLayer("ceiling"):removeProp(self._HUDalarm )
	self._boardRig:getLayer("ceiling"):removeProp(self._HUDscan )
end

function camerarig:onUnitAlerted( viz, eventData )
	viz:spawnViz( function( thread, eventData )
		thread:unblock()
		local unit = self:getUnit()
		self._boardRig._game:cameraPanToCell( unit:getLocation() )

		self._HUDthought:setCurrentAnim("alert")

		self._HUDthought:setListener( KLEIAnim.EVENT_ANIM_END,			
			function( anim, animname )
				if animname == "alert" then
					anim:setCurrentAnim("recording")
				end
			end )			
		
		self._HUDalarm:setVisible(true)
		self._boardRig:wait( 60 )
		self._HUDalarm:setVisible(false)
	end )
end

function camerarig:refresh()
	self:transitionUnitState( nil )
	self:transitionUnitState( self._idleState )
	self:_base().refresh( self )

	local unit = self._boardRig:getLastKnownUnit( self._unitID )
	local playerOwner = unit:getPlayerOwner()

	--if self._HUDscan then
		local orientation = self._boardRig._game:getCamera():getOrientation()* 2
		local facing = unit:getFacing() - orientation 
		if facing < 0 then 
			facing = facing - 8
		end
		self._HUDscan:setVisible(true)
		self._HUDscan:setCurrentAnim("idle_"..facing)
	--end
	self._HUDthought:setVisible(false)
	self._HUDalarm:setVisible(false)

	if unit:getTraits().mainframe_status == "off" or unit:getTraits().powering == true then
		if self._HUDIce then
			self._HUDIce:setVisible(false)
		end			
		self._prop:setSymbolVisibility( "red", "teal", false )
		self._HUDscan:setSymbolVisibility("camera_ol1", "camera_ol_line", false)

		self._HUDalarm:setVisible(false)
		if unit:getTraits().powering == true then
			self._HUDalarm:setVisible(true)
			if playerOwner and not playerOwner:isNPC() then		
				self._HUDalarm:setSymbolModulate("alarm_light_cone",0.5, 1, 1, 1 )
			end
		end

	else
		if playerOwner == nil or playerOwner:isNPC() then		
			self._prop:setSymbolVisibility( "red", true )
			self._prop:setSymbolVisibility( "teal", false )
			self._HUDscan:setSymbolModulate("camera_ol1",1, 0.5, 0.5, 1 )
			self._HUDscan:setSymbolModulate("camera_ol_line",1, 0, 0, 1 )
		else
			self._prop:setSymbolVisibility( "red", false )
			self._prop:setSymbolVisibility( "teal", true )
			self._HUDscan:setSymbolModulate("camera_ol1",0.5, 1, 1, 1 )
			self._HUDscan:setSymbolModulate("camera_ol_line",0, 1, 1, 1 )
		end	

		self._HUDscan:setSymbolVisibility("camera_ol1", "camera_ol_line", true)

		if  unit:getTraits().tracker_alert == true then		
			self._HUDthought:setVisible(true)
		end		
	end	
	


	
end

return
{
	rig = camerarig,
}

