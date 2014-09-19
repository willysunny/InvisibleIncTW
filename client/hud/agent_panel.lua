----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources" )
local util = include( "client_util" )
local cdefs = include( "client_defs" )
local guiex = include( "client/guiex" )
local array = include( "modules/array" )
local gameobj = include( "modules/game" )
local mui_defs = include( "mui/mui_defs")
local mui_util = include( "mui/mui_util" )
local targets = include( "hud/targeting" )
local world_hud = include( "hud/hud-inworld" )
local agent_actions = include( "hud/agent_actions" )
local simquery = include( "sim/simquery" )
local level = include( "sim/level" )

--------------------------------------------------------------------
--

local buttonLocator = class()

function buttonLocator:init( hud )
	self.cells = {}
	self.hud = hud
end

function buttonLocator:findLocation( worldx, worldy, worldz )
	local cellx, celly = self.hud._game:worldToCell( worldx, worldy )
	local cell = self.hud._game.simCore:getCell( cellx, celly )
	self.cells[ cell ] = (self.cells[ cell ] or -1) + 1

	return worldx, worldy, (worldz or 0) -- + 18 * self.cells[ cell ]
end

local function getProfileIcon( ability, unit )
	local profile_icon = ability.profile_icon

	if ability.onProfileIcon then
			profile_icon = ability:onProfileIcon( unit )
	end

	return profile_icon
end

local function generateTooltipReason( tooltip, reason )
	if reason then
		return tooltip .. "\n<c:ff0000>" .. reason .. "</>"
	else
		return tooltip
	end
end

local function canUseAbility( self, sim, ability, abilityOwner, abilityUser, ... )
	return abilityUser:canUseAbility( sim, ability, abilityOwner, ... )
end

local function canUseAction( self, action )
	return action.enabled, action.reason
end


local function onClickAbilityAction( self, widget, abilityOwner, abilityUser, ability )
	self._hud._game:dispatchScriptEvent( level.EV_HUD_CLICK_BUTTON, widget:getAlias() )
	self._hud:transitionAbilityTarget( abilityOwner, abilityUser, ability )
end


local function onClickMainframeAbility( self, ability, abilityOwner )
	self._hud:transitionAbilityTarget( abilityOwner, abilityOwner, ability )
end



local function refreshItemTargetting( self, item )
	local cellTargets = buttonLocator( self._hud )
	local iterfn = util.tnext( item:getAbilities(), function( ability ) return agent_actions.shouldShowAbility( self._hud._game, ability, item, self._unit ) end )
	local ability = iterfn()
	while ability do
		assert( item:getUnitOwner() or error( item:getName() ))
		local result, target = self:addAbilityTargets( cellTargets, ability, item, item:getUnitOwner() )
		if target then
			self._hud._stateData.targetHandler = target
			self._hud._stateData.ability = ability
		end
		ability = iterfn()
	end
end


local function onClickItem( self, widget, item, itemUser)
	self._hud._game:dispatchScriptEvent( level.EV_HUD_CLICK_BUTTON, widget:getAlias() )
	self._hud:transitionItemTarget( item, itemUser )
end

local function updateButtonFromActionTarget( self, widget, item )
	local enabled, reason = canUseAction( self, item )

	widget:setVisible( true )
	widget.binder.btn:setImage( item.icon )
	widget.binder.label:setText( util.toupper( item.txt ))
	widget.binder.btn:setTooltip( item.tooltip )
	widget.binder.btn.onClick = item.onClick
	widget.binder.btn:setDisabled( not enabled )



	widget.binder.btn:setColor(cdefs.COLOR_FREE:unpack())			
	widget.binder.btn:setColorInactive(cdefs.COLOR_FREE:unpack())
	widget.binder.btn:setColorActive(cdefs.COLOR_FREE_HOVER:unpack())
	widget.binder.btn:setColorHover(cdefs.COLOR_FREE_HOVER:unpack())	


	if not enabled then
		widget.binder.btn:setColor(0.5,0.5,0.5,1)		
		widget.binder.img:setColor(0.5,0.5,0.5,1)
	end
end



local function updateButtonFromAbilityTarget( self, widget, ability, abilityOwner, abilityUser, ... )
	local sim = self._hud._game.simCore
	local profileIcon = getProfileIcon( ability, abilityOwner )
	local enabled, reason = canUseAbility( self, sim, ability, abilityOwner, abilityUser, ... )
	local abilityTargets = {...}

	if ability.getProfileIcon then
		profileIcon = ability:getProfileIcon( sim, abilityUser, ... )
	end
	
	widget:setVisible( true )
	widget:setAlias( ability:getID() )-- Name this widget so it can be searched for by tutorial.
	widget.binder.btn:setImage( profileIcon )
	widget.binder.btn:setDisabled( not enabled )
	widget.binder.btn:setHotkey( ability.hotkey and string.byte(ability.hotkey) )

	widget.binder.label:setText( util.toupper( ability:getName( sim, abilityOwner, abilityUser, ... )))
	if ability.onTooltip then
		widget.binder.btn:setTooltip( ability:onTooltip( self._hud, sim, abilityOwner, abilityUser, unpack(abilityTargets) ) )

	elseif ability.createToolTip then
		widget.binder.btn:setTooltip( generateTooltipReason( ability:createToolTip( sim, abilityOwner, abilityUser, ... ), reason ) )
	end

	widget.binder.btn.onClick = util.makeDelegate( nil,
		function()
			if agent_actions.performAbility( self._hud._game, abilityOwner, abilityUser, ability, unpack(abilityTargets) ) then
				self:clearTargets()
				self._hud._game:dispatchScriptEvent( level.EV_HUD_CLICK_BUTTON, ability:getID() )
			end
		end )

	if enabled then

		if ability.usesAction then
			widget.binder.img:setColor(cdefs.COLOR_ATTACK:unpack())
			widget.binder.btn:setColor(cdefs.COLOR_ATTACK:unpack())
			widget.binder.btn:setColorInactive(cdefs.COLOR_ATTACK:unpack())
			widget.binder.btn:setColorActive(cdefs.COLOR_ATTACK_HOVER:unpack())
			widget.binder.btn:setColorHover(cdefs.COLOR_ATTACK_HOVER:unpack())			

		elseif ability.usesMP then
			widget.binder.img:setColor(cdefs.COLOR_ACTION:unpack())
			widget.binder.btn:setColor(cdefs.COLOR_ACTION:unpack())
			widget.binder.btn:setColorInactive(cdefs.COLOR_ACTION:unpack())
			widget.binder.btn:setColorActive(cdefs.COLOR_ACTION_HOVER:unpack())
			widget.binder.btn:setColorHover(cdefs.COLOR_ACTION_HOVER:unpack())				
		else
			widget.binder.img:setColor(cdefs.COLOR_FREE:unpack())
			widget.binder.btn:setColor(cdefs.COLOR_FREE:unpack())			
			widget.binder.btn:setColorInactive(cdefs.COLOR_FREE:unpack())
			widget.binder.btn:setColorActive(cdefs.COLOR_FREE_HOVER:unpack())
			widget.binder.btn:setColorHover(cdefs.COLOR_FREE_HOVER:unpack())				
		end
	else
		widget.binder.btn:setColor(0.5,0.5,0.5,1)
		widget.binder.img:setColor(0.5,0.5,0.5,1)
	end
end

local function updateButtonAbilityPopup( self, widget, ability, abilityOwner, abilityUser, ... )

	local buttonWidget = nil
	for i, widget in self._hud._screen.binder.agentPanel.binder.inventory.binder:forEach( "inv" ) do
		if widget._item then
			local abilities = widget._item:getAbilities()
			for i,itemAbility in ipairs(abilities) do
				if itemAbility == ability then
					buttonWidget = widget
					break
				end
			end			
		end
	end

	updateButtonFromAbilityTarget( self, widget, ability, abilityOwner, abilityUser, ...)

	buttonWidget._popUps = buttonWidget._popUps + 1
	local bx, by = buttonWidget:getAbsolutePosition()
	local bx1,by1 = self._hud._screen.binder.agentPanel:getAbsolutePosition()
	by = by + (buttonWidget._popUps*0.05)

	widget:setPosition(bx,by)
end

local function checkforSamePopup(self)
	if not self._popUpsSelected or #self._popUpsSelected ~= #self._popUps then
		return false
	else

		for i,element in ipairs(self._popUps)do

			if not self._popUpsSelected[i] or element.ability:getID() ~= self._popUpsSelected[i].ability:getID() then
				return false
			end
		end

		return true
	end
end

local function refreshPopUp(self)
	local group = self._hud._screen.binder.agentPanel.binder.inventoryGroup
	
	if checkforSamePopup(self) then
		
		for i, widget in group.binder.inventory.binder.popUp.binder:forEach( "action" ) do		
			if  self._popUpsSelected[i] then
				widget:setVisible(true)
				widget:createTransition( "deactivate_below_popup",
						function( transition )
							widget:setVisible( false )
						end,
					 { easeOut = true } )				
			else 
				widget:setVisible(false)
			end
		end
		self._popUps = {}
		self._popUpsSelected = nil
		self._hud:transitionNull()
	else

		if #self._popUps > 0 then	
			
			group.binder.inventory_title:setVisible(false)
			group.binder.inventory.binder.popUp:setVisible(true)
			
			local abilityBtn = nil

			for i, widget in group.binder.inventory.binder.popUp.binder:forEach( "action" ) do		
				if i<= #self._popUps then
					widget:createTransition( "activate_below_popup" )
					widget:setVisible(true)


					local ability = self._popUps[i].ability
					local abilityOwner = self._popUps[i].abilityOwner
					local abilityUser = self._popUps[i].abilityUser
					local unitID = self._popUps[i].unitID

					abilityBtn = ability

					updateButtonFromAbilityTarget( self, widget, ability, abilityOwner, abilityUser, unitID)
				else
					widget:setVisible(false)
				end
			end

			local buttonWidget = nil
			for i, widget in self._hud._screen.binder.agentPanel.binder.inventory.binder:forEach( "inv" ) do
				if widget._item then
					local abilities = widget._item:getAbilities()
					for i,itemAbility in ipairs(abilities) do
						if itemAbility == abilityBtn then
							buttonWidget = widget
							break
						end
					end			
				end
			end

			local lx,ly = buttonWidget:getPosition()
			local lx1,ly1 = group.binder.inventory.binder.popUp:getPosition()
			group.binder.inventory.binder.popUp:setPosition(lx,ly1)

			self._popUpsSelected = self._popUps

		else
			group.binder.inventory_title:setVisible(true)
			group.binder.inventory.binder.popUp:setVisible(false)		
		end

	end
end

local function updateButtonFromAbility( self, widget, ability, abilityOwner )
	local sim = self._hud._game.simCore
	local enabled, reason = canUseAbility( self, sim, ability, abilityOwner, self._unit)
	local hotkey = ability.hotkey

	widget:setVisible( true )
	widget:setAlias( ability:getID() )
	assert(abilityOwner)
	widget.binder.btn:setImage( getProfileIcon( ability, abilityOwner) )
	widget.binder.btn:setDisabled( not enabled )

	if ability.createToolTip then	
		widget.binder.btn:setTooltip( generateTooltipReason( ability:createToolTip( sim, abilityOwner, self._unit ), reason ) )
	elseif ability.onTooltip then
		widget.binder.btn:setTooltip( ability:onTooltip( self._hud, sim, abilityOwner, self._unit ))
	else
		widget.binder.btn:setTooltip( nil )
	end

	widget.binder.btn.onClick = util.makeDelegate( nil, onClickAbilityAction, self, widget, abilityOwner, self._unit, ability )
	widget.binder.btn:setHotkey( hotkey and string.byte(hotkey) )

	if enabled then
		if ability.usesAction then
			
			widget.binder.btn:setColor(cdefs.COLOR_ATTACK:unpack())
			widget.binder.btn:setColorInactive(cdefs.COLOR_ATTACK:unpack())
			widget.binder.btn:setColorActive(cdefs.COLOR_ATTACK_HOVER:unpack())
			widget.binder.btn:setColorHover(cdefs.COLOR_ATTACK_HOVER:unpack())			

		elseif ability.usesMP then
			
			widget.binder.btn:setColor(cdefs.COLOR_ACTION:unpack())
			widget.binder.btn:setColorInactive(cdefs.COLOR_ACTION:unpack())
			widget.binder.btn:setColorActive(cdefs.COLOR_ACTION_HOVER:unpack())
			widget.binder.btn:setColorHover(cdefs.COLOR_ACTION_HOVER:unpack())		

		else
			
			widget.binder.btn:setColor(cdefs.COLOR_FREE:unpack())			
			widget.binder.btn:setColorInactive(cdefs.COLOR_FREE:unpack())
			widget.binder.btn:setColorActive(cdefs.COLOR_FREE_HOVER:unpack())
			widget.binder.btn:setColorHover(cdefs.COLOR_FREE_HOVER:unpack())				
		end
	else
		widget.binder.img:setColor(0.5,0.5,0.5,1)
		widget.binder.btn:setColor(0.5,0.5,0.5,1)
	end
end

local function updateButtonFromItem( self, widget, item, hotkey, unit )
    guiex.updateButtonFromItem( self._hud._screen, widget, item, hotkey, unit )
	widget.binder.btn.onClick = util.makeDelegate( nil, onClickItem, self, widget, item, unit )
end

local function updateButtonFromAction( self, widget, action )
	local enabled, reason = canUseAction( self, action )
	widget:setVisible( true )
	widget.binder.btn:setImage( action.icon )
	widget.binder.btn:setDisabled( not enabled )
	widget.binder.btn.onClick = action.onClick
	widget.binder.btn:setTooltip( generateTooltipReason( action.tooltip, reason ) )
	widget.binder.btn:setHotkey( nil )

	if action.usesAction then
		
		widget.binder.btn:setColor(cdefs.COLOR_ATTACK:unpack())
		widget.binder.btn:setColorInactive(cdefs.COLOR_ATTACK:unpack())
		widget.binder.btn:setColorActive(cdefs.COLOR_ATTACK_HOVER:unpack())
		widget.binder.btn:setColorHover(cdefs.COLOR_ATTACK_HOVER:unpack())		
	else		
		
		widget.binder.btn:setColor(cdefs.COLOR_FREE:unpack())			
		widget.binder.btn:setColorInactive(cdefs.COLOR_FREE:unpack())
		widget.binder.btn:setColorActive(cdefs.COLOR_FREE_HOVER:unpack())
		widget.binder.btn:setColorHover(cdefs.COLOR_FREE_HOVER:unpack())	
	end
end

local function refreshPlayerInfo( unit, binder )
	-- Updates the agent information for the current unit (profile image, brief info text)
	
	binder.agentProfileImg:setVisible(false)
	binder.agentProfileAnim:setVisible(false)
	binder.agentName:setText( util.toupper( "INCOGNITA" ) )
end

local function refreshAgentInfo( unit, binder )
	-- Updates the agent information for the current unit (profile image, brief info text)
	if unit:getUnitData().profile_anim then
		binder.agentProfileImg:setVisible(false)
		binder.agentProfileAnim:setVisible(true)
		binder.agentProfileAnim:bindBuild( unit:getUnitData().profile_build or unit:getUnitData().profile_anim )
		binder.agentProfileAnim:bindAnim( unit:getUnitData().profile_anim )
		if unit:isKO() or unit:getTraits().iscorpse then
			binder.agentProfileAnim:getProp():setRenderFilter( cdefs.RENDER_FILTERS.desat )
			binder.agentProfileAnim:setPlayMode( KLEIAnim.STOP )
		else
			binder.agentProfileAnim:getProp():setRenderFilter( nil )
			binder.agentProfileAnim:setPlayMode( KLEIAnim.LOOP )
		end
	else
		binder.agentProfileImg:setVisible(true)
		binder.agentProfileAnim:setVisible(false)
		binder.agentProfileImg:setImage( unit:getUnitData().profile_icon )	
	end
	
	binder.agentName:setText( util.toupper( unit:getName() ) )
end

local function refreshAbilityTargetting( self )
	self:addAbilityTargets( buttonLocator( self._hud ), self._hud._stateData.ability, self._hud._stateData.abilityOwner, self._hud._stateData.abilityUser )
	self._hud._stateData.targetHandler = self._targets[ #self._targets ]
end

local POTENTIAL_ACTIONS =
{
	0, 0,
	1, 0,
	-1, 0,
	0, 1,
	0, -1,
	2, 0,
	-2, 0,
	0, 2,
	0, -2,
	1, 1,
	1, -1,
	-1, 1,
	-1, -1,
}

local function refreshContextActions( self, sim, unit, binder )
	local actions = {}
	local cellTargets = buttonLocator( self._hud )

	if not self._hud._game:isReplaying() and unit:getPlayerOwner() ~= nil and unit:getPlayerOwner() == self._hud._game:getLocalPlayer() and not unit:isGhost() then
		-- List context sensitive actions
		local x, y = unit:getLocation()
		for i = 1, #POTENTIAL_ACTIONS, 2 do
			local dx, dy = POTENTIAL_ACTIONS[i], POTENTIAL_ACTIONS[i+1]
			agent_actions.generatePotentialActions( self._hud, actions, unit, x + dx, y + dy )
		end

		-- Check actions on units in cell
		for i,childUnit in ipairs(unit:getChildren()) do
			-- Check proxy abilities.
			for j, ability in ipairs( childUnit:getAbilities() ) do
				if agent_actions.shouldShowProxyAbility( self._hud._game, ability, childUnit, unit, actions ) then
					table.insert( actions, { ability = ability, abilityOwner = childUnit, abilityUser = unit, priority = ability.HUDpriority } )
				end
			end
		end
	end
	table.sort( actions, function( a0, a1 ) return (a0.priority or math.huge) > (a1.priority or math.huge) end )

	-- Show all actionables owned by unit.
	for i, widget in binder:forEach( "dynaction" ) do
		local item = table.remove( actions )
		while true do
			if item and item.ability then
				if self:addAbilityTargets( cellTargets, item.ability, item.abilityOwner, item.abilityUser ) then
					item = table.remove( actions )
				else
					if self._hud:canShowElement( "abilities" ) then
						updateButtonFromAbility( self, widget, item.ability, unit )						
					else
						widget:setVisible(false)
					end
					break
				end
			elseif item then
				if self:addActionTargets( cellTargets, item ) then
					item = table.remove( actions )
				else
					if self._hud:canShowElement( "abilities" ) then
						updateButtonFromAction( self, widget, item )						
					else
						widget:setVisible(false)
					end
					break
				end
			else
				widget:setVisible(false)
				break
			end
		end
	end
end


local function refreshInventory( self, sim, unit, binder )
	local items = {}

	-- List items
	for i, childUnit in ipairs( unit:getChildren() ) do
		table.insert( items, childUnit )
	end

	self._panel.binder.inventory_title:setVisible(true)
	self._panel.binder.inventory:setVisible(true)

	-- Show all actionables owned by unit.
	for i, widget in self._hud._screen.binder.agentPanel.binder.inventory.binder:forEach( "inv" ) do
		local item = items[i]
		if unit:getPlayerOwner() ~= self._hud._game:getLocalPlayer() then			
			widget:setVisible(false)

		elseif item then
			updateButtonFromItem( self, widget, item, i, unit )

		elseif i <= (unit:getTraits().inventoryMaxSize or 0) then
			-- Open slot
            guiex.updateButtonEmptySlot( widget )
			widget._item = nil
		else
			widget._item = nil
			widget:setVisible(false)
		end
	end

end

local function refreshPassives( self, sim, unit, binder )
	local iterfn = util.tnext( unit:getAbilities(), function( ability ) return agent_actions.shouldShowAbility( self._hud._game, ability, unit ) end )
	for i, img in binder:forEach( "passiveImg" ) do
		local ability = iterfn()
		

		if ability then
			btn:setImage( getProfileIcon( ability, unit ) )
			img:setTooltip( ability:createToolTip( sim, unit ) )
			img:setVisible( true )
		else
			img:setVisible(false)
		end
	end	
end

-----------------------------------------------------------------------------------------
--

local agent_panel = class()

function agent_panel:init( hud, screen )
	self._hud = hud
	self._screen = screen
	self._panel = screen.binder.agentPanel
	self._panelInventory = screen.binder.inventoryGroup
	self._panelActions = screen.binder.actionsGroup
	self._targets = {}
	self._popUps = {}
	self._popUpsSelected = nil

	self:refreshPanel( nil )
end

function agent_panel:addActionTargets( cellTargets, item )
	local game, sim = self._hud._game, self._hud._game.simCore
	local wx, wy, wz = game:cellToWorld( item.x, item.y )
	wx, wy, wz = cellTargets:findLocation( wx, wy, (item.z or 0) )
	local widget = self._hud._world_hud:createWidget( world_hud.HUD, "Target", { worldx = wx, worldy = wy, worldz = wz, layoutID = item.layoutID } )
	updateButtonFromActionTarget( self, widget, item )
	return true
end

function agent_panel:addAbilityTargets( cellTargets, ability, abilityOwner, abilityUser )
	local game, sim = self._hud._game, self._hud._game.simCore
	local target
	if ability.acquireTargets then
		-- Targetted ability.  Show all targets.
		target = ability:acquireTargets( targets, game, sim, abilityOwner, abilityUser )
	elseif ability.showTargets then
		target = ability:showTargets( targets, game, sim, abilityOwner, abilityUser )
	end

	if target and not ability.noTargetUI then
		if target:hasTargets() then
			if target.startTargeting then
				target:startTargeting( cellTargets )
			end
			table.insert( self._targets, target )
		end
		if ability.showTargets then
			return false, target
		end
		return true, target

	elseif abilityOwner ~= abilityUser then
		local cell
	
		if abilityOwner:getLocation() then
			cell = sim:getCell( abilityOwner:getLocation() )

			local wx, wy, wz = game:cellToWorld( cell.x, cell.y )
			wx, wy, wz = cellTargets:findLocation( wx, wy )
			local widget = self._hud._world_hud:createWidget( world_hud.HUD, "Target",{ worldx = wx, worldy = wy, worldz = wz, layoutID = abilityOwner:getID() } )

			updateButtonFromAbilityTarget( self, widget, ability, abilityOwner, abilityUser )			
		else
			table.insert(self._popUps,{ ability=ability, abilityOwner=abilityOwner, abilityUser=abilityUser})
		end

		return true
	end



	return false
end

function agent_panel:clearTargets()
	while #self._targets > 0 do
		local target = table.remove( self._targets )
		if target.endTargeting then
			target:endTargeting( self._hud )
		end
	end

	self._hud._world_hud:destroyWidgets( world_hud.HUD )
end

function agent_panel:refreshPanel( unit, swipein )
	self._popUps, self._popUpsSelected = {}, nil
	-- Refreshes the entire panel with information about 'unit'.  If unit == nil, this implies hiding the panel.
	local sim = self._hud._game.simCore
	
	self._panel.binder.actions_title:setVisible(true)

	local color = {r=140/255,g=255/255,b=255/255,a=1}
	--if unit == self._hud._game:getLocalPlayer()  then
--		color = {r=247/255,g=127/255,b=14/255,a=1}
	--end
	
	self._panel.binder.nameBG:setColor(color.r,color.g,color.b,color.a)
	self._panel.binder.agentName:setColor(color.r,color.g,color.b,color.a)

	self._panel.binder.border1:setColor(color.r,color.g,color.b,color.a)
	self._panel.binder.border2:setColor(color.r,color.g,color.b,color.a)
	self._panel.binder.border3:setColor(color.r,color.g,color.b,color.a)
	self._panel.binder.border4:setColor(color.r,color.g,color.b,color.a)

		self:clearTargets()

	if unit and (unit._isPlayer or (unit:isValid() and unit:getLocation())) then
		local button_layout = include( "hud/button_layout" )
		self._unit = unit
		if unit.getLocation then
			self._hud._world_hud:setLayout( world_hud.HUD, button_layout( self._hud._game:cellToWorld( unit:getLocation() )))
		end
	else
		self._unit = nil
	end

	if self._unit == nil  then
		self._panel:setVisible( false )	
		self._panelInventory:setVisible( false )			
		self._panelActions:setVisible( false )
		if self._hud._state == self._hud.STATE_ABILITY_TARGET then
			refreshAbilityTargetting( self )
		end

	else
		self._panel:setVisible( true )		
		--self._panel:createTransition( "activate_left" )
		if self._hud:canShowElement( "inventoryPanel" ) then
			self._panelInventory:setVisible( true )		
			if swipein then
				self._panelInventory:createTransition( "activate_left" )
			end
		end

		if self._hud:canShowElement( "abilities" ) then
			self._panelActions:setVisible( true )
			if swipein then
				self._panelActions:createTransition( "activate_left" )
			end
		end

		if unit._isPlayer then
			refreshPlayerInfo( unit, self._panel.binder )

			self._panelInventory:setVisible(false)
			self._panelActions:setVisible(false)
		else

			self._panelInventory:setVisible(true)
			self._panelActions:setVisible(true)

			refreshAgentInfo( unit, self._panel.binder )
			refreshInventory( self, sim, unit, self._panel.binder )
			if self._hud._state == self._hud.STATE_ABILITY_TARGET then
				refreshAbilityTargetting( self )
			elseif self._hud._state == self._hud.STATE_ITEM_TARGET then
				refreshItemTargetting( self, self._hud._stateData.item )
			else
				refreshContextActions( self, sim, unit, self._panel.binder )
			end
			refreshPassives( self, sim, unit, self._panel.binder )
		end
	end
	refreshPopUp(self)
end

function agent_panel:getUnit()
	return self._unit
end

return
{
	agent_panel = agent_panel,
	refreshAgentInfo = refreshAgentInfo,
	updateButtonFromAbilityTarget = updateButtonFromAbilityTarget,
	updateButtonAbilityPopup = updateButtonAbilityPopup,
    updateButtonFromItem = updateButtonFromItem,
	refreshPopUp = refreshPopUp,
	buttonLocator = buttonLocator
}
