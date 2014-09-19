----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include("client_util")
local cdefs = include( "client_defs" )
local modalDialog = include( "states/state-modal-dialog" )

----------------------------------------------------------------
-- Create an asynch task with a wait dialog.

local function createDialogTask( dialogStr, task, cb, ... )
	assert( task )
	assert( dialogStr )

	local thread = MOAICoroutine.new ()
	thread:run ( function( ... )

		local startTime = os.clock()

		local modalDialog = modalDialog.createBusyDialog( dialogStr, "Please Wait" )
		statemgr.activate( modalDialog )

		while ( not task.isFinished ) do
			local progress = math.floor(task.httptask:getProgress())
			modalDialog:setText( string.format( "%s (%.2f) [%%%d]", dialogStr, os.clock() - startTime, progress ))
			coroutine.yield ()
		end

		statemgr.deactivate( modalDialog )

		local endTime = os.clock()
		log:write( "Task '" ..dialogStr.. "' took: " ..1000 * (endTime - startTime).. " ms")
		--log:write( util.stringize( task.result ))

		cb( task.result, task.responseCode, ... )
	end, ... )
end

local function createCountUpThread( widget, numStart, numEnd, duration, format )
	
	local thread = MOAICoroutine.new()
	thread:run( function() 
		local num = numStart
		local i = 0
		local speed = (numEnd - numStart)/(60*duration)

		widget:setText(num)
		
		while num < numEnd do
			num = num + speed
			if num > numEnd then 
				num = numEnd 
			end

			if format then
				widget:setText( string.format( format, math.floor(num) ) )
			else
				widget:setText( math.floor(num) )
			end

			coroutine.yield()
		end
	end)

	return thread

end


local function canUseItem( item, unit )
    local inventory = include( "sim/inventory" )

	if item:getTraits().installed and item:getTraits().augment then
		return false, false
    elseif not item:getUnitData().program and not inventory.isCarryable( item ) then
        return false, false
	elseif item:getRequirements() then 
		for skill,level in pairs( item:getRequirements() ) do
			if not unit:hasSkill(skill, level) then 
				return true, true
			end 
		end
    end

    return true, false
end

local SAFE_RED = { 245/255, 81/255, 32/255 }
local DEFAULT_AMMO_CLR = { 140/255, 255/255, 255/255 }
local ACTIVE_AMMO_CLR = { 1, 1, 0 }

local function updateButtonFromItem( screen, widget, item, hotkey, unit )
	local itemData = item:getUnitData()
	local enabled, requirement = canUseItem( item, unit )

	widget._item = item

	widget:setVisible( true )
	widget:setAlias( item:getName() )
    if widget.binder.btn:getSize() > 36 then
    	widget.binder.btn:setImage( itemData.profile_icon_100 )
    else
    	widget.binder.btn:setImage( itemData.profile_icon )
    end
	widget.binder.btn:setDisabled( not enabled )
	widget.binder.btn.onClick = nil -- Caller-defined.
	if item:getUnitData().onTooltip then
		local tooltip = util.tooltip( screen )
		local section = tooltip:addSection()
		item:getUnitData().onTooltip( section, item, unit )
		widget.binder.btn:setTooltip( tooltip )
    else
        widget.binder.btn:setTooltip( nil )
	end
	widget.binder.btn:setHotkey( hotkey and string.byte(hotkey) )
	widget.binder.equipImg:setVisible( item:getTraits().equipped == true )

	if enabled == true then
		if requirement then 
			widget.binder.btn:setColor(cdefs.COLOR_REQ:unpack())
			widget.binder.btn:setColorInactive(cdefs.COLOR_REQ:unpack())
			widget.binder.btn:setColorActive(cdefs.COLOR_REQ_HOVER:unpack())
			widget.binder.btn:setColorHover(cdefs.COLOR_REQ_HOVER:unpack())	

        elseif itemData.program then
			widget.binder.btn:setColor(cdefs.COLOR_PROGRAM:unpack())			
			widget.binder.btn:setColorInactive(cdefs.COLOR_PROGRAM:unpack())
			widget.binder.btn:setColorActive(cdefs.COLOR_PROGRAM_HOVER:unpack())
			widget.binder.btn:setColorHover(cdefs.COLOR_PROGRAM_HOVER:unpack())	

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

    local ammoTxt, ammoClr = "", DEFAULT_AMMO_CLR
	if item:getTraits().energyWeapon == "active" then
        ammoTxt, ammoClr = "ACTIVE", ACTIVE_AMMO_CLR

    elseif item:getTraits().energyWeapon == "used" then
        ammoTxt, ammoClr = "USED", SAFE_RED
            
	elseif itemData.traits.maxAmmo then
        ammoTxt = string.format( "%d/%d", item:getTraits().ammo, itemData.traits.maxAmmo )
        if item:getTraits().ammo <= 0 then
    		ammoClr = SAFE_RED
        end

	elseif (item:getTraits().cooldown or 0) > 0 then
        ammoTxt, ammoClr = tostring(item:getTraits().cooldown), SAFE_RED
	end

    widget.binder.ammoTxt:setText( ammoTxt )
    widget.binder.ammoTxt:setColor( 0, 0, 0 )
	widget.binder.ammoBG:setVisible( #ammoTxt > 0 )
	widget.binder.ammoBG:setColor( unpack(ammoClr) )
end

local function updateButtonEmptySlot( widget )
	widget:setVisible( true )
	widget:setAlias(nil)
	widget.binder.equipImg:setVisible( false )
	widget.binder.btn:setImage( "" )
	widget.binder.btn:setDisabled( true )
	widget.binder.btn:setTooltip( "EMPTY SLOT" )
	widget.binder.ammoBG:setVisible(false)
	widget.binder.ammoTxt:setText("")
end

local function updateButtonUpgradeInventory( widget )
	widget:setVisible( true )
	widget:setAlias(nil)
	widget.binder.equipImg:setVisible( false )
    widget.binder.btn:setDisabled( false )
    widget.binder.btn:setTooltip( "UPGRADE INVENTORY" )
    widget.binder.btn:setImage( "gui/hud3/SHOP_new_inventory_slot.png" )
	widget.binder.ammoBG:setVisible(false)
	widget.binder.ammoTxt:setText("")
end

local function updateButtonCredits( widget, credits, bonus )
	widget:setVisible( true )
	widget:setAlias(nil)
	widget.binder.equipImg:setVisible( false )
    widget.binder.btn:setDisabled( false )
    widget.binder.btn:setImage( "gui/icons/item_icons/icon-item_credit_chip.png" )		
	local tt = string.format( "<ttbody><ttheader2>STEAL $%d</>\nSteal credits</>", credits )
	if bonus then
		tt = tt .. string.format( "\n(+%d bonus from anarchy)", bonus )
	end
	widget.binder.btn:setTooltip( tt )
	widget.binder.ammoBG:setVisible(false)
	widget.binder.ammoTxt:setText("")
end

----------------------------------------------------------------

return
{
	createDialogTask = createDialogTask,
	createCountUpThread = createCountUpThread,
    updateButtonFromItem = updateButtonFromItem,
    updateButtonEmptySlot = updateButtonEmptySlot,
    updateButtonUpgradeInventory = updateButtonUpgradeInventory,
    updateButtonCredits = updateButtonCredits,
}


