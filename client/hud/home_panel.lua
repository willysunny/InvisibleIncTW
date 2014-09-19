----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local cdefs = include( "client_defs" )
local array = include( "modules/array" )
local mui_defs = include( "mui/mui_defs")
local mui_tooltip = include( "mui/mui_tooltip")
local agent_panel = include( "hud/agent_panel" )
local simquery = include( "sim/simquery" )

------------------------------------------------------------------------------
-- Local functions


local function onClickMainframeBtn( hud , player)
	hud:onClickMainframeBtn()
end

local function generateAgentTooltip( hud, unit )
	return mui_tooltip( unit:getName(), unit:getUnitData().toolTip, "TAB (cycle selection)" )
end

local function generateMainframeTooltip( hud )
	return mui_tooltip( "INCOGNITA", "Hack electronics by utilizing INCOGNITA", "SPACE" )
end

local function onClickUnitBtn( panel, unit )
	if not unit._isPlayer and unit:getLocation() ~= nil then
		panel._hud._game:cameraPanToCell( unit:getLocation() )	
	end
	panel._hud:selectUnit( unit )	
end

------------------------------------------------------------------------------

local panel = class()

function panel:init( screen, hud )
	self._hud = hud
	self._panel = screen.binder.homePanel
	self:refresh()
end

function panel:findAgentWidget( unitID )
	local localPlayer = self._hud._game:getLocalPlayer()
	if not localPlayer or localPlayer:isNPC() then
		return
	end
	local simquery = include( "sim/simquery" )

	local j = 2
	for i,unit in ipairs(localPlayer:getUnits()) do
		if localPlayer:findAgentDefByID( unit:getID() ) then
			if unit:getID() == unitID then
				return self._panel.binder:tryBind( "agent" .. j )
			else
				j = j + 1
			end
		end
	end

	return nil
end


function panel:refreshAgent( unit )
	local widget = self:findAgentWidget( unit:getID() )
	if widget == nil then
		return
	end

	-- Updates the agent information for the current unit (profile image, brief info text)
	widget.binder.agentProfile:setImage( unit:getUnitData().profile_icon_36x36 )
	widget.binder.agentProfile:setColor(1,1,1,1)

	widget.binder.btn:setTooltip( generateAgentTooltip( self._hud, unit ) )
	widget.binder.btn.onClick = util.makeDelegate( nil, onClickUnitBtn, self, unit )
	widget.binder.selected:setVisible( self._hud:getSelectedUnit() == unit )					
	widget.binder.border:setVisible(true)

	local clr = cdefs.AP_COLOR_NORMAL
	local ap = unit:getMP()
	if self._hud._movePreview and self._hud._movePreview.unitID == unit:getID() and ap > self._hud._movePreview.pathCost then
		clr = cdefs.AP_COLOR_PREVIEW
		ap = ap - self._hud._movePreview.pathCost
	end

	widget.binder.apTxt:setColor( clr:unpack() )
	widget.binder.apTxt:setVisible( true )
	widget.binder.apNum:setColor( clr:unpack() )
	widget.binder.apNum:setVisible( true )
	widget.binder.apNum:setText( math.floor( ap ))

	if not self._hud:canShowElement( "agentSelection" ) or self._hud._isMainframe == true then
		widget:setVisible( false )
	else	
		widget:setVisible( true )
	end
end


function panel:refresh()
	local localPlayer = self._hud._game:getLocalPlayer()

	for j, agentGrp in self._panel.binder:forEach( "agent" ) do
		agentGrp:setVisible( false )
	end

	if not localPlayer or localPlayer:isNPC() then
		return
	end

	-- INCOGNITA
	local item = self._panel.binder[ "agent1" ]
	-- Updates the agent information for the current unit (profile image, brief info text)
	if self._hud._isMainframe == true then		
		item.binder.plate.binder.agentProfile:setImage("gui/hud3/hud3_mainframe_icon_sm_inverse.png") --gui/icons/item_icons/items_icon_small/icon-item_oravirus_small.png" 
	else	
		item.binder.plate.binder.agentProfile:setImage("gui/hud3/hud3_mainframe_icon_sm.png") --gui/icons/item_icons/items_icon_small/icon-item_oravirus_small.png" 
	end

	--item.binder.plate.binder.agentProfile:setColor(247/255,127/255,14/255,1)
	item.binder.plate.binder.agentProfile:setColor(140/255,255/255,255/255,1)
	item.binder.border:setVisible(false)
	item:setAlias("mainframe")


	item.binder.apTxt:setVisible(false)
	item.binder.apNum:setVisible(false)

	item.binder.btn:setTooltip( generateMainframeTooltip( self._hud ) )
	item.binder.btn:setHotkey( string.byte(' ') )
	item.binder.btn.onClick = util.makeDelegate( nil, onClickMainframeBtn, self._hud,localPlayer)
	item.binder.selected:setVisible( self._hud:getSelectedUnit() == localPlayer )

	item:setVisible( self._hud:canShowElement( "mainframe" ) )

	--AGENTS	
	for i,unit in ipairs(localPlayer:getUnits()) do
		if localPlayer:findAgentDefByID( unit:getID() ) then
			self:refreshAgent( unit )
		end
	end
end

return
{
	panel = panel
}

