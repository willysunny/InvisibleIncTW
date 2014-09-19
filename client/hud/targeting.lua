----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local cdefs = include( "client_defs" )
local array = include( "modules/array" )
local mui_defs = include( "mui/mui_defs")
local world_hud = include( "hud/hud-inworld" )
local simquery = include( "sim/simquery" )

------------------------------------------------------------------------------
-- Local functions
------------------------------------------------------------------------------

---------------------------------------------------------------------
-- Simple Cell targeting. 

local simpleCellTarget = class()

function simpleCellTarget:init( game, range, sim )
	self._game = game
	self.sim = sim 
	self._hiliteClr = { 0.5, 0.5, 0.5, 0.5 }
	self.mx = nil
	self.my = nil
	self.range = range
end

function simpleCellTarget:hasTargets()
	return true
end

function simpleCellTarget:onInputEvent( event )
	if event.eventType == mui_defs.EVENT_MouseDown and event.button == mui_defs.MB_Left then
		local cellx, celly = self._game:wndToSubCell( event.wx, event.wy )
		return {math.floor(cellx), math.floor(celly)}
	elseif event.eventType == mui_defs.EVENT_MouseMove then
		local x, y = self._game:wndToSubCell( event.wx, event.wy )	
		self.mx, self.my = math.floor(x), math.floor(y)
	end
end

function simpleCellTarget:onDraw()
	local simquery = self.sim:getQuery()
	MOAIGfxDevice.setPenColor(unpack(self._hiliteClr))
	if self.range and self.mx and self.my then
		local cells = simquery.rasterCircle( self.sim, self.mx, self.my, self.range )
		for i = 1, #cells, 2 do
            local x, y = cells[i], cells[i+1]
			local x0, y0 = self._game:cellToWorld( x + 0.4, y + 0.4 )
			local x1, y1 = self._game:cellToWorld( x - 0.4, y - 0.4 )
			MOAIDraw.fillRect( x0, y0, x1, y1 )
		end
	end
end

function simpleCellTarget:getDefaultTarget()
	return nil
end

---------------------------------------------------------------------
-- Cell targeting.

local cellTarget = class()

function cellTarget:init( game, cells, ability, abilityOwner, abilityUser )
	self._game = game
	self._hiliteClr = { 0, 1, 0, 0.8 }
	self._cells = cells
	self._ability = ability
	self._abilityOwner = abilityOwner
	self._abilityUser = abilityUser
end

function cellTarget:hasTargets()
	return #self._cells > 0
end

function cellTarget:getDefaultTarget()
	if #self._cells == 1 then
		return { self._cells[1].x, self._cells[1].y }
	end

	return nil
end

function cellTarget:onInputEvent( event )
end

function cellTarget:startTargeting( cellTargets )
	local agent_panel = include( "hud/agent_panel" )
	local sim = self._game.simCore
	for i, cell in ipairs( self._cells ) do
		local wx, wy = self._game:cellToWorld( cell.x, cell.y )
		wx, wy = cellTargets:findLocation( wx, wy )
		local widget = self._game.hud._world_hud:createWidget( world_hud.HUD, "Target", {  worldx = wx, worldy = wy, worldz = 0 } )
		agent_panel.updateButtonFromAbilityTarget( self._game.hud._agent_panel, widget, self._ability, self._abilityOwner, self._abilityUser, { cell.x, cell.y } )
	end
end

function cellTarget:endTargeting( hud )
	hud._world_hud:destroyWidgets( world_hud.HUD )
end

function cellTarget:onDraw()
	MOAIGfxDevice.setPenColor(unpack(self._hiliteClr))

	for i,cell in ipairs(self._cells) do 
		local x0, y0 = self._game:cellToWorld( cell.x + 0.4, cell.y + 0.4 )
		local x1, y1 = self._game:cellToWorld( cell.x - 0.4, cell.y - 0.4 )
		MOAIDraw.fillRect( x0, y0, x1, y1 )
	end
end


---------------------------------------------------------------------
-- Exit targeting.

local exitTarget = class()

function exitTarget:init( game, exits, ability, abilityOwner, abilityUser )
	self._game = game
	self._exits = exits
	self._ability = ability
	self._abilityOwner = abilityOwner
	self._abilityUser = abilityUser
end

function exitTarget:hasTargets()
	return #self._exits > 0
end

function exitTarget:getDefaultTarget()
	return nil
end

function exitTarget:onInputEvent( event )
end

function exitTarget:startTargeting( cellTargets )
	local agent_panel = include( "hud/agent_panel" )
	local sim = self._game.simCore
	for i, exit in ipairs( self._exits ) do
		local dx, dy = simquery.getDeltaFromDirection( exit.dir )
		local x1, y1 = exit.x + dx, exit.y + dy
		local wx, wy = self._game:cellToWorld( (exit.x + x1)/2, (exit.y + y1)/2 )
		wx, wy = cellTargets:findLocation( wx, wy )
		local widget = self._game.hud._world_hud:createWidget( world_hud.HUD, "Target", {  worldx = wx, worldy = wy, worldz = 36, layoutID = string.format( "%d,%d-%d", exit.x, exit.y, exit.dir ) } )
		agent_panel.updateButtonFromAbilityTarget( self._game.hud._agent_panel, widget, self._ability, self._abilityOwner, self._abilityUser )
	end
end

function exitTarget:endTargeting( hud )
	hud._world_hud:destroyWidgets( world_hud.HUD )
end

---------------------------------------------------------------------
-- Direction targeting.

local directionTarget = class()

function directionTarget:init( game, x0, y0 )
	self._game = game
	self._x0, self._y0 = x0, y0
end

function directionTarget:hasTargets()
	return true
end

function directionTarget:getDefaultTarget()
	return nil
end

function directionTarget:onInputEvent( event )
	if (event.eventType == mui_defs.EVENT_MouseDown and event.button == mui_defs.MB_Left) or event.eventType == mui_defs.EVENT_MouseMove then
		local cellx, celly = self._game:wndToCell( event.wx, event.wy )
		if cellx and celly then
			local dx, dy = cellx - self._x0, celly - self._y0
			if dx ~= 0 or dy ~= 0 then
				local simquery = self._game.simCore:getQuery()
				self._target = simquery.getDirectionFromDelta( dx, dy )
				if event.eventType == mui_defs.EVENT_MouseDown then
					return self._target
				end
			end
		end
	end
end

function directionTarget:onDraw()
	if self._target then
		MOAIGfxDevice.setPenColor( 0, 1, 0 )

		local simquery = self._game.simCore:getQuery()
		local dx, dy = simquery.getDeltaFromDirection( self._target )
		local x0, y0 = self._game:cellToWorld( self._x0, self._y0 )
		local x1, y1 = self._game:cellToWorld( self._x0 + dx, self._y0 + dy )

		MOAIDraw.drawLine( x0, y0, x1, y1 )
	end
end

---------------------------------------------------------------------
-- Unit targeting.

local unitTarget = class()

function unitTarget:init( game, units, ability, abilityOwner, abilityUser, noDefault )
	self._game = game
	self._units = units
	self._noDefault = noDefault
	self._ability = ability
	self._abilityOwner = abilityOwner
	self._abilityUser = abilityUser
end

function unitTarget:hasTargets()
	return #self._units > 0
end

function unitTarget:getDefaultTarget()
	if not self._noDefault and #self._units == 1 then
		return self._units[1]:getID()
	end
	return nil
end


function unitTarget:startTargeting( cellTargets )
	local agent_panel = include( "hud/agent_panel" )
	local sim = self._game.simCore
	for i, unit in ipairs( self._units ) do
		local cell = sim:getCell( unit:getLocation() )

		-- If targetting self in item-target mode, then the option shoudl go into the popup menu (eg. STIM)
		if unit == self._abilityUser and self._game.hud._state == self._game.hud.STATE_ITEM_TARGET then
			--local widget = self._game.hud._world_hud:createWidget( world_hud.HUD, "Target")
			local realAgentPanel = self._game.hud._agent_panel
			table.insert(realAgentPanel._popUps,{ ability = self._ability, abilityOwner = self._abilityOwner, abilityUser = self._abilityUser, unitID = unit:getID() })
			--agent_panel.updateButtonAbilityPopup( self._game.hud._agent_panel, widget, self._ability, self._abilityOwner, self._abilityUser, unit:getID() )
		else
			local wx, wy, wz = self._game:cellToWorld( cell.x, cell.y )
			wx, wy, wz = cellTargets:findLocation( wx, wy )
			local widget = self._game.hud._world_hud:createWidget( world_hud.HUD, "Target", {  worldx = wx, worldy = wy, worldz = wz, layoutID = unit:getID() } )
			agent_panel.updateButtonFromAbilityTarget( self._game.hud._agent_panel, widget, self._ability, self._abilityOwner, self._abilityUser, unit:getID() )
		end
	end
end

function unitTarget:endTargeting( hud )
	hud._world_hud:destroyWidgets( world_hud.HUD )
end

function unitTarget:onInputEvent( event )
end

function unitTarget:onDraw()
	MOAIGfxDevice.setPenColor( 0.1, 0.88, 0.23 )
	for i,unit in ipairs(self._units) do
		local cx, cy = unit:getLocation()
		local x0, y0 = self._game:cellToWorld( cx + 0.4, cy + 0.4 )
		local x1, y1 = self._game:cellToWorld( cx - 0.4, cy - 0.4 )
		MOAIDraw.fillRect( x0, y0, x1, y1 )
	end
end

return
{	
	simpleCellTarget = simpleCellTarget, 
	cellTarget = cellTarget,
	exitTarget = exitTarget,
	directionTarget = directionTarget,
	unitTarget = unitTarget,
}
