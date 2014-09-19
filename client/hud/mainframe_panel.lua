----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local mathutil = include( "modules/mathutil" )
local cdefs = include( "client_defs" )
local array = include( "modules/array" )
local mui_defs = include( "mui/mui_defs")
local world_hud = include( "hud/hud-inworld" )
local hudtarget = include( "hud/targeting")
local rig_util = include( "gameplay/rig_util" )
local level = include( "sim/level" )
local mainframe = include( "sim/mainframe" )
local simquery = include( "sim/simquery" )
local simdefs = include( "sim/simdefs" )

local MODE_HIDDEN = 0
local MODE_VISIBLE = 1

local BREAKICE_COLOR_TT = util.color( 0, 0.5, 0.8, 0.3 ) -- Tooltip color of break ice lines

------------------------------------------------------------------------------
-- Local functions

local function setFirewallIdleAnim( widget, unit )
	if unit:getTraits().parasite then
		widget.binder.anim:setAnim( "idle_bugged" )
	else
		widget.binder.anim:setAnim( "idle" )
	end
end

local breakIceThread = class()

function breakIceThread:init( mainframePanel, widget, unit )
	self.widget = widget
	self.unit = unit
	self.mainframePanel = mainframePanel
	self.currentIce = unit:getTraits().mainframe_ice

	self.thread = MOAICoroutine.new()
	self.thread:run( self.run, self )
end

function breakIceThread:destroy()
	local targetIce = self.unit:getTraits().mainframe_ice

	setFirewallIdleAnim( self.widget, self.unit )

	self.widget.binder.firewallNum:setText( targetIce )

	self.widget.iceBreak = nil

	self.thread:stop()
	self.thread = nil
end

function breakIceThread:breakIce()
	local delta = self.unit:getTraits().mainframe_ice - self.currentIce
	if delta == 0 then
		return false
	end
	local anim = self.widget.binder.anim:getProp()

	MOAIFmodDesigner.playSound("SpySociety/HUD/mainframe/ice_deactivate")

	if delta > 0 then
		self.currentIce = self.currentIce + 1
		self.widget.binder.firewallNum:setText( self.currentIce )
		rig_util.waitForAnim( anim, "in" )
	else
		self.currentIce = self.currentIce  - 1
		self.widget.binder.firewallNum:setText( self.currentIce )
		rig_util.waitForAnim( anim, "out" )
	end

	return true
end

function breakIceThread:run()
	while self.unit:isValid() and self:breakIce() do
		-- Continue breaking ice...
		coroutine.yield()
	end

	if self.currentIce <= 0 then
		self.mainframePanel._hud._world_hud:destroyWidget( world_hud.MAINFRAME, self.widget )
	else
		self:destroy()
	end
end




local function destroyIceWidget( widget )
	if widget.iceBreak then
		widget.iceBreak:destroy()
		widget.iceBreak = nil
	end
end

local function findWidget( widgets, unit )
	for _, widget in ipairs( widgets ) do		
		if widget.ownerID == unit:getID() then
			return widget
		end
	end

	return nil
end

local breakIceTooltip = class( util.tooltip )

function breakIceTooltip:init( mainframePanel, iceWidget, unit, reason )
	util.tooltip.init( self, mainframePanel._hud._screen )
	self._iceWidget = iceWidget
	self.mainframePanel = mainframePanel

	local localPlayer = mainframePanel._hud._game:getLocalPlayer()

	if localPlayer then
		local equippedProgram = localPlayer:getEquippedProgram()	
		if equippedProgram then
			local programWidget = mainframePanel._panel.binder.programsPanel:findWidget( equippedProgram:getID() )		
			self._ux0, self._uy0 = programWidget.binder.btn:getAbsolutePosition()
		end
	end

	local section = self:addSection()
	section:addLine( "HACK "..unit:getName(), util.toupper( unit:getTraits().mainframe_status ))

	if unit:getTraits().trading_market then 
		section:addLine( "VALUE: "..unit:getTraits().credits )
	end

	if unit:getTraits().parasite then 
		section:addLine( "PARASITE HOSTED" )
	end

	if unit:getTraits().mainframe_program then
		section:addRequirement( "DAEMON PROGRAM" )
		local npc_abilities = include( "sim/abilities/npc_abilities" )
		local ability = npc_abilities[ unit:getTraits().mainframe_program ]
		if unit:getTraits().daemon_sniffed then 
			section:addAbility( string.format( ability.name ), ability.desc, ability.icon )
		else
			section:addAbility( string.format( "HIDDEN DAEMON" ), "?????????", "gui/items/item_quest.png" )
		end
	end

	if reason then
		section:addRequirement( reason )
	end
end

function breakIceTooltip:drawLine( x0, y0, x1, y1 )
	x0, y0 = self._iceWidget:getScreen():wndToUI( x0, y0 )
	x1, y1 = self._iceWidget:getScreen():wndToUI( x1, y1 )
	MOAIDraw.drawLine( x0, y0, x1, y0 )
	MOAIDraw.drawLine( x1, y0, x1, y1 )
end

function breakIceTooltip:onDraw()
	local screen = self._iceWidget:getScreen()
	if screen then
		local x0, y0 = self._ux0 - 0.5, self._uy0 - 0.5
		local x1, y1 = self._iceWidget.binder.btn:getAbsolutePosition()
		x1, y1 = x1 - 0.5, y1 - 0.5
		x0, y0 = screen:uiToWnd( x0, y0 )
		x1, y1 = screen:uiToWnd( x1, y1 )

		--self:drawLine( x0, y0 + 2, x1 + 2, y1 )
		self:drawLine( x0, y0, x1, y1 )
		--self:drawLine( x0, y0 - 2, x1 - 2, y1 )
	end
end

function breakIceTooltip:activate( screen )
	util.tooltip.activate( self, screen )
	if self._ux0 and self._uy0 then
		table.insert( self.mainframePanel._iceBreaks, self )
	end
end

function breakIceTooltip:deactivate()
	if self._ux0 and self._uy0 then
		array.removeElement( self.mainframePanel._iceBreaks, self )
	end
	util.tooltip.deactivate( self )
end

local function createActivateTooltip( hud, unit, useData )
	local tooltip = util.tooltip( hud._screen )
	local section = tooltip:addSection()

	section:addLine( unit:getName(), util.toupper( unit:getTraits().mainframe_status ))
	section:addAbility( useData.name, useData.tooltip, "gui/items/swtich.png" )
	return tooltip
end

local function createBreakIceButton( panel, widgets, unit )
	local sim = panel._hud._game.simCore
	local canUse, reason = mainframe.canBreakIce( sim, unit )
	local wx, wy = panel._hud._game:cellToWorld( unit:getLocation() )
	local widget = findWidget( widgets, unit )
	if widget == nil then
		local wz = 12
		if unit:getTraits().breakIceOffset then
			wz = unit:getTraits().breakIceOffset
		end
		widget = panel._hud._world_hud:createWidget( world_hud.MAINFRAME, "BreakIce", { worldx = wx, worldy = wy, worldz = wz, ownerID = unit:getID() }, nil, destroyIceWidget )
	else
		array.removeElement( widgets, widget )
	end

	widget.binder.btn:setTooltip( breakIceTooltip( panel, widget, unit, reason ))
	widget.binder.btn:setDisabled( not canUse )   
	if not canUse then		
		widget.binder.anim:getProp():setRenderFilter( cdefs.RENDER_FILTERS["desat"] )
	else
		widget.binder.anim:getProp():setRenderFilter( cdefs.RENDER_FILTERS["normal"] )
	end
	widget.binder.btn.onClick = 
		function( widget, ie )
			if (unit:getTraits().mainframe_ice or 0) > 0 then
				MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_MAINFRAME_CONFIRM_ACTION )

				local breakCost = 1
				if ie.button == mui_defs.MB_Right then
					breakCost = math.min( unit:getTraits().mainframe_ice, sim:getCurrentPlayer():getCpus() )	
				end
				panel._hud._game:doAction( "mainframeAction", {action = "breakIce", unitID = unit:getID(), cost = breakCost } )
			end
		end
	widget.binder.firewallNum:setText(unit:getTraits().mainframe_ice)

	setFirewallIdleAnim( widget, unit )

	widget.binder.program.binder.daemonKnown:setVisible(false)
	widget.binder.program.binder.daemonUnknown:setVisible(false)

	if unit:getTraits().mainframe_program ~= nil then
		local npc_abilities = include( "sim/abilities/npc_abilities" )
		local ability = npc_abilities[ unit:getTraits().mainframe_program ]
		widget.binder.program.binder.daemonUnknown:setVisible(true)

		if unit:getTraits().daemon_sniffed then 
			widget.binder.program.binder.daemonUnknown:setVisible(false)
			widget.binder.program.binder.daemonKnown:setVisible(true)
			if unit:getTraits().daemon_sniffed_revealed == nil then
				unit:getTraits().daemon_sniffed_revealed = true
				widget.binder.program.binder.daemonKnown.binder.txt:spoolText(ability.name, 12)			
			else
				widget.binder.program.binder.daemonKnown.binder.txt:setText(ability.name)			
			end
		end	
	end

	return widget
end


local function drawIceBreakers( panel )
	MOAIGfxDevice.setPenColor( BREAKICE_COLOR_TT:unpack() )

	for i, iceBreak in ipairs( panel._iceBreaks ) do
		iceBreak:onDraw()
	end
end

local function createActivateButton( panel, unit, useName, useData, useIndex )
	local sim = panel._hud._game.simCore
	local wx, wy = panel._hud._game:cellToWorld( unit:getLocation() )
	local widget = panel._hud._world_hud:createWidget( world_hud.MAINFRAME, "Activate", { worldx = wx, worldy = wy, worldz = 16 * useIndex } )

	widget.binder.btn:setTooltip( createActivateTooltip( panel._hud, unit, useData ))
	widget.binder.btn.onClick = util.makeDelegate( nil,
		function() 
			MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_MAINFRAME_CONFIRM_ACTION )
			panel._hud._game:doAction( "mainframeAction", {action = "use", unitID = unit:getID(), fn = useData.fn } )
		end )
	widget.binder.label:setText( util.toupper(useData.name) )
	return widget
end

local function refreshBreakIce( panel )
	-- Mark and sweep.
	local widgets = util.tdupe( panel._hud._world_hud:getWidgets( world_hud.MAINFRAME ) or {} )

	local localPlayer = panel._hud._game:getLocalPlayer()
	if localPlayer then
		local sim = panel._hud._game.simCore
		if sim:getMainframeLockout() then
			panel._hud:showWarning( STRINGS.UI.REASON.INCOGNITA_LOCKED_DOWN, nil, nil, nil, true )
			MOAIFmodDesigner.playSound( "SpySociety/Actions/mainframe_deterrent_action" )
		end

		for _, unitRaw in pairs(sim:getAllUnits() ) do
			if unitRaw:getTraits().mainframe_item then
				local unit = localPlayer:getLastKnownUnit( sim, unitRaw:getID() )
				local canSee = sim:canPlayerSeeUnit( localPlayer, unit )
			
				if unit:getPlayerOwner() == sim:getCurrentPlayer() then
					if unit:getUnitData().uses_mainframe and unit:getTraits().mainframe_status ~= "off" then
						local i = 1
						for useName, useData in pairs(unit:getUnitData().uses_mainframe) do
							createActivateButton( panel, unit, useName, useData, i )
							i = i + 1
						end
					end		

				elseif unit:isGhost() or canSee then
					if (unitRaw:getTraits().mainframe_ice or 0) > 0 and unitRaw:getTraits().mainframe_status ~= "off" then
						if unitRaw:isKO() or sim:getCell( unitRaw:getLocation() ) ~= sim:getCell( unit:getLocation() ) then
							--Do nothing 
						else 
							createBreakIceButton( panel, widgets, unitRaw )
						end
					end
				end
			end
		end 
	end

	-- Sweep any widgets that no longer exist.
	for i, widget in ipairs(widgets) do
		if widget.iceBreak == nil then
			panel._hud._world_hud:destroyWidget( world_hud.MAINFRAME, table.remove( widgets ) )
		end
	end
end

local function onClickMainframeAbility( panel, ability, abilityOwner )
	panel._hud:transitionAbilityTarget( abilityOwner, abilityOwner, ability )
end

local function onClickDaemonIcon( panel )
	if not panel._hud._mainframeOn  then
		local sim = panel._hud._game.simCore 
		local player = sim:getCurrentPlayer()
		panel._hud:selectUnit( player )
	end
end

local function setDaemonPanel( self, widget, ability, player )

	local sim = self._hud._game.simCore
	local currentPlayer = sim:getCurrentPlayer()

	if widget.binder.view_mainframe.binder.switchBtn then
		widget.binder.view_mainframe.binder.switchBtn.onClick = util.makeDelegate( nil, onClickDaemonIcon, self )
	end

	widget.binder.view_mainframe:setVisible(true)

	widget = widget.binder.view_mainframe

	widget.binder.descTxt:setText( util.toupper( ability:getDef().name ) )
	widget.binder.descTxt:setVisible(true)

	if ability:getDef().icon then
		widget.binder.icon:setVisible(true)


		widget.binder.icon:setImage(  ability:getDef().icon )
	end

	if widget.binder.anim and ability:getDef().ice then
		widget.binder.anim:setVisible(true)
	
		if widget.ownerID ~= ability:getID() and widget.thread then
			widget.thread:stop()
			widget.thread = nil
		end

		widget.ownerID = ability:getID()

		setFirewallIdleAnim( widget, unit )
	else
		widget.binder.anim:setVisible(false)
	end

	widget.binder.bg:setVisible(true)
	widget.binder.bg:setTooltip( ability:onTooltip( self._hud, sim, player ) )
	
	if ability.turns then
		widget.binder.firewallNum:setVisible(true)				
		widget.binder.firewallNum:setText(ability.turns)									
		widget.binder.turnsTxt:setVisible(true)
	end
	if ability.duration then
		widget.binder.firewallNum:setVisible(true)
		widget.binder.firewallNum:setText(ability.duration)				
		widget.binder.turnsTxt:setVisible(true)
	end

	if ability:getDef().ice then
		widget.binder.firewallNum:setVisible(true)
		widget.binder.firewallNum:setText(ability:getDef().ice)
		widget.binder.turnsTxt:setVisible(false)
		widget.binder.btn:setVisible(true)
		widget.binder.btn:setTooltip( ability:onTooltip( self._hud, sim, player ) )
		widget.binder.btn:setDisabled( not ability:canUseAbility( sim, player ) )
		widget.ownerID = ability:getID()

		local canUse = true
		if currentPlayer ~= nil and currentPlayer:getCpus() < 1 then
			 canUse = false
		end
		widget.binder.btn:setDisabled( not canUse )
		if not canUse then		
			widget.binder.anim:getProp():setRenderFilter( cdefs.RENDER_FILTERS["desat"] )
		else
			widget.binder.anim:getProp():setRenderFilter( cdefs.RENDER_FILTERS["normal"] )
		end
		widget.binder.btn.onClick = 
			function( widget, ie )
				if sim:getCurrentPlayer() then
					MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_MAINFRAME_CONFIRM_ACTION )

					local breakCost = 1
					if ie.button == mui_defs.MB_Right then
						breakCost = math.min( ability.ice, sim:getCurrentPlayer():getCpus() )	
					end
					self._hud._game:doAction( "mainframeAction", {action = "breakIce",  cost = breakCost, ability = ability  } )
				end
			end			
	else
		widget.binder.btn:setVisible(false)
	end		

end



local function updateButtonFromProgram( self, widget, ability, abilityOwner, hotkey )
	local sim = self._hud._game.simCore

	local enabled, reason = ability:canUseAbility( sim, abilityOwner )

	widget:setVisible( true )

	if ability.equipped then 
		--EQUIPPTED
	else
		--NOT EQUIPPED
	end

	if ability.toggled then 
		-- TOGGLED
	else
		-- NOT TOGGLED
	end

		
	widget.binder.powerTxt:setVisible(true)
	if ability:getDef().firewallDisplay then	
		widget.binder.powerTxt:setText(ability:getDef().firewallDisplay)	
	elseif ability:getDef().break_firewalls then
		widget.binder.powerTxt:setText( ability:getDef().break_firewalls )	
	else
		widget.binder.powerTxt:setText("-")	
	end

	if ability:getDef().toggle_program then
		widget.binder.costTxt:setText( string.format( STRINGS.PROGRAMS.COST_PER_TURN, ability:getDef().cpu_cost or 0 ) )
	else
		widget.binder.costTxt:setText( string.format( STRINGS.PROGRAMS.COST, ability:getDef().cpu_cost or 0 ))
	end

	widget.binder.descTxt:setText( ability:getDef().huddesc )	

	if ability.cooldown then
		if ability.cooldown > 0 then 
			widget.binder.turnsTxt:setVisible(true)
			widget.binder.powerTxt:setVisible(true)
			widget.binder.powerTxt:setText( ability.cooldown )
		else
			widget.binder.turnsTxt:setVisible(false)
		end		
	else
		widget.binder.turnsTxt:setVisible(false)
	end

	if ability:getDef().cpu_cost then 
		for i, widget in widget.binder:forEach( "power" ) do	
			if i<=ability:getDef().cpu_cost then
				if ability.equipped or ability.toggled then 					
					widget:setColor(140/255,255/255,255/255)
				else
					widget:setColor(72/255,128/255,128/255)
				end
			else
				widget:setColor(17/255,29/255,29/255)
			end
		end
	else
		for i, widget in widget.binder:forEach( "power" ) do	
			widget:setColor(17/255,29/255,29/255)
		end
	end
	
	widget:setAlias( ability:getID() )
	widget.binder.btn:setTooltip( ability:onTooltip( self._hud, sim, abilityOwner ) )
	widget.binder.btn:setDisabled( not enabled )

	local WHITE = util.color( 255/255, 255/255, 255/255 )
	local LIGHT_BLUE = util.color( 140/255, 255/255, 255/255 )
	local DARK_BLUE = util.color( 34/255, 57/255, 57/255 )
	local GRAY = util.color( 0.5, 0.5, 0.5 )

	if enabled then				
		widget.binder.img:setColor(1,1,1,1)
		if ability.equipped or ability.toggled then 

			widget.binder.btn:setColor(LIGHT_BLUE:unpack())
			widget.binder.btn:setColorInactive(LIGHT_BLUE:unpack())
			widget.binder.btn:setColorActive(LIGHT_BLUE:unpack())
			widget.binder.btn:setColorHover(LIGHT_BLUE:unpack())

			widget.binder.strengthBG:setColor(LIGHT_BLUE:unpack())
		else 	
			widget.binder.btn:setColor(DARK_BLUE:unpack())			
			widget.binder.btn:setColorInactive(DARK_BLUE:unpack())
			widget.binder.btn:setColorActive(LIGHT_BLUE:unpack())
			widget.binder.btn:setColorHover(LIGHT_BLUE:unpack())

			widget.binder.strengthBG:setColor(DARK_BLUE:unpack())		
		end	
	else
		widget.binder.btn:setColor(GRAY:unpack())			
		widget.binder.btn:setColorInactive(GRAY:unpack())
		widget.binder.btn:setColorActive(GRAY:unpack())
		widget.binder.btn:setColorHover(GRAY:unpack())
		widget.binder.img:setColor(GRAY:unpack())
		widget.binder.strengthBG:setColor(GRAY:unpack())
	end
		
	if enabled then	
		widget.binder.btn.onClick = util.makeDelegate( nil, onClickMainframeAbility, self, ability, abilityOwner )
	end
		
	if ability:getDef().icon then
		widget.binder.img:setVisible(true)
		widget.binder.img:setImage(  ability:getDef().icon )
	end
end 


local function updateProgramButtons( self, widgetName, player )
	-- Show all actionables owned by unit.
	local ACTION_HOTKEYS = { "Q", "W", "E", "R", "T", "Y" }
	local panel = self._panel
	local sim = self._hud._game.simCore

 	for i, widget in panel.binder.programsPanel.binder:forEach( "program" ) do
		widget:setVisible(false)
	end

	for i, widget in panel.binder.programsPanel.binder:forEach( "program" ) do
		local ability
		if player then
			ability = player:getAbilities()[i]
		end

		if ability == nil or sim:getMainframeLockout() then 
			widget:setVisible( false )
		else
			updateButtonFromProgram( self, widget, ability, player, ACTION_HOTKEYS[i] )
			widget:setVisible( true )
		end
	end


end

local function updateDaemonButtons( self, widgetName, player )
	local sim = self._hud._game.simCore

	local isBusy = false

	local panel = self._panel

   	for i, widget in panel.binder.daemonPanel.binder:forEach( widgetName ) do
		isBusy = isBusy or (widget.thread and widget.thread:isBusy())
   	end
   	if isBusy then

		return
   	end

   	local pnlVisible = false 

	for i, widget in panel.binder:forEach( widgetName ) do
		local ability
		if player then
			ability = player:getAbilities()[i]
		end

		local installing = false

		for i,abilityI in ipairs( self._installing) do
			if ability == abilityI then
				installing = true
			end
		end

		if ability == nil or installing or sim:getCurrentPlayer() == nil then
			widget:setVisible( false )
		else

			setDaemonPanel( self, widget, ability, player )

			widget:setVisible( true )
			pnlVisible = true
		end
	end

	panel.binder.daemonPnlTitle:setVisible(pnlVisible)

end


------------------------------------------------------------------------------

local panel = class()

function panel:init( screen, hud )
	self._screen = screen
	self._hud = hud
	self._panel = screen.binder.mainframePnl
	self._mode = MODE_HIDDEN
	self._installing = {}
	self._iceBreaks = {}

	self:hide()
end

function panel:destroyUI()
	if self._iceThread then
		self._iceThread:stop()
		self._iceThread = nil
	end
	self._hud._world_hud:destroyWidgets( world_hud.MAINFRAME )
end

function panel:hide()
	self._mode = MODE_HIDDEN
--	self._panel:setVisible( false )
	self._hud._mainframeOn = false 
	self._hud._world_hud:setMainframe( true, function() drawIceBreakers( self ) end  )
	self:destroyUI()
	self:refresh()
end

function panel:show()
	local localPlayer = self._hud._game:getLocalPlayer()
	if localPlayer == nil or self._hud._game.simCore:isGameOver() then
		return
	end

	self._mode = MODE_VISIBLE

	self._hud._mainframeOn = true
	self._hud._world_hud:setMainframe( true )

	self:refresh()
end

function panel:refresh()

	updateDaemonButtons( self, "enemyAbility", self._hud._game:getForeignPlayer() )
	
	if self._mode == MODE_HIDDEN then
		 self._panel.binder.programsPanel:setVisible( false )
		return
	end
	self._panel.binder.programsPanel:setVisible( true )
	updateProgramButtons( self, "program", self._hud._game:getLocalPlayer() )

	refreshBreakIce( self )

end

function panel:onSimEvent( ev )
	local simdefs = include( "sim/simdefs" )

	if ev.eventType == simdefs.EV_UNIT_UPDATE_ICE then
		-- Acquire list of widgets that are associated with ice
		local widgets = util.tdupe( self._hud._world_hud:getWidgets( world_hud.MAINFRAME ) or {}) 
		for i, widget in self._panel.binder:forEach( "enemyAbility" ) do
			if widget.binder.view_mainframe.ownerID ~= nil then
				table.insert( widgets, widget.binder.view_mainframe )
			end
		end
		-- Search for the widget associated with this particular ice!		
		local widget = findWidget( widgets, ev.eventData.unit )
		if widget and widget.iceBreak == nil then
			widget.iceBreak = breakIceThread( self, widget, ev.eventData.unit )
		end

	elseif ev.eventType == simdefs.EV_MAINFRAME_INSTALL_PROGRAM then
		local sim = self._hud._game.simCore
		local player = sim:getCurrentPlayer()
		MOAIFmodDesigner.playSound("SpySociety/Actions/mainframe_deterrentinstall")
		self:addMainframeProgram(  player, ev.eventData.ability, ev.eventData.idx)

	elseif ev.eventType == simdefs.EV_MAINFRAME_PARASITE then
		rig_util.wait( 120 )
		self._hud:hideMainframe()
	end
end

function panel:addMainframeProgram( player, ability, idx)
	local rig_util = include( "gameplay/rig_util" )
	local widget = self._panel.binder["enemyAbility"..idx]
	--local widget = self._hud._screen.binder.mainframe_centerDaemon	

	local sim = self._hud._game.simCore

	setDaemonPanel( self, widget, ability, player )

	widget:setVisible( true )

	if not widget:hasTransition() then
		widget:createTransition( "activate_left" )
	end			
end


function panel:onHudTooltip( screen, cell )
	-- Hook for mainframe-mode tooltips could go here.
	return nil
end


return
{
	panel = panel
}

