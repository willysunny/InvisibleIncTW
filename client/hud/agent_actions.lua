----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local resources = include( "resources" )
local util = include( "client_util" )
local cdefs = include( "client_defs" )
local array = include( "modules/array" )
local mui_defs = include( "mui/mui_defs")
local inventory = include( "sim/inventory" )
local hudtarget = include( "hud/targeting")
local simdefs = include( "sim/simdefs" )
local simquery = include( "sim/simquery" )
local level = include( "sim/level" )
local modalDialog = include( "states/state-modal-dialog" )

------------------------------------------------------------------------------
-- Local functions
------------------------------------------------------------------------------


local function isPassiveAbility( ability )
	return ability.executeAbility == nil
end

local function shouldShowAbility( game, ability, abilityOwner, abilityUser )
	if ability.profile_icon == nil or ability.neverShow then
		return false
	end

	if isPassiveAbility( ability ) then
		return false
	end

	local enabled, reason = abilityUser:canUseAbility( game.simCore, ability, abilityOwner )
	if not enabled and reason == nil then
		-- If there's no reason displayed, the ability simply shouldn't show up.
		return false
	end

	return true
end

local function shouldShowProxyAbility( game, ability, abilityOwner, abilityUser, actions )
	if not ability.proxy then
		return false
	elseif type(ability.proxy) == "number" then
		local count = 0
		for i, action in ipairs(actions) do
			if action.ability and action.ability:getID() == ability:getID() then
				count = count + 1
			end
		end
		if count >= ability.proxy then
			return false
		end
	end

	if ability.profile_icon == nil or ability.neverShow then
		return false
	end

	if isPassiveAbility( ability ) then
		return false
	end

	local enabled, reason = abilityUser:canUseAbility( game.simCore, ability, abilityOwner )
	if not enabled then
		-- Never show for proxy abilities if they aren't actually available.
		return false
	end

	return true
end


local function performDoorAction( game, exitOp, unit, cell, dir )
	game.hud:transitionNull()
	game:doAction( "useDoorAction", exitOp, unit:getID(), cell.x, cell.y, dir )
end

local function performAbility( game, abilityOwner, abilityUser, ability, ... )
	local abilityIndex = util.indexOf( abilityOwner:getAbilities(), ability )
	assert( abilityIndex, ability:getID() )

	if ability and ability:getDef().confirmAbility then
		local confirmTxt = ability:getDef():confirmAbility( game.simCore, abilityOwner, abilityUser )
		if confirmTxt then
			local result = modalDialog.showYesNo( confirmTxt, STRINGS.UI.HUD_CONFIRM_ABILITY )
			if result ~= modalDialog.OK then
				return false
			end
		end
	end

	game.hud:transitionNull()
	game:doAction( "abilityAction", abilityOwner:getID(), abilityUser:getID(), abilityIndex, ... )
	return true
end

local function generateTooltip( header, body, reason )
	if reason then
		return string.format("<ttheader>%s</>\n<ttbody>%s</>\n<c:ff0000>%s</>", header, body, reason )
	else
		return string.format("<ttheader>%s</>\n<ttbody>%s</>", header, body )
	end
end

local function generateDoorTooltip( hud, exit, exitOp, reason )


	local tooltip = util.tooltip( hud._screen )
	local section = tooltip:addSection()
	local doorState = ""
	if exit.locked then
		doorState = "LOCKED"
	elseif exit.closed then
		doorState = "CLOSED"
	else
		doorState = "OPEN"
	end
	section:addLine( "DOOR", doorState )

	if exitOp == simdefs.EXITOP_CLOSE then
		section:addAbility( "CLOSE", "Close this door.", "gui/icons/action_icons/Action_icon_Small/icon-action_door_close_small.png" )
	elseif exitOp == simdefs.EXITOP_OPEN then
		section:addAbility( "OPEN", "Open this door.", "gui/icons/action_icons/Action_icon_Small/icon-action_door_open_small.png" )
	elseif exitOp == simdefs.EXITOP_LOCK then
		section:addAbility( "LOCK", "Lock this door with a passcard.", "gui/icons/action_icons/Action_icon_Small/icon-action_lock_small.png" )
	elseif exitOp == simdefs.EXITOP_UNLOCK then
		section:addAbility( "UNLOCK", "Unlock this door.", "gui/icons/action_icons/Action_icon_Small/icon-action_unlock_small.png" )
	end
	if reason then
		section:addRequirement( reason )
	end
	return tooltip
end

local function isSameDoor( a, cell, dir )
	if a.cell then
		if cell.x + 1 == a.cell.x and cell.y == a.cell.y and dir == simdefs.DIR_E and a.dir == simdefs.DIR_W then
			return true
		elseif cell.x - 1 == a.cell.x and cell.y == a.cell.y and dir == simdefs.DIR_W and a.dir == simdefs.DIR_E then
			return true
		elseif cell.x == a.cell.x and cell.y + 1 == a.cell.y and dir == simdefs.DIR_N and a.dir == simdefs.DIR_S then
			return true
		elseif cell.x == a.cell.x and cell.y - 1 == a.cell.y and dir == simdefs.DIR_S and a.dir == simdefs.DIR_N then	
			return true
		end
	end

	return false
end

local function canModifyExit( unit, exitop, cell, dir )
	if not simquery.canReachDoor( unit, cell, dir ) then
		return false
	end

	return simquery.canModifyExit( unit, exitop, cell, dir )
end

	-- Generates a list of potential actions in a given direction.
local function generatePotentialExitActions( hud, actions, sim, unit, cell, dir )

	local exit = cell.exits[ dir ]
	if exit.door then
		if exit.locked and not array.findIf( actions, function( a ) return isSameDoor( a, cell, dir ) and a.exitop == simdefs.EXITOP_UNLOCK end ) then
			local enabled, reason = canModifyExit( unit, simdefs.EXITOP_UNLOCK, cell, dir )			
			if enabled or reason then
				table.insert( actions,
				{	
					txt = "Unlock Door\nACTION",
					icon = "gui/icons/action_icons/Action_icon_Small/icon-action_unlock_small.png",
					x = (cell.x + exit.cell.x) / 2, y = (cell.y + exit.cell.y) / 2,  z = 36, cell = cell, dir = dir, exitop = simdefs.EXITOP_UNLOCK,
					layoutID = string.format( "%d,%d-%d", cell.x, cell.y, dir ),
					reason = reason,
					tooltip = generateDoorTooltip( hud, exit, simdefs.EXITOP_UNLOCK, reason ),
					enabled = enabled,
					onClick = function() performDoorAction( hud._game, simdefs.EXITOP_UNLOCK, unit, cell, dir ) end
				})
			end
			
		elseif not exit.closed and not array.findIf( actions, function( a ) return isSameDoor( a, cell, dir ) and a.exitop == simdefs.EXITOP_CLOSE end ) and exit.keybits ~= simdefs.DOOR_KEYS.ELEVATOR and exit.keybits ~= simdefs.DOOR_KEYS.ELEVATOR_INUSE then
			local enabled, reason = canModifyExit( unit, simdefs.EXITOP_CLOSE, cell, dir )
			if enabled or reason then
				table.insert( actions,
				{	
					txt = "Close Door",
					icon = "gui/icons/action_icons/Action_icon_Small/icon-action_door_close_small.png",
					x = (cell.x + exit.cell.x) / 2, y = (cell.y + exit.cell.y) / 2,  z = 36, cell = cell, dir = dir, exitop = simdefs.EXITOP_CLOSE,
					layoutID = string.format( "%d,%d-%d", cell.x, cell.y, dir ),
					reason = reason,
					tooltip = generateDoorTooltip( hud, exit, simdefs.EXITOP_CLOSE, reason ),
					enabled = enabled,
					onClick = function() performDoorAction( hud._game, simdefs.EXITOP_CLOSE, unit, cell, dir ) end
				})
			end

		elseif not array.findIf( actions, function( a ) return isSameDoor( a, cell, dir ) and a.exitop == simdefs.EXITOP_OPEN end ) and exit.keybits ~= simdefs.DOOR_KEYS.ELEVATOR and exit.keybits ~= simdefs.DOOR_KEYS.ELEVATOR_INUSE then --not exit.locked and
			local enabled, reason = canModifyExit( unit, simdefs.EXITOP_OPEN, cell, dir )
			if enabled or reason then
				table.insert( actions,
				{
					txt = "Open Door",
					icon = "gui/icons/action_icons/Action_icon_Small/icon-action_door_open_small.png",
					x = (cell.x + exit.cell.x) / 2, y = (cell.y + exit.cell.y) / 2, z = 36, cell = cell, dir = dir, exitop = simdefs.EXITOP_OPEN,
					layoutID = string.format( "%d,%d-%d", cell.x, cell.y, dir ),
					reason = reason,
					tooltip = generateDoorTooltip( hud, exit, simdefs.EXITOP_OPEN, reason ),
					enabled = enabled,
					onClick = function() performDoorAction( hud._game, simdefs.EXITOP_OPEN, unit, cell, dir ) end
				})
			end
		end
	end
end

-- Generates a list of potential actions that could be performed by 'unit' at
-- the given location.
local function generatePotentialActions( hud, actions, unit, cellx, celly )
	local sim = hud._game.simCore
	local localPlayer = hud._game:getLocalPlayer()
	local x0, y0 = unit:getLocation()
	local cell = cellx and celly and sim:getCell( cellx, celly )
	if cell == nil or not sim:canPlayerSee( localPlayer, cellx, celly ) then
		return
	end

	-- Check actions on units in cell
	for i,cellUnit in ipairs(cell.units) do
		-- Check proxy abilities.
		for j, ability in ipairs( cellUnit:getAbilities() ) do
			if (cellUnit == unit and shouldShowAbility( hud._game, ability, cellUnit, unit )) or
				(cellUnit ~= unit and shouldShowProxyAbility( hud._game, ability, cellUnit, unit, actions )) then
				table.insert( actions, { ability = ability, abilityOwner = cellUnit, abilityUser = unit, priority = ability.HUDpriority } )
			end
		end

		-- Check loot special case.
		if simquery.canLoot( sim, unit, cellUnit ) then
			table.insert( actions,
			{
				txt = STRINGS.UI.ACTIONS.LOOT_BODY.NAME,
				icon = "gui/icons/action_icons/Action_icon_Small/icon-item_loot_small.png",
				x = cell.x, y = cell.y,
				enabled = true,
				layoutID = cellUnit:getID(),
				tooltip = string.format( "<ttheader>%s\n<ttbody>%s</>", STRINGS.UI.ACTIONS.LOOT_BODY.NAME, STRINGS.UI.ACTIONS.LOOT_BODY.TOOLTIP ),
				onClick =
					function()
						hud:showLootPanel( unit, cellUnit )
					end
			})
		elseif simquery.canGive( sim, unit, cellUnit ) then
			table.insert( actions,
			{
				txt = "TRANSFER",
				icon = "gui/icons/action_icons/Action_icon_Small/icon-item_loot_small.png",
				x = cell.x, y = cell.y,
				enabled = true,
				layoutID = cellUnit:getID(),
				tooltip = "TRANSFER ITEMS",
				onClick =
					function()
						hud:showTransferPanel( unit, cellUnit )
					end
			})
		end
	end

	local count = 0
	for i,cellUnit in ipairs(cell.units) do
		if inventory.canCarry( unit, cellUnit ) then
			count = count + 1
		end
	end
	if count > 0 then
		table.insert( actions,
			{	
				txt = "Pickup Items",
				icon = "gui/icons/action_icons/Action_icon_Small/icon-item_loot_small.png",
				x = cell.x, y = cell.y,
				enabled = true,
				onClick = function()
					hud:onSimEvent( { eventType = simdefs.EV_ITEMS_PANEL, eventData = { headerTxt = "CLICK to pick up", unit = unit, x = cellx, y = celly } } )
				end
			})
	end

	if unit:getTraits().canUseDoor ~= false then
		for dir, exit in pairs(cell.exits) do
			generatePotentialExitActions( hud, actions, sim, unit, cell, dir )			
		end
	end
end

return
{
	isPassiveAbility = isPassiveAbility,
	shouldShowAbility = shouldShowAbility,
	shouldShowProxyAbility = shouldShowProxyAbility,
	generatePotentialActions = generatePotentialActions,

	performAbility = performAbility,
	performDoorAction = performDoorAction,
}
