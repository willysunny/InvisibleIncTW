----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local cdefs = include( "client_defs" )
local guiex = include( "guiex" )
local array = include( "modules/array" )
local mui = include( "mui/mui")
local serverdefs = include( "modules/serverdefs" )
local simquery = include( "sim/simquery" )
local modalDialog = include( "states/state-modal-dialog" )
local inventory = include( "sim/inventory" )
local strings = include( "strings" )
local simdefs = include( "sim/simdefs" )

--------------------------------------------------------------------
-- In-game item management.  The item panel shows items that can be
-- placed in an agent's inventory, and triggers the appropriate pickup
-- simactions.

local function onClickPickupItem( panel, item )
	-- Pick da shit up.
	if panel._unit:getInventoryCount() >= panel._unit:getTraits().inventoryMaxSize then  
		modalDialog.show(STRINGS.UI.TOOLTIP_INVENTORY_FULL )
		return
	end

	panel._hud._game:doAction( "lootItem", panel._unit:getID(), item:getID() )
end

local function onClickStealCredits( panel )
	panel._hud._game:doAction( "lootItem", panel._unit:getID(), panel._targetUnit:getID() )
end

local function onLeaveWithRoom( panel, items )
	--If player's inventory still has room AND there's still stuff left.
	if panel._unit:getInventoryCount() < panel._unit:getTraits().inventoryMaxSize and #items > 0 then
		return modalDialog.showYesNo(STRINGS.UI.TOOLTIP_LEAVING_ITEM_SCREEN, STRINGS.UI.TOOLTIP_LEAVING_ITEM_SCREEN_YES)
	else
		return modalDialog.OK
	end 
end

local function onClickUpgradeInventory( panel, unit )

	local changes = { 0,0,0,0,0,0,0,0 }
	changes[panel._inventoryIndex] = 1

	local skills = unit:getSkills()
	local player = unit:getPlayerOwner()
	local playerCredits = player:getCredits()
	
	local cost = skills[panel._inventoryIndex]:getDef()[skills[panel._inventoryIndex]:getCurrentLevel()+1].cost
	if playerCredits >= cost then
		MOAIFmodDesigner.playSound("SpySociety/HUD/gameplay/upgrade_select_unit")
		panel._hud._game:doAction( "buySkillLevels", unit:getID(), changes  )	

	else
		MOAIFmodDesigner.playSound("SpySociety/HUD/gameplay/upgrade_cancel_unit")
		modalDialog.show( STRINGS.UI.TOOLTIP_NOT_ENOUGH_CREDIT )
	end

	panel:refresh()	
end

local function onClickBuyItem( panel, item, itemType )
	local sim = panel._hud._game.simCore
	local player = panel._unit:getPlayerOwner()
	if player ~= sim:getCurrentPlayer() then
		modalDialog.show( STRINGS.UI.TOOLTIP_CANT_PURCHASE )
		return
	end

	if item:getTraits().mainframe_program then
		if #player:getAbilities() >= simdefs.MAX_PROGRAMS then
			modalDialog.show( STRINGS.UI.TOOLTIP_PROGRAMS_FULL )
			return
		end		
		if player:hasMainframeAbility( item:getTraits().mainframe_program ) then
			modalDialog.show( STRINGS.UI.TOOLTIP_ALREADY_OWN )
			return
		end
	elseif panel._unit:getInventoryCount() >= panel._unit:getTraits().inventoryMaxSize then  
		modalDialog.show( STRINGS.UI.TOOLTIP_INVENTORY_FULL )
		return
	end

	local credits = player:getCredits()
	if credits < (item:getUnitData().value * panel._discount) then 
		modalDialog.show( STRINGS.UI.TOOLTIP_NOT_ENOUGH_CREDIT )
		return
	end

	local itemIndex = nil 
	if itemType == "item" then 
		itemIndex = array.find( panel._shopUnit.store.items, item )
	elseif itemType == "weapon" then 
		itemIndex = array.find( panel._shopUnit.store.weapons, item )
	elseif itemType == "augment" then 
		itemIndex = array.find( panel._shopUnit.store.augments, item )
	end

	MOAIFmodDesigner.playSound(cdefs.SOUND_HUD_BUY)

	panel._hud._game:doAction( "buyItem", panel._unit:getID(), panel._shopUnit:getID(), itemIndex, panel._discount, itemType )
	panel:refresh()
end

local function onClickTransferItem( panel, unit, targetUnit, item )
	-- Pick da shit up.
	if targetUnit:getInventoryCount() >= (targetUnit:getTraits().inventoryMaxSize or math.huge) then
		modalDialog.show(STRINGS.UI.TOOLTIP_INVENTORY_FULL )
		return
	end

	local itemIndex = array.find( unit:getChildren(), item )
	panel._hud._game:doAction( "transferItem", unit:getID(), targetUnit:getID(), itemIndex )
	panel:refresh()
end

local function onClickDropItem( panel, unit, item )
	local itemIndex = array.find( unit:getChildren(), item )
	panel._hud._game:doAction( "transferItem", unit:getID(), -1, itemIndex )
	panel:refresh()
end


local function onClickSellItem( panel, item )
	local itemIndex = array.find( panel._unit:getChildren(), item )
	MOAIFmodDesigner.playSound(cdefs.SOUND_HUD_SELL)
	panel._hud._game:doAction( "sellItem", panel._unit:getID(), panel._shopUnit:getID(), itemIndex )
	panel:refresh()
end

local function onClickClose( panel, initType )
	if initType == "loot" and panel._targetUnit then 
		local items = panel._targetUnit:getChildren()
		local answer = onLeaveWithRoom( panel, items )
		
		if answer == modalDialog.OK then
			panel:destroy()
		end
	else
		panel:destroy()
	end
end

local function setProfileImage( unit, panel )
	if unit and unit:getUnitData().profile_anim then
		panel.binder.profile:setVisible( true )
		panel.binder.agentProfileAnim:bindBuild( unit:getUnitData().profile_build or unit:getUnitData().profile_anim )
		panel.binder.agentProfileAnim:bindAnim( unit:getUnitData().profile_anim )
	else
		panel.binder.profile:setVisible( false )
	end
end

-----------------------------------------------------------------------
-- Base class for items panel

local items_panel = class()

function items_panel:init( hud, unit, initType )
	local screen = mui.createScreen( "shop-dialog.lua" )
	mui.activateScreen( screen )

	MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_POPUP )

	self._hud = hud
	self._screen = screen

	local skills = unit:getSkills()
	for i,skill in ipairs(skills)do
		if skill._skillID == "inventory" then
			self._inventoryIndex = i	
		end
	end

	screen.binder.pnl.binder.inventory_bg.binder.closeBtn.onClick = util.makeDelegate( nil, onClickClose, self, initType )
	     screen.binder.pnl.binder.shop_bg.binder.closeBtn.onClick = util.makeDelegate( nil, onClickClose, self, initType )

	self._initType = initType

	if initType == "loot" then
		screen.binder.pnl.binder.sell.binder.titleLbl:setText(STRINGS.UI.SHOP_INVENTORY)
			
		screen.binder.pnl.binder.shop_bg:setVisible(false)
		screen.binder.pnl.binder.inventory_bg:setVisible(true)

		screen.binder.pnl.binder.inventory:setVisible(true)

		screen.binder.pnl.binder.items:setVisible(false)
		screen.binder.pnl.binder.augments:setVisible(false)
		screen.binder.pnl.binder.weapons:setVisible(false)	
		self._itemTarget = "inventory"	
		screen.binder.pnl.binder.creditsTxt:setVisible(true)
	else 
		screen.binder.pnl.binder.sell.binder.titleLbl:setText(STRINGS.UI.SHOP_SELL)
		if initType == "server" then 
			screen.binder.pnl.binder.headerTxt:spoolText(STRINGS.UI.SHOP_SERVER)
		else
			screen.binder.pnl.binder.headerTxt:spoolText(STRINGS.UI.SHOP_PRINTER)
		end
		screen.binder.pnl.binder.shop_bg:setVisible(true)
		screen.binder.pnl.binder.inventory_bg:setVisible(false)

		screen.binder.pnl.binder.inventory:setVisible(false)

		screen.binder.pnl.binder.items:setVisible(true)
		screen.binder.pnl.binder.augments:setVisible(true)
		screen.binder.pnl.binder.weapons:setVisible(true)
		self._itemTarget = "items"
	end

	setProfileImage( unit, self._screen.binder.pnl.binder.sell )
end

function items_panel:findWidget( widgetName )
	return self._screen:findWidget( widgetName )
end

function items_panel:refresh()

	local screen = self._screen
	local player = self._hud._game.simCore:getCurrentPlayer()
	local credits = player:getCredits()
	screen.binder.pnl.binder.creditsTxt:setText( string.format("$%d", credits ) )

	-- Fill out the dialog options.
	local itemCount = 0
	for i, widget in screen.binder.pnl.binder[self._itemTarget].binder:forEach( "item" ) do
		if self:refreshItem( widget, i, "item" ) then
			itemCount = itemCount + 1
		end
	end

	for i, widget in screen.binder.pnl.binder.weapons.binder:forEach( "item" ) do 
		self:refreshItem( widget, i, "weapon" )
	end

	for i, widget in screen.binder.pnl.binder.augments.binder:forEach( "item" ) do 
		self:refreshItem( widget, i, "augment" )
	end

	for i, widget in screen.binder.pnl.binder.sell.binder:forEach( "item" ) do 
		self:refreshUserItem( self._unit, self._unit:getChildren()[i], widget, i )
	end

	-- Auto-close if no items left
	if itemCount == 0 then
		self:destroy()
	end
end

function items_panel:destroy()
	self._hud._itemsPanel = nil
	mui.deactivateScreen( self._screen )
	self._screen = nil
end


function items_panel:refreshUserItem( unit, item, widget, i )

	if item == nil then 
		if i <= unit:getTraits().inventoryMaxSize then
            guiex.updateButtonEmptySlot( widget )
			--widget.binder.btn:setImage( "gui/hud3/SHOP_empty_inventory_slot.png" )
			widget.binder.cost:setVisible(false)
			widget.binder.itemName:setVisible(false)

		elseif i == unit:getTraits().inventoryMaxSize +1  and i < 9 and not unit:getTraits().noInventoryUpgrade then
			local skills = unit:getSkills()
            guiex.updateButtonUpgradeInventory( widget )
            widget.binder.btn.onClick = util.makeDelegate( nil, onClickUpgradeInventory, self, unit )
			widget.binder.itemName:setVisible(true)			
			widget.binder.itemName:setText("UPGRADE INVENTORY")
			widget.binder.cost:setText("$"..skills[self._inventoryIndex]:getDef()[skills[self._inventoryIndex]:getCurrentLevel()+1].cost)
		else
			widget:setVisible( false )
		end

		return false
	else
        guiex.updateButtonFromItem( self._screen, widget, item, nil, unit )

		widget.binder.itemName:setVisible(true)
		widget.binder.itemName:setText( util.toupper(item:getName()) )
		widget.binder.cost:setVisible(false)
		return true
	end
end

-----------------------------------------------------------------------
-- Shop UI

local shop_panel = class( items_panel )

function shop_panel:init( hud, shopperUnit, shopUnit )
	items_panel.init( self, hud, shopperUnit, shopUnit:getTraits().storeType )

	self._shopUnit = shopUnit
	self._unit = shopperUnit
	self._discount = 1.00 
end


function shop_panel:refreshItem( widget, i, itemType )
	local item = nil 
	if itemType == "item" then 
		item = self._shopUnit.store.items[i]
	elseif itemType == "weapon" then 
		item = self._shopUnit.store.weapons[i]
	elseif itemType == "augment" then 
		item = self._shopUnit.store.augments[i]
	end

	if item == nil then
		widget:setVisible( false )
		return false
	else
        guiex.updateButtonFromItem( self._screen, widget, item, nil, self._unit )
		widget.binder.itemName:setText( util.toupper(item:getName()) )
		widget.binder.cost:setText( string.format( "$%d", item:getUnitData().value * self._discount ) )		
		widget.binder.btn.onClick = util.makeDelegate( nil, onClickBuyItem, self, item, itemType )
		return true
	end
end

function shop_panel:refreshUserItem( unit, item, widget, i )
	if items_panel.refreshUserItem( self, unit, item, widget, i ) then
		widget.binder.cost:setVisible(true)
		if item:getUnitData().value then 
			widget.binder.cost:setText( string.format( "+$%d", item:getUnitData().value * 0.5) )	
			widget.binder.btn.onClick = util.makeDelegate( nil, onClickSellItem, self, item )
		else
			widget.binder.cost:setText( STRINGS.UI.SHOP_CANNOT_SELL )
			widget.binder.btn:setDisabled( true )
		end
        return true
    end
end
-----------------------------------------------------------------------
-- Items panel

local loot_panel = class( items_panel )


function loot_panel:init( hud, unit, targetUnit )
	items_panel.init( self, hud, unit, "loot" )

	self._unit = unit
	self._targetUnit = targetUnit

	self._screen.binder.pnl.binder.headerTxt:spoolText(string.format(STRINGS.UI.SHOP_LOOT, util.toupper(targetUnit:getName())))

	setProfileImage( targetUnit, self._screen.binder.pnl.binder.inventory )
end


function loot_panel:refreshUserItem( unit, item, widget, i )
	if items_panel.refreshUserItem( self, unit, item, widget, i ) then
		widget.binder.btn.onClick = util.makeDelegate( nil, onClickTransferItem, self, unit, self._targetUnit, item )
	end

	return true
end


function loot_panel:refreshItem( widget, i )


	widget.binder.btn:setColorInactive(244/255, 255/255, 120/255)
	widget.binder.btn:setColorActive(1,1,1)
	widget.binder.btn:setColorHover(1,1,1)		
	
	local items = self._targetUnit:getChildren()
	local item = nil
	for _, cellUnit in ipairs( items ) do
		if inventory.canCarry( self._unit, cellUnit ) then
			i = i - 1
			if i == 0 then
				item = cellUnit
				break
			end
		end
	end

	-- Check special 'credits item'
	if i == 1 then
		local credits = simquery.calculateCashOnHand( self._hud._game.simCore, self._targetUnit )
		local bonus = math.floor( credits * (self._unit:getTraits().stealBonus or 0))
		credits = credits + bonus

		if (credits or 0) > 0 then
            guiex.updateButtonCredits( widget, credits, bonus )
			
			widget.binder.itemName:setText( string.format( "$%d credits", credits ))
			widget.binder.cost:setText( "" )
			widget.binder.btn.onClick = util.makeDelegate( nil, onClickStealCredits, self )
			return true
		end
	end

	if item == nil then
		widget:setVisible( false )
		return false
	else
        guiex.updateButtonFromItem( self._screen, widget, item, nil, self._unit )
		widget.binder.itemName:setText( util.toupper(item:getName() ) )
		widget.binder.cost:setText( "" )
		widget.binder.btn.onClick = util.makeDelegate( nil, onClickPickupItem, self, item )
		return true
	end
end


-----------------------------------------------------------------------
-- Transfer panel (inventories between two units)

local transfer_panel = class( items_panel )

function transfer_panel:init( hud, unit, targetUnit )
	items_panel.init( self, hud, unit, "loot" )

	self._unit = unit
	self._targetUnit = targetUnit

	self._screen.binder.pnl.binder.headerTxt:spoolText( "TRANSFER ITEMS" )
	self._screen.binder.pnl.binder.inventory_bg.binder.closeBtn.onClick = util.makeDelegate( nil, onClickClose, self, "transfer" )

	setProfileImage( targetUnit, self._screen.binder.pnl.binder.inventory )
end

function transfer_panel:refreshItem( widget, i )
	local inventory = self._targetUnit:getChildren()
	local item = inventory[i]
	return self:refreshUserItem( self._targetUnit, item, widget, i )
end

function transfer_panel:refreshUserItem( unit, item, widget, i )
	if items_panel.refreshUserItem( self, unit, item, widget, i ) then
		if unit == self._unit then
			widget.binder.btn.onClick = util.makeDelegate( nil, onClickTransferItem, self, unit, self._targetUnit, item )
		elseif unit == self._targetUnit then
			widget.binder.btn.onClick = util.makeDelegate( nil, onClickTransferItem, self, unit, self._unit, item )
		end
	end

	return true
end


-----------------------------------------------------------------------
-- Item pickup panel

local pickup_panel = class( items_panel )

function pickup_panel:init( hud, unit, cellx, celly )
	items_panel.init( self, hud, unit, "loot" )

	self._unit = unit
	self._cellx, self._celly = cellx, celly

	self._screen.binder.pnl.binder.headerTxt:setText( "" )
	setProfileImage( nil, self._screen.binder.pnl.binder.inventory )
end

function pickup_panel:refreshItem( widget, i )
	widget.binder.btn:setColorInactive(244/255, 255/255, 120/255)
	widget.binder.btn:setColorActive(1,1,1)
	widget.binder.btn:setColorHover(1,1,1)		
	
	local cell = self._hud._game.simCore:getCell( self._cellx, self._celly )
	local item
	for _, cellUnit in ipairs( cell.units ) do
		if inventory.canCarry( self._unit, cellUnit ) then
			i = i - 1
			if i == 0 then
				item = cellUnit
				break
			end
		end
	end

	if item == nil then
		widget:setVisible( false )
		return false
	else
        guiex.updateButtonFromItem( self._screen, widget, item, nil, self._unit )
		widget.binder.itemName:setText( util.toupper(item:getName() ) )
		widget.binder.cost:setText( "" )
		widget.binder.btn.onClick = util.makeDelegate( nil, onClickPickupItem, self, item )
		return true
	end
end

function pickup_panel:refreshUserItem( unit, item, widget, i )
	if items_panel.refreshUserItem( self, unit, item, widget, i ) then
		widget.binder.btn.onClick = util.makeDelegate( nil, onClickDropItem, self, unit, item )
	end
	return true
end

return
{
	shop = shop_panel,
	loot = loot_panel,
	transfer = transfer_panel,
	pickup = pickup_panel,
}


