----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local mathutil = include( "modules/mathutil" )
local array = include( "modules/array" )
local color = include( "modules/color" )
local gameobj = include( "modules/game" )
local mui = include("mui/mui")
local mui_defs = include( "mui/mui_defs")
local mui_tooltip = include( "mui/mui_tooltip")
local modalDialog = include( "states/state-modal-dialog" )
local agent_panel = include( "hud/agent_panel" )
local home_panel = include( "hud/home_panel" )
local pause_dialog = include( "hud/pause_dialog" )
local console_panel = include( "hud/console_panel" )
local items_panel = include( "hud/items_panel" )
local hudtarget = include( "hud/targeting")
local world_hud = include( "hud/hud-inworld")
local agent_actions = include( "hud/agent_actions" )
local cdefs = include( "client_defs" )
local rig_util = include( "gameplay/rig_util" )
local resources = include( "resources" )
local level = include( "sim/level" )
local simdefs = include( "sim/simdefs" )
local simquery = include( "sim/simquery" )
local serverdefs = include( "modules/serverdefs" )
local mui_group = include( "mui/widgets/mui_group" )

----------------------------------------------------------------
-- Local functions

local STATE_NULL = 0
local STATE_ABILITY_TARGET = 4
local STATE_ITEM_TARGET = 5
local STATE_REPLAYING = 9

local MAINFRAME_ZOOM = 0.2

 -- Max pathfinding distance for determining valid path; paths beyond this MP cost are considered unpathable.
local MAX_PATH = 15

local DEFAULT_MAINFRAME = 0
local SHOW_MAINFRAME = 1
local HIDE_MAINFRAME = 2

function showFlyText(self, x0, y0, txt, color, target)	
	local wx, wy = self._game:worldToWnd( x0, y0, 0 )
	local u1x, u1y = self._screen:wndToUI( wx,wy )	
	local nx,ny = 0,0

	if target == "credits" then
		nx,ny = self._screen.binder.resourcePnl.binder.credits:getPosition()
		ny = -ny + 20

	elseif target == "alarm" then
		local sx,sy = self._screen:getResolution()
		nx,ny = self._screen.binder.alarm:getPosition()
		nx = sx - nx 

	else
		nx,ny = self._screen.binder.resourcePnl.binder.cpuNum:getPosition()
		ny = -ny + 20
	end

	local u2x,u2y = self._screen:wndToUI( nx,ny )	
	local fxmgr = self._game.fxmgr
	fxmgr:widgetFlyTxt( u1x,u1y, u2x, u2y, txt , 3, self._screen, 0.5, color)
end

function subtractCPU(self,delta)
	local anim = self._screen.binder.resourcePnl.binder.cpuUseFx
	anim:setVisible(true)
	anim:setAnim("idle")

	anim:getProp():setListener( KLEIAnim.EVENT_ANIM_END,
				function( anim, animname )
					if animname == "idle" then
						anim:setVisible(false)
					end
				end )

	local nx,ny = self._screen.binder.resourcePnl.binder.cpuNum:getPosition()
	local u1x,u1y = self._screen:wndToUI( nx,ny )	
	local fxmgr = self._game.fxmgr
	fxmgr:widgetFlyTxt( u1x,u1y, u1x + 0.025 ,u1y, delta , 2, self._screen)

end

local function closeMission(panel)
	panel:setVisible(false)
end

local function showMission(self,header,body)
	local panel = self._screen.binder.mission
	panel:setVisible(true)
	panel.binder.headerTxt:setText(header)
	panel.binder.bodyTxt:spoolText(body)
	panel.binder.closeBtn.onClick =  util.makeDelegate( nil, closeMission, panel) 
end

local function checkForMainframeEvent( simdefs, eventType, eventData )
	if eventType == simdefs.EV_UNIT_MAINFRAME_UPDATE or eventType == simdefs.EV_UNIT_UPDATE_ICE or eventType == simdefs.EV_MAINFRAME_PARASITE or
		eventType == simdefs.EV_MAINFRAME_DANGER or eventType == simdefs.EV_MAINFRAME_INSTALL_PROGRAM or eventType == simdefs.EV_MAINFRAME_UNINSTALL_PROGRAM then
		-- These events require mainframe mode.
		return SHOW_MAINFRAME
	
	elseif eventType == simdefs.EV_ELECTRIC_SHOCK or eventType == simdefs.EV_UNIT_START_WALKING or eventType == simdefs.EV_UNIT_START_SHOOTING or eventType == simdefs.EV_MAINFRAME_HIDE then
		-- These events require normal mode.
		return HIDE_MAINFRAME
	end

	-- Any eithe event don't care about the mainframe mode.
	return DEFAULT_MAINFRAME
end


local function clearMovementRange( self )
	-- Hide movement range hilites.
	self._game.boardRig:clearMovementTiles()

	if self._overwatchSafety then
		self._game.boardRig:unhiliteCells( self._overwatchSafety )
		self._overwatchSafety = nil
	end

	-- Clear movement cells
	self._revealCells = nil
end


local function showMovementRange( self, unit )

	clearMovementRange( self )

	-- Show movement range.
	if unit and not unit._isPlayer and unit:hasTrait("mp") and unit:canAct() and unit:getPlayerOwner() == self._game:getLocalPlayer() then
		local sim = self._game.simCore
		local simquery = sim:getQuery()
		local cell = sim:getCell( unit:getLocation() )

		self._revealCells = simquery.floodFill( sim, unit, cell,unit:getMP() )

		if unit:getTraits().sneaking == true and unit:isPC() then  
			self._game.boardRig:setMovementTiles( self._revealCells, 0.8 * cdefs.MOVECLR_SNEAK, cdefs.MOVECLR_SNEAK )
		else
			self._game.boardRig:setMovementTiles( self._revealCells, 0.8 * cdefs.MOVECLR_DEFAULT, cdefs.MOVECLR_DEFAULT )
		end

		if config.SAFEZONES then
			self:showOverwatchSafety(unit, self._revealCells)
		end

	end
end

local function previewAbilityAP( hud, unit, apCost )
	local rig = hud._game.boardRig:getUnitRig( unit:getID() )
	rig:previewMovement( apCost )
	hud._home_panel:refreshAgent( unit )
	if apCost > 0 then
		hud._abilityPreview = true
	else 
		hud._abilityPreview = false 
	end  
end

local function showMovement( hud, unit, moveTable, pathCost )
	local sim = hud._game.simCore

	if hud._movePreview then
		hud._game.boardRig:unchainCells( hud._movePreview.hiliteID )
		local rig = hud._game.boardRig:getUnitRig( hud._movePreview.unitID )
		local prevUnit = sim:getUnit( hud._movePreview.unitID )
		if rig and not hud._abilityPreview then
			rig:previewMovement( 0 )
		end
		hud._movePreview = nil

		hud._home_panel:refreshAgent( prevUnit )
	end

	if moveTable then
		hud._movePreview = { unitID = unit:getID(), pathCost = pathCost }
		if unit:getMP() >= pathCost then
			hud._movePreview.hiliteID = hud._game.boardRig:chainCells( moveTable )
			local rig = hud._game.boardRig:getUnitRig( unit:getID() )
			if rig then
				rig:previewMovement( pathCost )
				hud._abilityPreview = false 
			end
		else
			hud._movePreview.hiliteID = hud._game.boardRig:chainCells( moveTable, {r=0.2, g=0.2, b=0.2, a=0.8}, nil, true )
		end

		hud._home_panel:refreshAgent( unit )
	end
end

local function previewMovement(hud, unit, cellx, celly)
	local sim = hud._game.simCore 
	local simdefs = sim:getDefs()

	hud._bValidMovement = false

	if unit and sim:getCurrentPlayer() and unit:getPlayerOwner() == sim:getCurrentPlayer() and unit:hasTrait("mp") and unit:canAct() then
		local startcell = sim:getCell( unit:getLocation() )
		local endcell = startcell
		if cellx and celly then
			endcell = sim:getCell( cellx, celly )
		end

		if startcell ~= endcell and endcell then
			local moveTable, pathCost = sim:getQuery().findPath( sim, unit, startcell, endcell, math.max( MAX_PATH, unit:getMP() ) )
			if moveTable then
				hud._bValidMovement = unit:getMP() >= pathCost
				table.insert( moveTable, 1, { x = startcell.x, y = startcell.y } )
				showMovement(hud, unit, moveTable, pathCost )
				return
			end
		end
	end

	showMovement( hud, nil )
end

local function showOverwatchSafety(self, unit, cells)
	local sim = self._game.simCore
	local simdefs = sim.getDefs()
	local simquery = sim.getQuery()

	if self._overwatchSafety then
		self._game.boardRig:unhiliteCells( self._overwatchSafety )
		self._overwatchSafety = nil
	end

	local enemyFound = false
	for _, enemy in ipairs(sim:getNPC():getUnits() ) do
		if enemy:getBrain() and enemy:getBrain():getTarget() == unit then
			enemyFound = true
			break
		end
	end
	if not enemyFound then
		return
	end

	local safeCells = {}
	for _, cell in ipairs(cells) do
		if simquery.isCellWatched(sim, unit:getPlayerOwner(), cell.x, cell.y) == simdefs.CELL_HIDDEN then
			table.insert(safeCells, cell)
		end
	end

	if #safeCells > 0 then
		self._overwatchSafety = self._game.boardRig:hiliteCells( safeCells, {0.3,0.3,0.0,0.3} )
	end
end



local function transition( hud, state, stateData )	

	local sim = hud._game.simCore
	local simdefs = sim.getDefs()
	local simquery = sim.getQuery()

	if hud._state == STATE_REPLAYING then
		hud._game:skip()
	end

	if hud._stateData and hud._stateData.hiliteID then
		hud._game.boardRig:unhiliteCells( hud._stateData.hiliteID )
	elseif hud._stateData and hud._stateData.ability then
		if hud._stateData.ability.endTargeting then
			hud._stateData.ability:endTargeting( hud )
		end
		if hud._stateData.targetHandler and hud._stateData.targetHandler.endTargeting then
			hud._stateData.targetHandler:endTargeting( hud )
		end
	end

	if state == STATE_ABILITY_TARGET and stateData and stateData.ability then 
		if stateData.ability.startTargeting then
			stateData.ability:startTargeting( hud )
		end
		if stateData.targetHandler and stateData.targetHandler.startTargeting then
			stateData.targetHandler:startTargeting( agent_panel.buttonLocator( hud ) )
		end
	end

	hud._state = state
	hud._stateData = stateData
		
	if hud._state == STATE_NULL and (hud:getSelectedUnit() and  not hud:getSelectedUnit()._isPlayer)then
		showMovementRange( hud, hud:getSelectedUnit() )
		previewMovement( hud, hud:getSelectedUnit(), hud._tooltipX, hud._tooltipY )
	else
		clearMovementRange( hud )
		showMovement( hud, nil )
	end

	hud:refreshHud( )
end

local function countSelectables( self, cell )
	local count = 0
	for i, unit in ipairs( cell.units ) do
		if self:canSelect( unit ) then
			count = count + 1
		end
	end
	return count
end

local function canSelect( hud, unit )
	local localPlayer = hud._game:getLocalPlayer()

	if unit:getUnitData().profile_icon == nil and unit:getUnitData().profile_anim == nil then
		return false
	end

	if ((unit:getTraits().selectpriority or 1) <= 0) then
		return false
	end
	
	if unit:getLocation() == nil then
		return false
	end

	return unit:isGhost() or localPlayer == nil or hud._game.simCore:canPlayerSeeUnit( localPlayer, unit )
end

local function doMoveUnit( hud, unit, cellx, celly )
	local sim = hud._game.simCore
	local simdefs = sim:getDefs()
	assert( unit )

	if unit:getPlayerOwner() == sim:getCurrentPlayer() and unit:getPlayerOwner() == hud._game:getLocalPlayer() and unit:hasTrait("mp") and unit:canAct() then
		local startcell = sim:getCell( unit:getLocation() )
		local endcell = sim:getCell( cellx, celly )

		if startcell ~= endcell and endcell then
			local moveTable, pathCost = sim:getQuery().findPath( sim, unit, startcell, endcell, math.max( MAX_PATH, unit:getMP() ) )
			if moveTable then
				if pathCost <= unit:getMP() then
					hud._game:doAction( "moveAction", unit:getID(), moveTable )
					MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_CONFIRM )
				else
					hud:showWarning( "Not enough Action Points.", {r=1,g=1,b=1,a=1}, "End your turn to refresh Action Points" )

					local endTurnBtn = hud._screen:findWidget( "endTurnBtn" )
					endTurnBtn:blink(0.2, 2, 0, {r=1,g=1,b=1,a=1})

					if not endTurnBtn:hasTransition() then
						endTurnBtn:createTransition( "activate_left" )
					end
					MOAIFmodDesigner.playSound( simdefs.SOUND_SPEECH_WARNING )
				end
				return true
			else
				local checkcell = unit:getPlayerOwner():getCell(cellx,celly)
				if not checkcell or not sim:getQuery().canPath(sim, nil, nil, checkcell) then
					hud:showWarning( "Selected unit cannot move there." )
					MOAIFmodDesigner.playSound( simdefs.SOUND_SPEECH_WARNING )
				else
					hud:showWarning( "There is no valid path there.", {r=1,g=1,b=1,a=1} )
					MOAIFmodDesigner.playSound( simdefs.SOUND_SPEECH_WARNING )
				end
				return true
			end
		end
	end

	return false
end

local function doSelectUnit( hud, cellx, celly )
	local localPlayer = hud._game:getLocalPlayer()
	local selectedUnit = nil
	if cellx and celly then
		local cell
		if localPlayer == nil then
			cell = hud._game.simCore:getCell( cellx, celly )
		else
			cell = localPlayer:getCell( cellx, celly )
		end
		if cell then
			local idx = util.indexOf( cell.units, hud:getSelectedUnit() )

			if idx == nil then
				-- Select the highest priority unit.
				local candidates = {}
				for _,unit in ipairs(cell.units) do
					if canSelect( hud, unit ) then
						table.insert( candidates, unit )
					end
				end
				table.sort( candidates, function( lu, ru ) return (lu:getTraits().selectpriority or 1) > (ru:getTraits().selectpriority or 1) end )
				selectedUnit = candidates[1]
			else
				-- Each selection attempt cycles through the selectable units in the cell.
				for i = 1,#cell.units do
					
					idx = (idx or 0) - 1
					if idx <= 0 then
						idx = #cell.units
					end

					local unit = cell.units[idx]
					if canSelect( hud, unit ) then						
						selectedUnit = unit
						break
					end
				end			
			end
		end
	end

	if selectedUnit then
		MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_SELECT_UNIT )
		hud:selectUnit( selectedUnit )		
	end
end

local function doSelectInitialUnit( self )
	-- Selects the first valid (non-KO) unit of the local player, or nil otherwise.
	local sim = self._game.simCore
	local selectUnit = sim:getUnit( self._lastSelectedUnitID )
	if selectUnit and (not canSelect( self, selectUnit ) or selectUnit:isKO()) then
		selectUnit = nil
	end

	if self._game:getLocalPlayer() ~= nil then
		if selectUnit == nil or not canSelect( self, selectUnit ) or selectUnit:isKO() then
			local units = self._game:getLocalPlayer():getUnits()
			for i, unit in ipairs(units) do
				if canSelect( self, unit ) and not unit:isKO() then
					selectUnit = unit
					break
				end
			end
		end
		
		self:selectUnit( selectUnit )
		if selectUnit then
			MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_SELECT_UNIT )
			self._game:getCamera():fitOnscreen( self._game:cellToWorld( selectUnit:getLocation()) )
		end
	end

end

local function doSelectNextUnit( self )
	if self._game:getLocalPlayer()  ~= nil then
		local units = self._game:getLocalPlayer():getUnits()
		local sim = self._game.simCore
		local simquery = sim:getQuery()
		if #units > 0 then
			local idx = util.indexOf( units, self:getSelectedUnit() ) or 0
			local count = 0

			repeat
				idx = (idx % #units) + 1
				count = count + 1
				local unit = units[idx]
				if unit:getLocation() and simquery.isAgent( unit ) then
					self:selectUnit( unit )
					MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_SELECT_UNIT )
					self._game:getCamera():fitOnscreen( self._game:cellToWorld( unit:getLocation()) )
					break
				end
			until units[idx] == self._stateData or count >= #units
		end
	end
end

local function onClickMenu( hud )
	hud:showPauseMenu()
end

local function onClickRotateCamera( hud, orientationDelta )
	if not hud._game:isReplaying() then
		local camera = hud._game:getCamera()
		camera:rotateOrientation( camera:getOrientation() + orientationDelta )
	end
end

local function refreshToggleFastBtn( hud )
	local currentPlayer = hud._game.simCore:getCurrentPlayer()
	if currentPlayer then
		local settingsFile = savefiles.getSettings( "settings" )
		hud._screen.binder.statsPnl.binder.fastBtn:setChecked( settingsFile.data.fastMode == true )
	end
end

local function onClickToggleFast( hud, btn )
	local currentPlayer = hud._game.simCore:getCurrentPlayer()
	if currentPlayer then
		local settingsFile = savefiles.getSettings( "settings" )
		settingsFile.data.fastMode = btn:isChecked()
		refreshToggleFastBtn( hud )
	end
end

local function refreshTrackerAdvance( hud, trackerNumber )
    local stage = hud._game.simCore:getTrackerStage( trackerNumber )
	local animWidget = hud._screen.binder.alarm.binder.trackerAnimFive
	local colourIndex = math.min( #cdefs.TRACKER_COLOURS, stage + 1 )
	local colour = cdefs.TRACKER_COLOURS[ colourIndex ]

    -- Show the tracker number
	hud._screen.binder.alarm.binder.trackerTxt:setText( tostring(stage) )
	hud._screen.binder.alarm.binder.trackerTxt:setColor(colour.r, colour.g, colour.b, 1)

    -- Refresh the alarm ring.
	animWidget:setColor( colour:unpack() )
    if trackerNumber >= simdefs.TRACKER_MAXCOUNT then
    	animWidget:setAnim("idle_5")
    else
    	animWidget:setAnim("idle_".. trackerNumber % simdefs.TRACKER_INCREMENT )
    end

    -- And cue the music 
	MOAIFmodDesigner.setMusicProperty("intensity", stage )
end

local function setAlarmVisible( hud, visible )
	hud._screen.binder.alarm:setVisible(visible)
end

local function runTrackerAdvance( hud, txt, delta, tracker )
	if txt then
		hud:showWarning( txt, nil, nil, (delta+1)*cdefs.SECONDS )
	end

	hud._screen.binder.alarm.binder.alarmRing1:setAnim( "idle" )	
	hud._screen.binder.alarm.binder.alarmRing1:setVisible( true )
	hud._screen.binder.alarm.binder.alarmRing1:getProp():setListener( KLEIAnim.EVENT_ANIM_END,
		function( anim, animname )
			if animname == "idle" then
				hud._screen.binder.alarm.binder.alarmRing1:setVisible(false)
			end		
		end)

    local animWidget = hud._screen.binder.alarm.binder.trackerAnimFive
	for i=1,delta do
		MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_ADVANCE_TRACKER )
    
        local stage = hud._game.simCore:getTrackerStage( tracker + i )
	    local colourIndex = math.min( #cdefs.TRACKER_COLOURS, stage + 1 )
	    local colour = cdefs.TRACKER_COLOURS[ colourIndex ]
	    animWidget:setColor( colour:unpack() )
        local fillNum = (tracker + i) % simdefs.TRACKER_INCREMENT
        if fillNum == 0 then
            rig_util.waitForAnim( animWidget:getProp(), "fill_5" )
        else
            rig_util.waitForAnim( animWidget:getProp(), "fill_" .. fillNum )
        end
    end

    refreshTrackerAdvance( hud, tracker + delta )
	
    rig_util.wait( 30 )
	MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_ADVANCE_TRACKER_NUMBER )
end

local function showDaemon( self, daemonName, daemonBodyTxt, icon )
	local screen = mui.createScreen( "modal-daemon.lua" )
	
	mui.activateScreen( screen )

	local result = nil

	screen.binder.pnl.binder.okBtn.binder.btn:setText(STRINGS.UI.CONTINUE)
	screen.binder.pnl.binder.okBtn.binder.btn.onClick = util.makeDelegate( nil, function() result = true end )

	screen.binder.pnl.binder.title.binder.titleTxt:setVisible(false)
	screen.binder.pnl.binder.title.binder.titleTxt2:setVisible(false)
	screen.binder.pnl.binder.bodyTxt:setVisible(false)
	screen.binder.pnl.binder.progress:setVisible(false)

	screen.binder.pnl.binder.icon:setImage(icon)


	rig_util.wait( 0.2*cdefs.SECONDS )
	screen.binder.pnl.binder.title.binder.titleTxt:setVisible(true)
	screen.binder.pnl.binder.title.binder.titleTxt2:setVisible(true)
	screen.binder.pnl.binder.title.binder.titleTxt:setText( string.format( STRINGS.DAEMONS.DAEMON_PNL_TITLE ) )
	screen.binder.pnl.binder.title.binder.titleTxt2:spoolText( string.format( STRINGS.DAEMONS.WARNING_TITLE, daemonName ) )
	

	rig_util.wait( 0.2*cdefs.SECONDS )
	screen.binder.pnl.binder.bodyTxt:setVisible(true)
	screen.binder.pnl.binder.bodyTxt:spoolText( daemonBodyTxt )

	rig_util.wait( 0.2*cdefs.SECONDS )
	screen.binder.pnl.binder.progress:setVisible(true)

	local modalRoutine = MOAICoroutine.new()		
	modalRoutine:run( function()
			local val = 0
			while val < 1 do
				screen.binder.pnl.binder.progress:setProgress( val )	
				rig_util.wait( 0.05*cdefs.SECONDS )
				val = val + .05

			end

			screen.binder.pnl.binder.progress:setProgress( 1 )	

		end )
	modalRoutine:resume()


	-- We are running in the vizThread coroutine.  Yield until a response is chosen by the UI.
	while result == nil do
		coroutine.yield()
	end

	self._game.simCore:setChoice( 1 )
	modalRoutine:stop()
	mui.deactivateScreen( screen )
end

local function showWarning( self, txt, color, subtext, timeinseconds, mainframe, iconFlash, ability)

	--jcheng:
	--if there's a subtext, use warningtxt
	--if no subtext, use the warningtxtCenter which is centered in the box

	if not timeinseconds then
		self._warningTimer = 3*cdefs.SECONDS
	else
		self._warningTimer = timeinseconds
	end

		
	self._screen.binder.warning:setVisible(true)

	local warningTxt = self._screen.binder.warningTxtCenter
	if subtext then
		warningTxt = self._screen.binder.warningTxt
		self._screen.binder.warningSubTxt:setText(subtext)
		self._screen.binder.warningTxtCenter:setText("")
	else
		self._screen.binder.warningSubTxt:setText("")
		self._screen.binder.warningTxt:setText("")
	end

	warningTxt:setText(txt)

	if color then
		self._screen.binder.warningBG:setColor(color.r,color.g,color.b,color.a)
		warningTxt:setColor(color.r,color.g,color.b,color.a)
		if subtext then
			self._screen.binder.warningSubTxt:setColor(color.r,color.g,color.b,color.a)
		end
	else
		self._screen.binder.warningBG:setColor( 184/255, 13/255, 13/255, 1)
		warningTxt:setColor(184/255, 13/255, 13/255, 1)
		if subtext then
			self._screen.binder.warningSubTxt:setColor(184/255, 13/255, 13/255, 1)
		end
	end

	if mainframe then
		self._screen.binder.warning.binder.hazzard:setVisible(true)
		self._screen.binder.warning.binder.warningTxt:setColor(0,0,0,1)
		self._screen.binder.warning.binder.warningSubTxt:setColor(0,0,0,1)
		self._screen.binder.warning.binder.warningTxtCenter:setColor(0,0,0,1)
		self._screen.binder.warning.binder.warningBG:setVisible(false)
		self._screen.binder.warning.binder.fullBG:setVisible(true)
		self._screen.binder.warning.binder.fullBG:setColor(1,0,0,160/255)		
	else
		self._screen.binder.warning.binder.fullBG:setVisible(false)
		self._screen.binder.warning.binder.hazzard:setVisible(false)
		self._screen.binder.warning.binder.warningBG:setVisible(true)
	end	

	if not self._screen.binder.warning:hasTransition() then
		self._screen.binder.warning:createTransition( "activate_left" )
	end

end


local function showPauseMenu( self )
	self._pause_dialog:show()
end

local function getCPULocation( self )	
	return self._screen.binder.resourcePnl.binder.cpuNum:getPosition()
end

local function canShowElement( self, name )
	local vizTags = self._game.simCore.vizTags
	if vizTags == nil then
		return true
	end

	return vizTags[ name ] ~= false
end

local function startTitleSwipe(hud,swipeText,color,sound,showCorpTurn)
	MOAIFmodDesigner.playSound( sound )
	hud._screen.binder.swipe:setVisible(true)
	hud._screen.binder.swipe.binder.anim:setColor(color.r, color.g, color.b, color.a )	
	hud._screen.binder.swipe.binder.anim:setAnim("pre")

	hud._screen.binder.swipe.binder.txt:spoolText(string.format(swipeText))	
	hud._screen.binder.swipe.binder.txt:setColor(color.r, color.g, color.b, color.a )	

	local stop = false
	hud._screen.binder.swipe.binder.anim:getProp():setPlayMode( KLEIAnim.LOOP )
	hud._screen.binder.swipe.binder.anim:getProp():setListener( KLEIAnim.EVENT_ANIM_END,
	function( anim, animname )
				if animname == "pre" then
					hud._screen.binder.swipe.binder.anim:setAnim("loop")		
					stop = true
				end					
			end )

	util.fullGC() -- Convenient time to do a full GC. ;}			

	while stop == false do
		coroutine.yield()		
	end

end

local function stopTitleSwipe(hud)
    rig_util.waitForAnim(  hud._screen.binder.swipe.binder.anim:getProp(), "pst" )
    hud._screen.binder.swipe:setVisible(false)
end

local function hideTitleSwipe( hud )
	hud._screen.binder.swipe:setVisible( false )
end

local function onClickEndTurn( hud, button, event )
	transition( hud, STATE_NULL )
	hud._game:doAction( "endTurnAction" )
	if hud:getSelectedUnit() then
		hud._lastSelectedUnitID = hud:getSelectedUnit():getID()
	else
		hud._lastSelectedUnitID = nil
	end
	hud:selectUnit( nil )
end

local function hideMainframe( hud )
	if hud._lastSelectedUnitID	then
		hud:selectUnit(hud._game.simCore:getUnit( hud._lastSelectedUnitID ) )		
		hud._lastSelectedUnitID = nil
	else
		hud:selectUnit(nil)
	end	
end

local function showMainframe( hud )

	hud:selectUnit(hud._game:getLocalPlayer())				
end

local function onClickMainframeBtn( hud, button, event )
	if config.DEV and hud._game:isReplaying() then
		hud._game:skip()
	end
	if not hud._game:isReplaying() then
		if hud._isMainframe then
			hideMainframe( hud )
		else
			showMainframe( hud )
		end
	end
end

local function setMainframeMode( hud, mainframeMode, selectLastUnit )
	local gfxOptions = hud._game:getGfxOptions()

	if mainframeMode ~= hud._isMainframe then 
		MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_MODE_SWITCH )
		MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/mode_switch_static" )

		if mainframeMode == true then
			MOAIFmodDesigner.setMusicProperty("mode",1)

			MOAIFmodDesigner.setAmbientReverb( "mainframe" )
			KLEIRenderScene:pulseUIFuzz( 0.2 )					
			FMODMixer:pushMix("mainframe")

			hud._beforeMainframeZoom = hud._game:getCamera():getZoom()

			hud._game:getCamera():zoomTo( hud._game:getCamera():getZoom() +MAINFRAME_ZOOM )

			gfxOptions.bRenderExits = true
			gfxOptions.bFOWEnabled = false
			gfxOptions.bMainframeMode = true
			gfxOptions.KAnimFilter = "green"

			hud._isMainframe = true
			hud._game.boardRig:refresh()
 
			--hud:selectUnit( hud._game:getLocalPlayer() )

			hud._mainframe_panel:show()
			
			hud._game:dispatchScriptEvent( level.EV_HUD_MAINFRAME_TOGGLE )	 
			hud._hideCubeCursor = true

		else
			MOAIFmodDesigner.setMusicProperty("mode",0)

			MOAIFmodDesigner.setAmbientReverb( "office" )
			KLEIRenderScene:pulseUIFuzz( 0.2 )
			FMODMixer:popMix("mainframe")

			hud._mainframe_panel:hide()

			hud._game:getCamera():zoomTo( hud._beforeMainframeZoom )
--[[
			if selectLastUnit then			
				hud:selectUnit( hud._game.simCore:getUnit( hud._lastSelectedUnitID ) )
			end
]]
			gfxOptions.bRenderExits = true
			gfxOptions.bFOWEnabled = true
			gfxOptions.bMainframeMode = false
			gfxOptions.KAnimFilter = "default"
			
			hud._isMainframe = false

			hud._game.boardRig:refresh()

			hud._game:dispatchScriptEvent( level.EV_HUD_MAINFRAME_TOGGLE )	
			hud._hideCubeCursor = false
		end
	end
	
end

local function showChoiceDialog( hud, headerTxt, bodyTxt, options, dType, tooltips, playerCredits, enemyProfile )
	assert( hud._choice_dialog == nil )

	local screen

	screen = mui.createScreen( "modal-event.lua" )
	
	hud._choice_dialog = screen
	mui.activateScreen( screen )

	screen.binder.pnl.binder.headerTxt:setText( headerTxt )
	screen.binder.pnl.binder.bodyTxt:setText("<c:8CFFFF>".. bodyTxt.."</>" )

	--selected agent
	local unit = hud:getSelectedUnit()
	if unit ~= nil and unit.getUnitData then
		screen.binder.pnl.binder.yourface.binder.portrait:bindBuild( unit:getUnitData().profile_build or unit:getUnitData().profile_anim )
		screen.binder.pnl.binder.yourface.binder.portrait:bindAnim( unit:getUnitData().profile_anim )
		screen.binder.pnl.binder.yourface:setVisible(true)
	else
		screen.binder.pnl.binder.yourface:setVisible(false)
	end

	if enemyProfile then
		screen.binder.pnl.binder.theirface.binder.portrait:bindBuild( "portraits/portrait_security_build" )
		screen.binder.pnl.binder.theirface.binder.portrait:bindAnim( "portraits/portrait_animation_template" )
		screen.binder.pnl.binder.theirface.binder.portrait:setColor(0,0,0,1)
		screen.binder.pnl.binder.theirface:setVisible(true)
	else
		screen.binder.pnl.binder.theirface:setVisible(false)
	end

	-- Fill out the dialog options.
	local result = nil
	local x = 1
	for i, btn in screen.binder.pnl.binder:forEach( "optionBtn" ) do
		if options[i] == nil then
			btn:setVisible( false )
		else
			btn:setVisible( true )
			btn:setText("<c:8CFFFF>"..  options[i] .."</>")
			btn.onClick = util.makeDelegate( nil, function() result = i end )
			x = x + 1
		end
	end

	if (dType == "level" or dType == "augment") and tooltips ~= nil then
		for i, btn in screen.binder.pnl.binder:forEach( "optionBtn" ) do
			btn:setTooltip(tooltips[i])
		end
	end

	-- We are running in the vizThread coroutine.  Yield until a response is chosen by the UI.
	-- Note that the click handler will be triggered by the main coroutine, but we use a closure
	-- to inform us what the chosen result is.
	while result == nil do
		coroutine.yield()
	end

	mui.deactivateScreen( screen )
	hud._choice_dialog = nil

	hud._game.simCore:setChoice( result )

	return result
end

local function showNoteDialog( hud, unit )
	local noteType = unit:getTraits().noteType
	local notes = cdefs.NOTES[ noteType ]
	if notes and #notes > 0 then
		-- Use the unique unitID to select a random note from the list.  This ensures a degree
		-- of randomness, but also binds the note content to this specific unit only :)  Nice!
		local bodyTxt = notes[ unit:getID() % #notes + 1 ]
		showChoiceDialog( hud, noteType, bodyTxt, { "Close" } )
	end
end

----------------------------------------------------------

local function destroyHud( self )
	MOAIFmodDesigner.setAmbientReverb( nil )

	showMovement( self )

	mui.deactivateScreen( self._screen )
	self._screen = nil

	if self._itemsPanel then
		self._itemsPanel:destroy()
		self._itemsPanel = nil
	end

	if self._missionPanel then
		self._missionPanel:destroy()
		self._missionPanel = nil
	end

	self._world_hud:destroy()

	self._game.layers["floor"]:removeProp( self.hudProp )
	self.hudProp = nil
end

local function refreshTooltip( self )
	self._forceTooltipRefresh = true
end

local function onHudTooltip( self, screen, wx, wy )
	if self._world_hud._screen:getTooltip() ~= nil then
		return nil
	end

	wx, wy = screen:uiToWnd( wx, wy )
	local cellx, celly = self._game:wndToCell( wx, wy )
	local cell = cellx and celly and self._game.boardRig:getLastKnownCell( cellx, celly )

	local tooltipTxt = wx and wy and self._game:generateTooltip( wx, wy )
	if type(tooltipTxt) == "string" and #tooltipTxt > 0 then
		return tooltipTxt
		
	elseif not cell then
		-- No cell here, no tooltip.
		self._lastTooltipCell, self._lastTooltip = nil, nil

	elseif self._lastTooltipCell == cell and not self._forceTooltipRefresh then
		-- Same cell as last update, dont recreate things.  Shiz be expensive yo!
		return self._lastTooltip

	elseif self._isMainframe then
		self._lastTooltipCell = cell
		self._lastTooltip = self._mainframe_panel:onHudTooltip( screen, cell )
		return self._lastTooltip

	else
		local tooltip = util.tooltip( self._screen )
		local selectedUnit = self:getSelectedUnit()


		-- check to see if there are any interest points here
		local player = self._game:getForeignPlayer()
		local interest = nil
		for i,unit in ipairs(player:getUnits()) do
			if unit:getBrain() and unit:getBrain():getInterest() and unit:getBrain():getInterest().x == cell.x and unit:getBrain():getInterest().y == cell.y then

				if unit:getTraits().alerted then				
					interest = "hunting"
				else
					if interest ~= "hunting" then
						interest = "investigating"
					end
				end
		
			end				
		end
		
		-- only put the tip if needed and only 1, not one for each interest present.
		if interest then
			local section = tooltip:addSection()
				
			local line = cdefs.INTEREST_TOOLTIPS[interest].line
			local icon = cdefs.INTEREST_TOOLTIPS[interest].icon
			section:addAbility("INTEREST POINT", line,icon )
		end

		local localPlayer = self._game:getLocalPlayer()
		local isWatched = localPlayer and simquery.isCellWatched( self._game.simCore, localPlayer, cellx, celly )
		if isWatched == simdefs.CELL_WATCHED then
			tooltip:addSection( ):addWarning( "WATCHED", "This location is watched by the enemy.", "gui/icons/thought_icons/status_hunt.png" , cdefs.COLOR_WATCHED_BOLD )
		elseif isWatched == simdefs.CELL_NOTICED then
			tooltip:addSection( ):addWarning( "NOTICED", "This location is noticed by the enemy.", "gui/icons/thought_icons/status_hunt.png" , cdefs.COLOR_NOTICED_BOLD )
		elseif isWatched == simdefs.CELL_HIDDEN then
			tooltip:addSection():addWarning( "HIDDEN", "This location is hidden from enemy sight.", "gui/icons/thought_icons/status_engaged.png" )
		end

		if selectedUnit and self._state == STATE_NULL and not selectedUnit._isPlayer then
			-- This cell has NO selectable units, and there is a unit selected.
			local x0, y0 = selectedUnit:getLocation()
			local canMove = (x0 ~= cell.x or y0 ~= cell.y) and self._revealCells ~= nil and array.find( self._revealCells, cell ) ~= nil
			if canMove then
				local section = tooltip:addSection()
				section:appendHeader( "RIGHT CLICK", "MOVE" )
			end
		end
			
		if cell.units then

			local nextSelect = nil
			for i, cellUnit in ipairs( cell.units ) do
				if cellUnit:getUnitData().onWorldTooltip then
					local section = tooltip:addSection()
                    cellUnit:getUnitData().onWorldTooltip( section, cellUnit )

					if selectedUnit ~= cellUnit and nextSelect == nil and self:canSelect( cellUnit ) then
						section:appendHeader( "LEFT CLICK", "SELECT" )
						nextSelect = cellUnit
					end
					if cellUnit:getTraits().mainframe_item then
						section:appendHeader( "SPACEBAR", "MAINFRAME" )
					end
				end
			end	
		end

		self._lastTooltipCell, self._lastTooltip = cell, tooltip
		self._forceTooltipRefresh = nil

		return tooltip
	end
end

local function refreshObjectives( self )

	if config.RECORD_MODE then
		return
	end

	for _, widget in ipairs(self._objectiveWidgets) do 
		self._screen:removeWidget( widget )
		widget = nil 
	end

	self._objectiveWidgets = {}

	local objectives = self._game.simCore:getObjectives()
	local timedObjs = 0
	local lineObjs = 0
	for _, objective in ipairs(objectives) do 
		--If the objective is a normal one-liner or a multi-turn objective
		if objective.objType == "line" then 
			local widget = self._screen:createFromSkin( "objectiveLine", { xpx = true, ypx = true, anchor = 7 } )
			self._screen:addWidget( widget )
			local x = 244
			local y = 100 + (21 * lineObjs + 38 * timedObjs)
			widget:setPosition(x, y)
			widget:setVisible( true )
			widget.binder.objectiveTxt:setText( objective.txt )
			table.insert( self._objectiveWidgets, widget )
			lineObjs = lineObjs + 1
		else 
			local widget = self._screen:createFromSkin( "objectiveTimed", { xpx = true, ypx = true, anchor = 7 } )
			self._screen:addWidget( widget )
			local x = 136
			local y = 106 + (21 * lineObjs + 38 * timedObjs)
			widget:setPosition(x, y)
			widget:setVisible( true )
			widget.binder.objectiveTxt:setText( objective.txt )

			for i, bar in widget.binder:forEach( "bar" ) do 
				if i > objective.max then 
					bar:setVisible( false )
				else 
					bar:setVisible( true )
					if i <= objective.current then 
						bar:setColor( 244/255, 255/255, 120/255, 1 )
					else 
						bar:setColor( 34/255, 34/255, 58/255, 1 )
					end
				end 
			end 

			table.insert( self._objectiveWidgets, widget )
			timedObjs = timedObjs + 1
		end
	end

	if #objectives == 0 then 
		self._screen.binder.objectivesTopLabel:setVisible( false )
	else 
		self._screen.binder.objectivesTopLabel:setVisible( true )
		local x = 155 
		local y = 93 + (21 * lineObjs + 38 * timedObjs)
		self._screen.binder.objectivesTopLabel:setPosition( x, y )
	end


	--if objectiveTxt ~= self._screen.binder.objectiveTxt:getText() then
		--self._screen.binder.objectivesTopLabel:setVisible( false )
		--objective stuff WIP
	--end
end

local function refreshHudValues( self )
	local pcPlayer = self._game.simCore:getPC()
	if pcPlayer then
		self._screen.binder.resourcePnl.binder.cpuNum:setText(string.format("%d/%d", pcPlayer:getCpus(), pcPlayer:getMaxCpus()))		
		self._screen.binder.resourcePnl.binder.credits:setText(string.format("%d", pcPlayer:getCredits()))
	else
		self._screen.binder.resourcePnl.binder.cpuNum:setText("-")
		self._screen.binder.resourcePnl.binder.credits:setText("???")
	end
end

local function refreshHud( self )
	hideTitleSwipe( self )
	refreshTrackerAdvance( self, self._game.simCore:getTracker() )
	refreshToggleFastBtn( self )

	if self._choice_dialog then
		mui.deactivateScreen( self._choice_dialog )
		self._choice_dialog = nil
	end 

	self._home_panel:refresh()

	self._mainframe_panel:refresh()

	-- the agent panel unit may no longer be a valid selection
	if self:getSelectedUnit() and ( not self:getSelectedUnit()._isPlayer and not self:getSelectedUnit():getLocation() )  then
		self:selectUnit( nil )
	end

	self._agent_panel:refreshPanel( self:getSelectedUnit() )

	local showPanels = (self._game.simCore:getCurrentPlayer() == self._game:getLocalPlayer())

	self._endTurnButton:setVisible( showPanels and self:canShowElement( "endTurnBtn" ))
	self._screen.binder.homePanel:setVisible( showPanels )
	self._screen.binder.resourcePnl:setVisible( showPanels and self:canShowElement( "resourcePnl" ))
	self._screen.binder.statsPnl:setVisible( showPanels and self:canShowElement( "statsPnl" ))
	self._screen.binder.alarm:setVisible( self:canShowElement( "alarm" ))
	self._screen.binder.mainframePnl:setVisible( showPanels )
	self._screen.binder.topPnl:setVisible( self:canShowElement( "topPnl" ))

	if #self._objectiveWidgets > 0 then
		self._screen.binder.objectivesTopLabel:setVisible( showPanels )
	end
	
	for i,widget in ipairs( self._objectiveWidgets ) do 
		widget:setVisible( showPanels )
	end

	local daysTxt = 0
	local hoursTxt = 0
	local difficultyNum = self._game.params.difficulty
	if difficultyNum == nil or difficultyNum == 0 then
		difficultyNum = 1
	end

	local difficultyStr = ""
	if self._game.params.gameDifficulty == simdefs.NORMAL_DIFFICULTY then
		difficultyStr = util.toupper( STRINGS.UI.NORMAL_DIFFICULTY )
	else
		difficultyStr = util.toupper( STRINGS.UI.HARD_DIFFICULTY )
	end
	
	local difficulty = STRINGS.UI.DIFFICULTY[difficultyNum]

	if self._game.params.campaignHours then
		daysTxt = math.floor( self._game.params.campaignHours / 24 ) + 1
		hoursTxt = self._game.params.campaignHours % 24
	end

	local turnText = math.floor((self._game.simCore._turnCount + 1)/2)+1

	self._screen.binder.statsPnl.binder.statsTxt:setText( string.format(STRINGS.UI.HUD_DAYS_TURN_ALARM, daysTxt, hoursTxt, difficulty, difficultyStr ) )

	refreshHudValues( self )

	-- As the HUD can change right beneath the mouse, want to force a tooltip refresh
	refreshTooltip( self )
end

local function clearLOS( self )
	-- Boardrig has cleared all hilites, need to clear identifiers so we don't try to double unhilite.
	self._losUnits = {}
end

local function selectUnit( self, selectedUnit )
	local prevUnit = self._agent_panel:getUnit()
	local player = self._game:getLocalPlayer() 

	-- Selection should only happen in STATE_NULL, so if we're not there, cleanup and go to null state!
	if self._state == STATE_ABILITY_TARGET or self._state == STATE_ITEM_TARGET then
		transition( self, STATE_NULL )
	end

	if prevUnit ~= selectedUnit then
		self._agent_panel:refreshPanel( selectedUnit, true )
			
		-- Clear previous unit's selection state
		if prevUnit ~= nil then
			
			if prevUnit ~= player then				
				self._game.boardRig:selectUnit( nil )
			end

			clearMovementRange( self )
			showMovement( self, nil )

			if prevUnit == player then
				setMainframeMode( self, false )
			end
		end

		-- this is set after mainframe mode.
		
		-- Select new state
		if selectedUnit and selectedUnit == player  then	
			-- MAINFRAME SELECTED
			if prevUnit then				
				self._lastSelectedUnitID = prevUnit:getID()
			end			
			setMainframeMode( self, true )
		else
			self._game.boardRig:selectUnit( selectedUnit )

			if selectedUnit and selectedUnit:getPlayerOwner() == self._game.boardRig:getSim():getCurrentPlayer() then
				showMovementRange( self, selectedUnit )
				previewMovement( self, selectedUnit, self._tooltipX, self._tooltipY )

			elseif prevUnit then
				MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_DESELECT_UNIT )
			end
			refreshTooltip( self )

			self._game:dispatchScriptEvent( level.EV_UNIT_SELECTED, selectedUnit and selectedUnit:getID() )

		end
		self._home_panel:refresh()
	
	end
end

local function getSelectedUnit( self )
	return self._agent_panel:getUnit()
end

local function transitionAbilityTarget( self, abilityOwner, abilityUser, ability )
	if not ability.acquireTargets then
		agent_actions.performAbility( self._game, abilityOwner, abilityUser, ability )
		MOAIFmodDesigner.playSound( cdefs.SOUND_UI_CONFIRM )
	else
		local targetHandler = ability:acquireTargets( hudtarget, self._game, self._game.simCore, abilityOwner, abilityUser )
		if not targetHandler:hasTargets() then
			self:showWarning( "No valid targets." )
		else
			local defaultTarget = targetHandler:getDefaultTarget()
			if defaultTarget and not ability.noDefaultTarget then
				agent_actions.performAbility( self._game, abilityOwner, abilityUser, ability, defaultTarget )
			else
				if ability.startTargeting then
					ability:startTargeting( hudtarget, self._game, self._game.simCore, abilityOwner, abilityUser )
				end

				transition( self, STATE_ABILITY_TARGET, { abilityOwner = abilityOwner, abilityUser = abilityUser, ability = ability, targetHandler = targetHandler } )
			end
		end
	end
end

local function transitionItemTarget( self, item, itemUser )
	transition( self, STATE_ITEM_TARGET, { item = item, itemUser = itemUser } )
end

local function updateHudTooltip( self )
	local sim = self._game.simCore
	local localPlayer = self._game:getLocalPlayer()
	if localPlayer and self._tooltipX and self._tooltipY then

		if not self._hideCubeCursor then

			if not self._game.fxmgr:containsFx( self.selectFX ) then
				self.selectFX = self._game.fxmgr:addAnimFx({ x = 0, y = 0, kanim = "gui/selectioncubetest", symbol = "character", anim = "anim", loop = true, scale = 1.0 })
			end
			self.selectFX:setLoc( self._game:cellToWorld( self._tooltipX, self._tooltipY ))

		else
			if self.selectFX then
				self._game.fxmgr:removeFx( self.selectFX )
				self.selectFX = nil
			end			
		end

		local tooltipCell = localPlayer:getCell( self._tooltipX, self._tooltipY )

		if tooltipCell then
			for i,unit in ipairs(tooltipCell.units) do
				if unit:hasTrait("hasSight") and self._losUnits[ unit:getID() ] == nil then
					self._losUnits[ unit:getID() ] = 0
				end
			end
		end	

		for unitID, hiliteID in pairs( self._losUnits ) do
			local unit = sim:getUnit( unitID )
			local x, y
			if unit then
				x, y = unit:getLocation()
			end
			
			if unit == nil or x ~= self._tooltipX or y ~= self._tooltipY or not inputmgr.keyIsDown( mui_defs.K_SHIFT ) then
				if hiliteID > 0 then
					self._game.boardRig:unhiliteCells( hiliteID )
				end
				self._losUnits[ unitID ] = nil

			elseif hiliteID == 0 then
				local losCoords, cells = {}, {}
				sim:getLOS():getVizCells( unit:getID(), losCoords )
				for i = 1, #losCoords, 2 do
					local x, y = losCoords[i], losCoords[i+1]
					table.insert( cells, sim:getCell( x, y ))
				end
				self._losUnits[ unitID ] = self._game.boardRig:hiliteCells( cells )
			end
		end

	else
		if self.selectFX then
			self._game.fxmgr:removeFx( self.selectFX )
			self.selectFX = nil
		end

		showMovement( self ) -- Clear
	end

	self._world_hud:refreshWidgets()
end


local function transferDaemonProgram(self)
	local player = self._game:getLocalPlayer()
					
	local move = false
	if self._daemonCenterPanelUp.ability.duration or self._daemonCenterPanelUp.ability.ice then
		self._mainframe_panel:addMainframeProgram(  player, self._daemonCenterPanelUp.ability, self._daemonCenterPanelUp.idx)
		move = true
	end
	
	for i,abilityI in ipairs(self._mainframe_panel._installing) do
		if abilityI == self._daemonCenterPanelUp.ability then
			table.remove(self._mainframe_panel._installing,i)
			break
		end
	end
	
	return move
end

local function showPickupPanel( self, unit, cellx, celly )
	if self._itemsPanel then
		self._itemsPanel:destroy()
	end
	self._itemsPanel = items_panel.pickup( self, unit, cellx, celly )
	self._itemsPanel:refresh()
end

local function showLootPanel( self, unit, targetUnit )
	if self._itemsPanel then
		self._itemsPanel:destroy()
	end
	self._itemsPanel = items_panel.loot( self, unit, targetUnit )
	self._itemsPanel:refresh()
end

local function showTransferPanel( self, unit, targetUnit )
	if self._itemsPanel then
		self._itemsPanel:destroy()
	end

	self._itemsPanel = items_panel.transfer( self, unit, targetUnit )
	self._itemsPanel:refresh()
end

local function showShopPanel( self, shopperUnit, shopUnit )
	if self._itemsPanel then
		self._itemsPanel:destroy()
	end
	self._itemsPanel = items_panel.shop( self, shopperUnit, shopUnit )
	self._itemsPanel:refresh()
end

local function updateHud(self)
	assert( self._game:isReplaying() == (self._state == STATE_REPLAYING) )

	if mui.wasHandled() then
		-- no In game tooltip stuff if the UI is handling events
		self._tooltipX, self._tooltipY = nil, nil
	end

	updateHudTooltip( self )

	if self._warningTimer then
		self._warningTimer = self._warningTimer - 1
		if self._warningTimer <= 0 then
			self._warningTimer = nil
			self._screen.binder.warning:setVisible( false )

			if self._daemonCenterPanelUp then

				local move = transferDaemonProgram(self)

				local widget = self._screen.binder.mainframe_centerDaemon			

				if move then
					widget:createTransition( "deactivate_right",
						function( transition )
							widget:setVisible( false )
						end,
					 { easeOut = true } )
				else
					widget:setVisible( false )
				end

				self._daemonCenterPanelUp = nil
			end
		end
	end

	local player = self._game:getLocalPlayer()
	if player then
		if self._blinkyCPUCount and self._mainframeOn then 
			if player:getCpus() <= 0 then 
				self._blinkyCPUCount = self._blinkyCPUCount - 1 

				if self._blinkyCPUCount < 1 then 
					if self._blinkyCPU_showOff then 
						self._screen.binder.resourcePnl.binder.cpuNum:setColor(1, 0, 0, 1)	
						self._blinkyCPU_showOff = nil
						self._blinkyCPUCount = 20
					else 
						self._screen.binder.resourcePnl.binder.cpuNum:setColor(140/255,255/255,255/255,1)	
						self._blinkyCPU_showOff = true
						self._blinkyCPUCount = 20
					end
				end
			end
		end

		if self._mainframeOn == false or player:getCpus() >= 1 then 
			self._screen.binder.resourcePnl.binder.cpuNum:setColor(140/255,255/255,255/255,1)
		end
	end

	self._missionPanel:onUpdate()
end

local function drawRaycast( self, x0, y0, x1, y1 )
	local tx, ty = self._game.simCore:getLOS():raycast( x0, y0, x1, y1 )
	MOAIGfxDevice.setPenColor( 0, 1, 0, 1 )
	x0, y0 = self._game:cellToWorld( x0, y0 )
	x1, y1 = self._game:cellToWorld( x1, y1 )
	if tx then
		tx, ty = self._game:cellToWorld( tx, ty )
		MOAIDraw.drawLine( x0, y0, tx, ty )
		MOAIGfxDevice.setPenColor( 1, 0, 0, 1 )
		MOAIDraw.drawLine( tx, ty, x1, y1 )
		return 0
	else
		MOAIDraw.drawLine( x0, y0, x1, y1 )
		return 1
	end
end

local function onHudDraw( self )
	if self._debugLOS then
		local u = self:getSelectedUnit()
		if u and u.getLocation then
			local x0, y0 = u:getLocation()
			local cell = self._game.simCore:getCell( self._game:wndToCell( inputmgr.getMouseXY() ) )
			if cell then
				local c, delta = 0, 0.49
				c = c + drawRaycast( self, x0, y0, cell.x + delta, cell.y + delta )
				c = c + drawRaycast( self, x0, y0, cell.x + delta, cell.y - delta )
				c = c + drawRaycast( self, x0, y0, cell.x - delta, cell.y + delta )
				c = c + drawRaycast( self, x0, y0, cell.x - delta, cell.y - delta )
				if c > 0 then
					local x1, y1 = self._game:cellToWorld( cell.x - 0.5, cell.y - 0.5 )
					local x2, y2 = self._game:cellToWorld( cell.x + 0.5, cell.y + 0.5 )
					MOAIGfxDevice.setPenColor( 0, 1, 0, 1 )
					MOAIDraw.fillRect( x1, y1, x2, y2 ) 
				end
			end
		end

	elseif self._state == STATE_ABILITY_TARGET or self._state == STATE_ITEM_TARGET then
		if self._stateData.targetHandler and self._stateData.targetHandler.onDraw then
			self._stateData.targetHandler:onDraw()
		end
	end
end

local function onSimEvent( self, ev )

	local sim = self._game.simCore
	local simdefs = sim.getDefs()

	local mfMode = checkForMainframeEvent( simdefs, ev.eventType, ev.eventData )
	if mfMode == SHOW_MAINFRAME then
		if not self._isMainframe then
			showMainframe( self )
		end
		self._mainframe_panel:onSimEvent( ev )

	elseif mfMode == HIDE_MAINFRAME and self._isMainframe then
		hideMainframe( self )
	end
	
	if ev.eventType == simdefs.EV_UNIT_WARPED then
		if ev.eventData.to_cell == nil then
			local selectedUnit = self._agent_panel:getUnit()
			if selectedUnit and selectedUnit == ev.eventData.unit then			
				self:selectUnit( nil )
			end
		end

	elseif ev.eventType == simdefs.EV_HUD_REFRESH then
		self:refreshHud()

	elseif ev.eventType == simdefs.EV_UNIT_REFRESH then
		if self._agent_panel:getUnit() == ev.eventData.unit then
			self._agent_panel:refreshPanel( self._agent_panel:getUnit() )
		end


	elseif ev.eventType == simdefs.EV_UNIT_DRAG_BODY or ev.eventType == simdefs.EV_UNIT_DROP_BODY then
		self._home_panel:refreshAgent( ev.eventData.unit )

	elseif ev.eventType == simdefs.EV_TURN_START then
		--self:refreshHud()
		local currentPlayer = self._game.simCore:getCurrentPlayer()

		self._game.boardRig:onStartTurn( currentPlayer and currentPlayer:isPC() )

		if currentPlayer ~= nil then
			self:refreshHud()

			if currentPlayer ~= self._game:getLocalPlayer() then
				self._oldPlayerMainframeState = self._isMainframe
			end

			local txt, color, sound
			local corpTurn = false
			if currentPlayer:isNPC() then
				txt = "ENEMY ACTIVITY"
				color = {r=1,g=0,b=0,a=1}
				sound = cdefs.SOUND_HUD_GAME_ACTIVITY_CORP		
				corpTurn = true
			else
				txt = "AGENT ACTIVITY"
				color = {r=140/255,g=255/255 ,b=255/255,a=1}
				sound = cdefs.SOUND_HUD_GAME_ACTIVITY_AGENT
				doSelectInitialUnit( self )
			end

			self:startTitleSwipe(txt,color,sound, corpTurn)
			rig_util.wait(30)
		
			self:stopTitleSwipe()
		end
	
	elseif ev.eventType == simdefs.EV_WAIT_DELAY then
		rig_util.wait( ev.eventData )
	
	elseif ev.eventType == simdefs.EV_TURN_END then		

		if ev.eventData and not ev.eventData:isNPC() then
			self:stopTitleSwipe()
		end

	elseif ev.eventType == simdefs.EV_ADVANCE_TRACKER then

		if ev.eventData.tracker + ev.eventData.delta >= simdefs.TRACKER_MAXCOUNT then			
		--	self._game.post_process:colorCubeLerp( "data/images/cc/cc_default.png", "data/images/cc/screen_shot_out_test1_cc.png", 1.0, MOAITimer.PING_PONG, 0,0.5 )		
			MOAIFmodDesigner.playSound(  "SpySociety/HUD/gameplay/alarm_LP","alarm")
		end
		runTrackerAdvance( self, ev.eventData.txt, ev.eventData.delta, ev.eventData.tracker)

	elseif ev.eventType == simdefs.EV_LOOT_ACQUIRED and not ev.eventData.silent then
		if not self._game.debugStep then
			modalDialog.show( string.format("%s acquired %s!", ev.eventData.unit:getName(), ev.eventData.lootUnit:getName() ), "Loot" )
		end

	elseif ev.eventType == simdefs.EV_CREDITS_ACQUIRED then
		if not self._game.debugStep then
			MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/gain_money")
			modalDialog.show( string.format("%s acquired %d credits!", ev.eventData.unit:getName(), ev.eventData.credits ), "Loot" )
		end

	elseif ev.eventType == simdefs.EV_NOTE_DIALOG then
		showNoteDialog( self, ev.eventData )

	elseif ev.eventType == simdefs.EV_MAINFRAME_TEXT then 
		modalDialog.show( string.format("%s", ev.eventData.desc ) ) 

	elseif ev.eventType == simdefs.EV_CREDITS_REFRESH then
		refreshHudValues( self )

	elseif ev.eventType == simdefs.EV_CHOICE_DIALOG then
		return showChoiceDialog( self, ev.eventData.headerTxt, ev.eventData.bodyTxt, ev.eventData.options, ev.eventData.type, ev.eventData.tooltips, ev.eventData.playerCredits, ev.eventData.enemyProfile )

	elseif ev.eventType == simdefs.EV_ITEMS_PANEL then
		if ev.eventData then
			if ev.eventData.shopUnit then
				self:showShopPanel( ev.eventData.shopperUnit, ev.eventData.shopUnit )
			elseif ev.eventData.targetUnit then
				self:showLootPanel( ev.eventData.unit, ev.eventData.targetUnit )
			else
				self:showPickupPanel( ev.eventData.unit, ev.eventData.x, ev.eventData.y )
			end

		elseif self._itemsPanel then
			self._itemsPanel:refresh()
		end

	elseif ev.eventType == simdefs.EV_CMD_DIALOG then
		console_panel.panel( self, ev.eventData )
		
	elseif ev.eventType == simdefs.EV_AGENT_LIMIT then
		if not self._game.debugStep then
			modalDialog.show( string.format("You have the maximum number of agents, your team cannot support any more.") )
		end

	elseif ev.eventType == simdefs.EV_SHOW_ALARM then
		if not self._game.debugStep then
			if ev.eventData.sound then
				MOAIFmodDesigner.playSound( ev.eventData.sound )
			end
			if ev.eventData.speech then
				MOAIFmodDesigner.playSound( ev.eventData.speech )
			end			
 			modalDialog.showAlarm( ev.eventData.txt, ev.eventData.txt2, ev.eventData.num, ev.eventData.num2, ev.eventData.txt3, ev.eventData.txt4 )
		end

 	elseif ev.eventType == simdefs.EV_SHOW_ALARM_FIRST then
		if not self._game.debugStep then
			if ev.eventData.sound then
				MOAIFmodDesigner.playSound( ev.eventData.sound )
			end
			if ev.eventData.speech then
				MOAIFmodDesigner.playSound( ev.eventData.speech )
			end			
 			modalDialog.showFirstAlarm( ev.eventData.txt, ev.eventData.txt2, ev.eventData.num, ev.eventData.num2, ev.eventData.txt3, ev.eventData.txt4 )
		end

	elseif ev.eventType == simdefs.EV_SHOW_PROGRAM then
		if not self._game.debugStep then
			if ev.eventData.showOnce then
				local settings = savefiles.getSettings( "settings" )
				settings.data.seenOnce = settings.data.seenOnce or {}
				if settings.data.seenOnce[ ev.eventData.showOnce ] then
					return -- Already seen
				else
					settings.data.seenOnce[ ev.eventData.showOnce ] = true
					settings:save()
				end
			end

			if ev.eventData.sound then
				MOAIFmodDesigner.playSound( ev.eventData.sound )
			end
			if ev.eventData.speech then
				MOAIFmodDesigner.playSound( ev.eventData.speech )
			end			
 			modalDialog.showProgram( ev.eventData.txt1, ev.eventData.txt2, ev.eventData.txt3, ev.eventData.icon, ev.eventData.color  )
		end

	elseif ev.eventType == simdefs.EV_SHOW_MISSION then
		self:showMission(ev.eventData.header,ev.eventData.body)

	elseif ev.eventType == simdefs.EV_REFRESH_OBJECTIVES then 
		self:refreshObjectives()

	elseif ev.eventType == simdefs.EV_UNIT_FLY_TXT then
		local wx, wy = self._game:cellToWorld(  ev.eventData.x, ev.eventData.y )
		local color =  ev.eventData.color
		local txt = ev.eventData.txt	
		local target = ev.eventData.target	
		self:showFlyText(wx, wy, txt, color, target)		

	elseif ev.eventType == simdefs.EV_HUD_SUBTRACT_CPU then
		self:subtractCPU( ev.eventData.delta)

	elseif ev.eventType == simdefs.EV_SKILL_LEVELED then
		if self._itemsPanel then
			 self._itemsPanel:refresh()
		end
	elseif ev.eventType == simdefs.EV_SHOW_DAEMON then
		MOAIFmodDesigner.playSound( simdefs.SOUND_SPEECH_WARNING_DAEMON )
		self:showDaemon( ev.eventData.name, ev.eventData.txt, ev.eventData.icon  )
	end

end


local function onInputEvent( self, event )
	local sim = self._game.simCore

	if self._state == STATE_ABILITY_TARGET then
		if event.eventType == mui_defs.EVENT_MouseDown and event.button == mui_defs.MB_Right then
			transition( self, STATE_NULL )
			return true
		
		elseif self._stateData.targetHandler then
			local target = self._stateData.targetHandler:onInputEvent( event )
			if target then
				agent_actions.performAbility( self._game, self._stateData.abilityOwner, self._stateData.abilityUser, self._stateData.ability, target )
				return true
			end
		end
		
	elseif self._state == STATE_ITEM_TARGET then
		if event.eventType == mui_defs.EVENT_MouseDown and event.button == mui_defs.MB_Right then
			transition( self, STATE_NULL )
			return true

		elseif self._stateData.targetHandler and self._stateData.targetHandler.onInputEvent then
			local target = self._stateData.targetHandler:onInputEvent( event )
			if target then
				agent_actions.performAbility( self._game, self._stateData.item, self._stateData.itemUser, self._stateData.ability, target )
				return true
			end
		end

	elseif self._isMainframe then
		if event.eventType == mui_defs.EVENT_KeyDown then
			if event.key == mui_defs.K_TAB then
				doSelectNextUnit( self )				
			elseif event.key == mui_defs.K_ESCAPE then			
				self:showPauseMenu()
			end
		end		
	
	elseif self._state == STATE_NULL then

		if event.eventType == mui_defs.EVENT_MouseUp then
			if event.button == mui_defs.MB_Left then
				local cellx, celly = self._game:wndToCell( event.wx, event.wy )
				doSelectUnit( self, cellx, celly )

			elseif event.button == mui_defs.MB_Right then
				local cellx, celly = self._game:wndToCell( event.wx, event.wy )
				local unit = self:getSelectedUnit()
				if unit then
					if cellx and doMoveUnit( self, unit, cellx, celly ) then
						MOAIFmodDesigner.playSound( cdefs.SOUND_HUD_GAME_CLICK )
					end
					return true		
				end
			end

		elseif event.eventType == mui_defs.EVENT_KeyDown then
			if event.key == mui_defs.K_TAB then
				doSelectNextUnit( self )				

			elseif event.key == mui_defs.K_ESCAPE then
				if not self:getSelectedUnit() then
					self:showPauseMenu()
				else
					self:selectUnit( nil )
				end
			end
		end

	elseif self._state == STATE_REPLAYING then
		if config.DEV and event.eventType == mui_defs.EVENT_KeyDown and event.key == mui_defs.K_TAB then
			self._game:skip()
			doSelectNextUnit( self )
		end
	end

	if event.eventType == mui_defs.EVENT_MouseMove then
		local x, y = self._game:wndToCell( event.wx, event.wy )
		if x ~= self._tooltipX or y ~= self._tooltipY then
			if self._state == STATE_NULL then
				local unit = self:getSelectedUnit()
				if unit and not unit._isPlayer then
					previewMovement( self, unit, x, y )			
				end
			end

			self._game.boardRig:onTooltipCell( x, y, self._tooltipX, self._tooltipY )
			self._tooltipX, self._tooltipY = x,y
		end

	end

	-- Cancel
	if self._state ~= STATE_NULL and self._state ~= STATE_REPLAYING then
		if (event.eventType == mui_defs.EVENT_KeyDown and event.key == mui_defs.K_ESCAPE) then
			transition( self, STATE_NULL )	
			showMovement( self, nil )
		end
	end

	if self._game:getCamera():onInputEvent( event ) then
		return true	
	end
	
	return false
end

local function transitionNull( self )
	transition( self, STATE_NULL )
end

local function transitionReplay( self, replay )
	--self._screen:setEnabled( not replay )
	if self._itemsPanel then
		self._itemsPanel._screen:setEnabled( not replay )
	end

	if replay then
		if self._state ~= STATE_REPLAYING then
			assert( self._state )
			transition( self, STATE_REPLAYING, { prevState = self._state, prevData = self._stateData })
		end
	else
		if self._state == STATE_REPLAYING then
			assert( self._stateData.prevState, util.stringize(self._stateData, 1))
			transition( self, self._stateData.prevState, self._stateData.prevData )
		end
	end
end

local function createHud( game, players )

	local t =
	{
		STATE_NULL = STATE_NULL,
		STATE_ABILITY_TARGET = STATE_ABILITY_TARGET,
		STATE_ITEM_TARGET = STATE_ITEM_TARGET,
		STATE_REPLAYING = STATE_REPLAYING,

		_game = game,
		_players = players,

		_state = STATE_NULL,
		_stateData = nil,
		_isMainframe = false,
		_movePreview = nil,
		_oldPlayerMainframeState = nil, 
		_mainframeOn = false, 
		_abilityPreview = false, 

		_lastSelectedUnitID = nil,
		_losUnits = {},
		_objectiveWidgets = {},
		_overwatchSafety = {},

		clearLOS = clearLOS,
		countSelectables = countSelectables,
		canSelect = canSelect,
		selectUnit = selectUnit,
		getSelectedUnit = getSelectedUnit,

		onClickMainframeBtn = onClickMainframeBtn,

		transitionNull = transitionNull,
		transitionReplay = transitionReplay,
		transitionAbilityTarget = transitionAbilityTarget,
		transitionItemTarget = transitionItemTarget,

		showMovement = showMovement,
		showMovementRange = showMovementRange,
		showOverwatchSafety = showOverwatchSafety,
		showMission = showMission,
		closeMission = closeMission,

		previewAbilityAP = previewAbilityAP, 

		onHudDraw = onHudDraw,
		onSimEvent = onSimEvent,
		onInputEvent = onInputEvent,
		refreshHud = refreshHud,
		refreshObjectives =refreshObjectives,
		destroyHud = destroyHud,
		updateHud = updateHud,
		subtractCPU = subtractCPU,

		startTitleSwipe = startTitleSwipe,
		stopTitleSwipe = stopTitleSwipe,	

		showFlyText = showFlyText,

		showPickupPanel = showPickupPanel,
		showLootPanel = showLootPanel,
		showShopPanel = showShopPanel,
		showTransferPanel = showTransferPanel,
		showWarning = showWarning,
		showDaemon = showDaemon,
		showPauseMenu = showPauseMenu,
		setAlarmVisible = setAlarmVisible,
		transferDaemonProgram = transferDaemonProgram,
		
		hideMainframe = hideMainframe,
		showMainframe = showMainframe,

		getCPULocation = getCPULocation,
		canShowElement = canShowElement
	}	

	t._world_hud = world_hud( game )

	t._screen = mui.createScreen( "hud.lua" )
	t._screen.onTooltip = util.makeDelegate( nil, onHudTooltip, t )
	
	t._agent_panel = agent_panel.agent_panel( t, t._screen )
	t._home_panel = home_panel.panel( t._screen, t )

	do
		local mainframe_panel = include( "hud/mainframe_panel" )
		t._mainframe_panel = mainframe_panel.panel( t._screen, t )
	end

	t._pause_dialog = pause_dialog( game )

	t._endTurnButton = t._screen.binder.endTurnBtn
	t._endTurnButton.onClick = util.makeDelegate(nil, onClickEndTurn, t)

	t._uploadGroup = t._screen.binder.upload_bar 
	
	t._screen.binder.menuBtn.onClick = util.makeDelegate( nil, onClickMenu, t )

	t._screen.binder.topPnl.binder.watermark:setText( config.WATERMARK )
	t._statusLabel = t._screen.binder.statusTxt
	t._tooltipLabel = t._screen.binder.tooltipTxt
	t._tooltipBg = t._screen.binder.tooltipBg

	t._screen.binder.warning:setVisible(false)
	t._screen.binder.objectivesTopLabel:setVisible( false )

	t._screen.binder.mainframe_centerDaemon:setVisible(false)


	local w,h = game.boardRig:getWorldSize()
	local scriptDeck = MOAIScriptDeck.new ()
	scriptDeck:setRect ( -w/2, -h/2, w/2, h/2 )
	scriptDeck:setDrawCallback ( 
		function( index, xOff, yOff, xFlip, yFlip )
			t:onHudDraw()
		end )

	t.hudProp = MOAIProp2D.new ()
	t.hudProp:setDeck ( scriptDeck )
	t.hudProp:setPriority( 1 ) -- above the board, below everything else
	game.layers["floor"]:insertProp ( t.hudProp )
	
	t._screen.binder.alarm.binder.alarmRing1:setVisible( false )
	t._screen.binder.alarm.binder.alarmRing1:setColor( 1, 0, 0, 1 ) 
	
	t._screen.binder.topPnl.binder.btnRotateLeft.onClick = util.makeDelegate( nil, onClickRotateCamera, t, -1 )
	t._screen.binder.topPnl.binder.btnRotateRight.onClick = util.makeDelegate( nil, onClickRotateCamera, t, 1 )
	t._screen.binder.statsPnl.binder.fastBtn.onClick = util.makeDelegate( nil, onClickToggleFast, t )

	local camera = t._game:getCamera()

	mui.activateScreen( t._screen )

	t:refreshHud()
		
	local mission_panel = include( "hud/mission_panel" )
	t._missionPanel = mission_panel( t, t._screen )

	t._blinkyCPUCount = 30 
	MOAIFmodDesigner.setAmbientReverb( "office" )

	return t
end

return
{
	createHud = createHud
}


