----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources" )
local util = include( "client_util" )
local cdefs = include( "client_defs" )
local array = include( "modules/array" )
local gameobj = include( "modules/game" )
local mui_defs = include( "mui/mui_defs")

--------------------------------------------------------------------
--


-----------------------------------------------------------------------------------------
--

local combat_panel = class()

function combat_panel:init( hud, screen )
	self._hud = hud
	self._screen = screen
	self._panel = screen.binder.combatPanel

	self:refreshPanel( nil )
end

function combat_panel:setPosition( x0, y0 )
	local width,height = self._screen:getResolution()
	local offset = 100/width 
	if x0 > 0.60 then
		offset=  - 100/width
	end
	y0 = math.min(math.max(y0,0.2),0.7)
	self._panel:setPosition(x0-0.5+ offset,y0-0.2)
end

function combat_panel:refreshPanel( weaponUnit, unit, targetUnit )
	-- Refreshes the entire panel with information about 'unit'.  If unit == nil, this implies hiding the panel.
	local sim = self._hud._game.simCore

	if not unit or not targetUnit then
		self._panel:setVisible( false )
		return
	end

	self._panel:setVisible( true )

	local shot = sim:getQuery().calculateShotSuccess( sim, unit, targetUnit, weaponUnit )
	
	local damType = " DAMAGE"
	if shot.ko then
		damType = " KO"
	end	

	local baseDamageFinal = shot.damage

	local immune = false 

	if shot.ko and not targetUnit:getTraits().canKO then 
		immune = true 
	end 

	if weaponUnit:getTraits().canTag then
		self._panel.binder.damageTxt:setText("TAG")
	elseif immune then 
		self._panel.binder.damageTxt:setText("IMMUNE")		
	elseif shot.armorBlocked then 
		self._panel.binder.damageTxt:setText("ARMORED")
	elseif shot.ko then
		self._panel.binder.damageTxt:setText(baseDamageFinal .. damType)
	else 
		self._panel.binder.damageTxt:setText("KILL")
	end

	if targetUnit:getTraits().neutralize_shield then 
		if targetUnit:getTraits().neutralize_shield > 0 then 
			self._panel.binder.damageTxt:setText("REDUCE SHIELDS")
		end
	end
end

return combat_panel

