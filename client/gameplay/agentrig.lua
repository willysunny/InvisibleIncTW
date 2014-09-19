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
local rig_util = include( "gameplay/rig_util" )
local rand = include( "modules/rand" )
local binops = include( "modules/binary_ops" )
local unitrig = include( "gameplay/unitrig" )
local coverrig = include( "gameplay/coverrig" )
local world_hud = include( "hud/hud-inworld" )
local flagui = include( "hud/flag_ui" )
local simdefs = include( "sim/simdefs" )
local simquery = include( "sim/simquery" )
local psi_abilities = include( "sim/abilities/psi_abilities" )

-----------------------------------------------------------------------------------
-- Local

local function applyKanim( kanim, prop )
	if type(kanim.build) == "table" then
		for i,build in ipairs(kanim.build) do
			prop:bindBuild( KLEIResourceMgr.GetResource(build) )
		end
	elseif type(kanim.build) == "string" then
		prop:bindBuild( KLEIResourceMgr.GetResource(kanim.build) )
	end

	for i,anim in ipairs(kanim.anims) do
		prop:bindAnim( KLEIResourceMgr.GetResource(anim) )
	end

	for _,build in ipairs(kanim.wireframe or {}) do
		prop:bindWireframeBuild( KLEIResourceMgr.GetResource(build) )
	end
end

local function unapplyKanim( kanim, prop )
	if type(kanim.build) == "table" then
		for i,build in ipairs(kanim.build) do
			prop:unbindBuild( KLEIResourceMgr.GetResource(build) )
		end
	elseif type(kanim.build) == "string" then
		prop:unbindBuild( KLEIResourceMgr.GetResource(kanim.build) )
	end

	for i,anim in ipairs(kanim.anims) do
		prop:unbindAnim( KLEIResourceMgr.GetResource(anim) )
	end

	for _,build in ipairs(kanim.wireframe or {}) do
		prop:unbindWireframeBuild( KLEIResourceMgr.GetResource(build) )
	end
end

local function getLeanDir(unit)
	local cell = unit:getSim():getCell(unit:getLocation() )
	for _, dir in ipairs(simdefs.DIR_SIDES) do
		if simquery.checkIsWall(unit:getSim(), cell,dir) then
			local ldir, rdir = ( dir - 2 ) % simdefs.DIR_MAX, ( dir + 2 ) % simdefs.DIR_MAX

			if cell.exits[ldir] and not simquery.checkIsWall(unit:getSim(), cell.exits[ldir].cell, dir) then
				return simquery.getReverseDirection(dir) -- It's open to the left!
			end

			if cell.exits[rdir] and not simquery.checkIsWall(unit:getSim(), cell.exits[rdir].cell, dir) then
				return simquery.getReverseDirection(dir) -- It's open to the right!
			end
		end
	end
end

local function getCoverDir(unit)
	local cell = unit:getSim():getCell(unit:getLocation() )
	-- Any half-wall covers to hide behind?
	for _, dir in ipairs(simdefs.DIR_SIDES) do
		if simquery.checkIsHalfWall(unit:getSim(), cell, dir ) then
			return simquery.getReverseDirection(dir)
		end
	end
end

local function getIdleFacing(sim, unit)
	if unit:isPC() and unit:getLocation() and not unit:getTraits().takenDrone and not unit:getTraits().movingBody then
		-- Should lean against cover?
		local dir = getCoverDir(unit) 
		if dir then
			return dir
		end

		-- Should lean against a wall?
		dir = getLeanDir(unit)
		if dir then
			return dir
		end
	end
	return unit:getFacing()
end

local function getIdleAnim( sim, unit )
	
	if unit:isDead() or unit:getTraits().iscorpse then
		return "dead"

	elseif unit:isKO() then
		return "idle_ko"
		
	elseif unit:getTraits().isMeleeAiming and not unit:getTraits().hasObjectCover then
		return "overwatch_melee"

	elseif unit:getTraits().isAiming then
		return "overwatch"

	elseif unit:getTraits().isLyingDown then
		return "idle_ko"

	elseif unit:getTraits().movingBody then
		return "body_drag_idle"

	elseif simquery.isUnitPinning( sim, unit ) then						
		return "pin",nil,unit:getSounds().pin

	elseif unit:isPC() and unit:getLocation() and not unit:getTraits().takenDrone then
		local cell = sim:getCell( unit:getLocation() )
		-- Any half-wall covers to hide behind?
		local dir = getCoverDir(unit) 
		if dir then
			return "hide", dir, unit:getSounds().crouchcover
		end
		-- Should lean against a wall?
		dir = getLeanDir(unit)
		if dir then
			return "lean", dir, unit:getSounds().wallcover
		end

	end

	return "idle"
end

-----------------------------------------------------------------------------------
-- agentrig FSM

local function updateChannelingFX( boardRig, ability )
	-- This coroutine runs as long as it isn't aborted by the ability terminating.
	local rand = rand.createGenerator( os.time() )
	local cells = ability:getTargetCells()
	while cells and #cells > 0 do
		local cellIndex = rand:nextInt( 1, #cells / 2 ) * 2 - 1
		local x, y = cells[ cellIndex ], cells[ cellIndex + 1 ]
		local wx, wy = boardRig:cellToWorld( x, y )
		boardRig._game.fxmgr:addAnimFx( { kanim = "fx/psi_teleport_fx", symbol = "effect", anim = "idle", x = wx, y = wy, z = 42, layer = boardRig:getLayer() } )
		boardRig:wait( 30 )
	end
end

local function handleUseComp( self, unit, ev )
	if not ev.eventData.dontBlock then
		ev.thread:unblock()
	end
	if simquery.isUnitPinning(unit:getSim(), unit ) then
		self:waitForAnim("pin_stand")
	elseif getCoverDir(unit) then
		self:waitForAnim( "hide_pst", getIdleFacing(unit:getSim(), unit) )
	elseif getLeanDir(unit) then
		self:waitForAnim( "lean_pst", getIdleFacing(unit:getSim(), unit) )
	end

	local sounds = {{sound=ev.eventData.sound,soundFrames=ev.eventData.soundFrame}}

	local anim = "use_comp"
	if ev.eventData.useTinker then
		anim = "tinker"
	end
	self:waitForAnim( anim, ev.eventData.facing, nil, sounds)
	
	if ev.eventData.useTinker then
		self:waitForAnim( "tinker_pst", ev.eventData.facing, nil)
	end

	if ev.eventData.targetID then
		MOAIFmodDesigner.playSound("SpySociety/HUD/gameplay/node_capture")
		self._rig._boardRig:getUnitRig( ev.eventData.targetID ):addAnimFx( "gui/hud_fx", "wireless_console_takeover", "idle" )
	end

	local idleAnim, idleFacing, folleySnd = getIdleAnim( self._rig._boardRig:getSim(), unit )
	if folleySnd then
		self._rig:playSound(folleySnd)
	end	
	self:waitForAnim( idleAnim.."_pre", idleFacing)

	self._rig:setPlayMode( KLEIAnim.LOOP )
	self._rig:setCurrentAnim( idleAnim, idleFacing )


end

local function handlePeek( self, unit, ev )
	ev.thread:unblock()

	local t = ev.eventData.peekInfo
	if t and t.cellvizCount > 0 then
		self._rig._boardRig._game:cameraPanToCell( t.x0 + t.dx * 2, t.y0 + t.dy * 2 )
	end

	--foley
	if self._rig:getUnit():getSounds().peek then
		self._rig:playSound( self._rig:getUnit():getSounds().peek )
	end

	if ev.eventData.doorDir then
		if not simquery.isUnitPinning(unit:getSim(), unit ) then
			if getCoverDir(unit) then
				self:waitForAnim( "hide_pst", getIdleFacing(unit:getSim(), unit) )
			elseif getLeanDir(unit) then
				self:waitForAnim( "lean_pst", getIdleFacing(unit:getSim(), unit) )
			else
				self:waitForAnim( "door_peek_pre", ev.eventData.doorDir )
			end
		end
		self._rig:playSound( "SpySociety/Actions/door_peek")

		self:waitForAnim( "door_peek_pst", ev.eventData.doorDir )
	else
		if simquery.isUnitPinning(unit:getSim(), unit ) then
			self:waitForAnim("pin_stand")
		end
		self:waitForAnim( "peek_fwrd" )
		self:waitForAnim( "peek_pst_fwrd" )
	end

	local idleAnim, idleFacing, folleySnd = getIdleAnim( self._rig._boardRig:getSim(), unit )
	if folleySnd then
		self._rig:playSound(folleySnd)
	end
	self:waitForAnim( idleAnim.."_pre", idleFacing )
end

local function handleStand( self, unit )
	if unit:getSounds().getup then
		self._rig:playSound(unit:getSounds().getup)
	end

	if unit:getSounds().wakeup then
		self._rig:playSound(unit:getSounds().wakeup)
	end

	local oldFacing = self._rig:getFacing()	
	self:waitForAnim( "get_up",oldFacing)

	local orientation = self._rig._boardRig._game:getCamera():getOrientation()*2
	oldFacing = oldFacing - orientation

	if oldFacing < 0 then
		oldFacing = oldFacing + simdefs.DIR_MAX
	end
	
	local branchTimes = {11,9,9,17,nil,15,13,11}
	local branch = branchTimes[oldFacing+1]

	self:waitForAnim( "get_up_pst",nil,branch)
	self:waitForAnim( "idle_pre" )

	self._rig:transitionUnitState( self._rig._idleState )
end

-------------------------------------------------------------
local idle_state = class( unitrig.base_state )

function idle_state:init( rig )
	unitrig.base_state.init( self, rig, "idle" )
end

function idle_state:onEnter()
	local isCrouching = false
	local unit = self._rig:getUnit()

	local idleAnim, idleFacing, folleySnd = getIdleAnim( self._rig._boardRig:getSim(), unit )
	self._rig:setCurrentAnim( idleAnim, idleFacing )

	if unit:isGhost() then
		self._rig:setPlayMode( KLEIAnim.STOP )
	else
		if idleAnim == "overwatch" then
			self._rig:setPlayMode( KLEIAnim.ONCE )
		else
			self._rig:setPlayMode( KLEIAnim.LOOP )
		end
	end

	if psi_abilities.isChanneling( unit ) then
		if self._channelFX == nil then
			self._channelFX = self._rig:addAnimFx( "fx/psi_channel_caster_fx", "effect", "idle", true, { loop = true, z = isCrouching and 24 or 42} )
		end
		local channelAbility = unit:getTraits().psi_ability
		if channelAbility and channelAbility.getTargetCells then
			if self._channelTargetCoroutine == nil then
				self._channelTargetCoroutine = MOAICoroutine.new()
				self._channelTargetCoroutine:run( updateChannelingFX, self._rig._boardRig, channelAbility )
			end
		end
	end
end

function idle_state:onExit()
	if self._channelFX then
		self._channelFX:destroy()
		self._channelFX = nil
	end
	if self._channelTargetCoroutine then
		self._channelTargetCoroutine:stop()
		self._channelTargetCoroutine = nil
	end
end

function idle_state:onSimEvent( ev, eventType, eventData )
	local unit = self._rig:getUnit()
	if unit:isGhost() then
		if eventType == simdefs.EV_UNIT_START_WALKING then
			self._rig:transitionUnitState( self._rig._walkState, ev )
		end

	else
		unitrig.base_state.onSimEvent( self, ev, eventType, eventData )
	
		if eventType == simdefs.EV_UNIT_START_WALKING then
			self._rig:transitionUnitState( self._rig._walkState, ev )

		elseif eventType == simdefs.EV_UNIT_START_SHOOTING then
			self._rig:refreshLocation()	
			self._rig:transitionUnitState( self._rig._shootState, ev )
		
		elseif eventType == simdefs.EV_UNIT_HIT then
			self._rig:transitionUnitState( self._rig._hitState, ev, self._rig._idleState )	
			
		elseif eventType == simdefs.EV_UNIT_RELOADED then
			self._rig:transitionUnitState( self._rig._reloadState, ev )				

		elseif eventType == simdefs.EV_UNIT_USEDOOR then
			self._rig:refreshLocation()	
			self._rig:transitionUnitState( self._rig._usedoorState, ev )	

		elseif eventType == simdefs.EV_UNIT_HEAL then
			self._rig:refreshLocation()	
			self._rig:transitionUnitState( self._rig._healState, ev )

		elseif eventType == simdefs.EV_UNIT_INSTALL_AUGMENT then 
			self._rig:addAnimFx( "fx/emp_effect", "character", "idle", true )	

		elseif eventType == simdefs.EV_UNIT_PICKUP then
			self._rig:refreshLocation()	
			self._rig:transitionUnitState( self._rig._pickupState, ev )	

		elseif eventType == simdefs.EV_UNIT_KO then
            if eventData.stand then
                handleStand( self, eventData.unit )
            else
                self:waitForAnim( "ko" )
                self._rig:refresh()
    			self._rig:eraseInterest()
            end

		elseif eventType == simdefs.EV_UNIT_MELEE then		
			self._rig:refreshLocation()
			self._rig:transitionUnitState( self._rig._meleeState, ev )	

		elseif eventType == simdefs.EV_UNIT_DEATH then
			local sounds = {{sound=simdefs.SOUNDPATH_DEATH_HARDWOOD ,soundFrames=35}}	
			if unit:getSounds().fall then
				table.insert(sounds,{sound=unit:getSounds().fall,soundFrames=3})
			end
			self:waitForAnim( "death", nil,nil, sounds )
            self._rig:refresh()
			self._rig:eraseInterest()

		elseif eventType == simdefs.EV_UNIT_USECOMP then
			handleUseComp( self, unit, ev )

		elseif eventType == simdefs.EV_UNIT_LOOKAROUND then
			self._rig:refreshLocation()	
			self._rig:transitionUnitState( self._rig._lookaroundState, ev )	

		elseif eventType == simdefs.EV_UNIT_DRAG_BODY then
			self._rig:refreshLocation()
			self._rig:refreshHUD( unit )
			self._rig:transitionUnitState( self._rig._dragBodyState, ev )

		elseif eventType == simdefs.EV_UNIT_DROP_BODY then
			self._rig:refreshLocation()	
			self._rig:refreshHUD( unit )
			self._rig:transitionUnitState( self._rig._dropBodyState, ev )	

		elseif eventType == simdefs.EV_UNIT_BODYDROPPED then
			self._rig:refreshLocation()	
			self._rig:refreshProp()
			self._rig:transitionUnitState( self._rig._bodyDropState, ev )	

		elseif eventType == simdefs.EV_UNIT_DONESEARCHING then
			self._rig:refreshLocation()	
			self._rig:transitionUnitState( self._rig._shrugState, ev )	

		elseif eventType == simdefs.EV_UNIT_TURN then
			self._rig:refreshLocation()
			self._rig:refreshProp()

		elseif eventType == simdefs.EV_UNIT_PEEK then
			handlePeek( self, unit, ev )

		elseif eventType == simdefs.EV_UNIT_HIDE_FLAGS then
			self._rig:hideFlags( ev.eventData.hideFlags )


		elseif eventType == simdefs.EV_UNIT_OVERWATCH_MELEE then			
			if not unit:getTraits().hasObjectCover then
				self:waitForAnim( "overwatch_melee_pre" )			
				self:onEnter()
			end

		elseif eventType == simdefs.EV_UNIT_OVERWATCH then			
			
			self:waitForAnim( "overwatch_pre" )			
			self:onEnter()

		end
	end
end

-------------------------------------------------------------

local walking_state = class( unitrig.base_state )

function walking_state:init( rig )
	unitrig.base_state.init( self, rig, "walking" )
end

function walking_state:onEnter( ev )
	unitrig.base_state.onEnter( self )
	
	self._wasSeen = self._rig._boardRig:canPlayerSee( self._rig:getLocation() )
	self._beenSeen = self._wasSeen

	-- Only perform preamble if visible, not if invisible or ghosted.
	if self._wasSeen then
		local unit = self._rig:getUnit()
		if unit:getPlayerOwner() == self._rig._boardRig:getLocalPlayer() then
			self._rig._boardRig:cameraLock( self._rig:getProp() )
		end

		if unit:getUnitData().sounds.walk_pre then
			self._rig:playSound( unit:getUnitData().sounds.walk_pre )
		end	

		if unit:getTraits().walk and not unit:getTraits().movingBody then
			-- Note: ev may be nil if we entered not because of EV_START_WALKING, but perhaps some other event (eg. EV_UNIT_HIT)
			if ev and ev.eventData.reverse and not unit:getTraits().isDrone then
				self._rig:setCurrentAnim( "walk180")
			else
				self:waitForAnim( "walk_pre" )
			end
		end
	end

	if self._rig:getUnit():getSounds().move_loop then
		self._rig:playSound( self._rig:getUnit():getUnitData().sounds.move_loop, "move_loop" )
 	end			
	if self._rig:getUnit():getTraits().movingBody then
		self._rig:playSound(simdefs.SOUNDPATH_DRAG_HARDWOOD, "drag_loop" )
		self._draggingBody = true
 	end			
end

function walking_state:onExit()
	unitrig.base_state.onExit( self )

	self._rig._boardRig:cameraLock( nil )
	self._rig:refreshProp( true )

	if self._easeDriver ~= nil then
		self._easeDriver:stop()
		self._easeDriver = nil
	end

	if self._losDriver ~= nil then
		self._losDriver:stop()
		self._losDriver = nil
	end
	if self._losProp then
		self._rig._boardRig:refreshLOSCaster( self._rig._unitID )
		self._losProp = nil
	end
	
	if self._rig:getUnit():getSounds().move_loop then
		MOAIFmodDesigner.stopSound( "move_loop")
	end	
	if self._rig:getUnit():getTraits().movingBody or self._draggingBody then
		--movingBody might be nil after getting a move interrupted
		MOAIFmodDesigner.stopSound( "drag_loop")
		self._draggingBody = nil
	end	

	self:destroyGhostFade()
end

function walking_state:onSimEvent( ev, eventType, eventData )
	if eventType == simdefs.EV_UNIT_STOP_WALKING then

		if self._rig:getUnit():getSounds().move_loop then
			MOAIFmodDesigner.stopSound( "move_loop")
		end	
		if self._rig:getUnit():getTraits().movingBody then
			MOAIFmodDesigner.stopSound( "drag_loop")
		end	

		if self._wasSeen then
			
			self._rig:refreshLocation()

			local unit = self._rig:getUnit()
			if unit:getTraits().movingBody then
				self:waitForAnim("body_drag_pst")
			elseif unit:getTraits().walk then
				self:waitForAnim( "walk_pst" )
			elseif not unit:getTraits().hasObjectCover then 			
				self:waitForAnim( "run_pst" )
			else
				local idleAnim, idleFacing, folleySnd = getIdleAnim( self._rig._boardRig:getSim(), unit )
				if folleySnd then
					self._rig:playSound(folleySnd)					
				end					
				self:waitForAnim( idleAnim.."_pre", idleFacing )
			end
			if simquery.isUnitPinning( self._rig._boardRig:getSim(), unit ) then
				self:waitForAnim( "pin_pre" )
			end
		end

		self._rig:transitionUnitState( self._rig._idleState )
		return true

	elseif eventType == simdefs.EV_UNIT_REFRESH then
		-- Don't do a full refresh, we're in the middle of walking.
		self._rig:refreshHUD( self._rig:getUnit() )

		if not self._wasSeen then
			self._rig:refreshLocation()
            self._rig:refreshProp( false )           
        end

		return true

	elseif eventType == simdefs.EV_UNIT_UNGHOSTED then
		return true

	elseif eventType == simdefs.EV_UNIT_WARPED then
		-- Don't just warp, continue ambulating!
		if ev.eventData.from_cell ~= ev.eventData.to_cell then
			self:performStep( ev )
		end
		return true

	elseif eventType == simdefs.EV_UNIT_DEATH then
		self._rig:eraseInterest()
		self._rig:transitionUnitState( self._rig._idleState )
		return true

	elseif eventType == simdefs.EV_UNIT_HIT then
		self._rig:transitionUnitState( self._rig._hitState, ev, self._rig._walkState )
		return true
	end
end

function walking_state:refreshLOSCaster( seerID )
	if self._losProp then
		local seer = self._rig:getUnit()
		local bAgentLOS = (seer:getPlayerOwner() == self._rig._boardRig:getLocalPlayer())
		local type = bAgentLOS and KLEIShadowMap.ALOS_DIRECT or KLEIShadowMap.ELOS_DIRECT
		local arcStart = seer:getFacingRad() - simquery.getLOSArc( seer )/2
		local arcEnd = seer:getFacingRad() + simquery.getLOSArc( seer )/2
		local range = seer:getTraits().LOSrange and self._rig._boardRig:cellToWorldDistance( seer:getTraits().LOSrange )

		self._rig._boardRig._game.shadow_map:insertLOS( type, seerID, arcStart, arcEnd, range, self._losProp )

		if seer:getTraits().LOSperipheralArc then
			local range = seer:getTraits().LOSperipheralRange and self._rig._boardRig:cellToWorldDistance( seer:getTraits().LOSperipheralRange )
			local losArc = seer:getTraits().LOSperipheralArc
			local arcStart = seer:getFacingRad() - losArc/2
			local arcEnd = seer:getFacingRad() + losArc/2

			self._rig._boardRig._game.shadow_map:insertLOS( KLEIShadowMap.ELOS_PERIPHERY, seerID + simdefs.SEERID_PERIPHERAL, arcStart, arcEnd, range, self._losProp )
		end
		return true
	end
end

function walking_state:destroyGhostFade()
	if self._fadeTimer then
		self._rig._prop:clearAttrLink( KLEIAnim.ATTR_A_FILTER_COL )
		self._fadeTimer:stop()
		self._fadeTimer = nil
		self._rig._renderFilterOverride = nil
		self._rig:refreshRenderFilter()
	end
end

function walking_state:createGhostFade( walkTime, a, b )
	local curve = MOAIAnimCurve.new()
	curve:reserveKeys ( 2 )
	curve:setKey ( 1, 0, a )
	curve:setKey ( 2, walkTime, b )

	local timer = MOAITimer.new()
	timer:setSpan ( 0, curve:getLength() )
	timer:setMode( MOAITimer.NORMAL )

	curve:setAttrLink ( MOAIAnimCurve.ATTR_TIME, timer, MOAITimer.ATTR_TIME )

	timer:start()

	self._rig._prop:setAttrLink(KLEIAnim.ATTR_A_FILTER_COL, curve, MOAIAnimCurve.ATTR_VALUE )

	if self._fadeTimer ~= nil then
		self._fadeTimer:stop()
	end

	self._fadeTimer = timer

	self._rig._renderFilterOverride = cdefs.RENDER_FILTERS["ghost"]
end

function walking_state:performStep( ev )
	local from_cell = ev.eventData.from_cell
	local to_cell = ev.eventData.to_cell
	local isStealth = ev.eventData.unit:getTraits().sneaking

	local soundRange = simdefs.SOUND_RANGE_1
	if ev.eventData.unit:getPlayerOwner():isNPC() then
		soundRange = simdefs.SOUND_RANGE_2		
	elseif isStealth then
		soundRange = simdefs.SOUND_RANGE_0
	end

	local isSeen = self._rig._boardRig:canPlayerSeeUnit( ev.eventData.unit )
	local WALKSPEED = 0.16 -- In cells/second
	if ev.eventData.unit:getTraits().movingBody then
		WALKSPEED = 0.36
	elseif ev.eventData.unit:getTraits().walk then
		WALKSPEED = 0.32
	elseif ev.eventData.unit:getTraits().sneaking then
		WALKSPEED = 0.16
	end
	local settingsFile = savefiles.getSettings( "settings" )
	if settingsFile.data.fastMode then
		WALKSPEED = WALKSPEED * 0.5
	end

	local walkTime = mathutil.dist2d( from_cell.x, from_cell.y, to_cell.x, to_cell.y ) * config.WARPSPEED * WALKSPEED

	-- Need to make flag frontmost, in case we're walking past some dead dudes.
	if self._rig._flagUI then
		self._rig._flagUI:moveToFront()
	end

	local foot_frames = simdefs.FOOTSTEP_FRAMES_RUN
	if isSeen then
		self._rig:setPlayMode( KLEIAnim.LOOP )

		if self._rig:getUnit():getTraits().movingBody then
			self._rig:setCurrentAnim("body_drag", simquery.getReverseDirection(self._rig:getUnit():getFacing() ) )
		elseif self._rig:getUnit():getTraits().walk then
			if not ev.eventData.reverse then
				self._rig:setCurrentAnim( "walk" )
				foot_frames = simdefs.FOOTSTEP_FRAMES_WALK
			end
		elseif self._rig:getUnit():getTraits().sneaking then
			self._rig:setCurrentAnim( "snk" )
			foot_frames = simdefs.FOOTSTEP_FRAMES_SNK
		else
			self._rig:setCurrentAnim( "run" )
			foot_frames = simdefs.FOOTSTEP_FRAMES_RUN
		end
	end
		
	if isSeen and not self._wasSeen then
		self:createGhostFade( walkTime * 0.7, 0.8, 1 ) -- Fade in from FOW
	elseif not isSeen and self._wasSeen then
		self:createGhostFade( walkTime * 0.7, 1, 0.8 ) -- Fade out into FOW
	end

	-- Update correct anim facing and render filter according to rig location (if visibility changes, we may become ghosted)
	if self._wasSeen or isSeen then
		self._rig:setLocation( to_cell.x, to_cell.y )
		self._rig._facing = simquery.getDirectionFromDelta( to_cell.x - from_cell.x, to_cell.y - from_cell.y )

		self._rig:refreshProp( true )
	end

	if self._wasSeen or isSeen or self._rig._boardRig:canPlayerHear( to_cell.x, to_cell.y, soundRange ) then

		if self._wasSeen or isSeen then
			-- Perform the actual movement interpolation if we are or were visible.
			local x0, y0 = self._rig._boardRig:cellToWorld( from_cell.x, from_cell.y )
			local x1, y1 = self._rig._boardRig:cellToWorld( to_cell.x, to_cell.y )
			self._rig._prop:setLoc( x0, y0 )

			local ease = MOAIEaseType.LINEAR
			if ev.eventData.reverse then
				ease = MOAIEaseType.LINEAR
			end

			self._easeDriver = self._rig._prop:seekLoc( x1, y1, 0, walkTime, ease )

			if self._losProp == nil then
				self._losProp = MOAITransform.new()
				self:refreshLOSCaster( self._rig._unitID )
			end
			self._losProp:setLoc( x0, y0 )
			self._losDriver = self._losProp:seekLoc( x1, y1, 0, walkTime, ease )

		else
			-- Otherwise, just fake the timing; we need to play sounds.
			local timer = MOAITimer.new ()
			timer:setSpan( 0, walkTime )
			timer:start()
			self._easeDriver = timer
		end

		if ev.eventData.unit:getSounds().move_loop then
			local x1, y1 = self._rig._boardRig:cellToWorld( to_cell.x, to_cell.y )
			MOAIFmodDesigner.setSoundProperties( "move_loop", nil, {x1,y1,0}, nil )
		end	
		if ev.eventData.unit:getTraits().movingBody then
			local x1, y1 = self._rig._boardRig:cellToWorld( to_cell.x, to_cell.y )
			MOAIFmodDesigner.setSoundProperties( "drag_loop", nil, {x1,y1,0}, nil )
		end	


		local stepSound
		if isStealth then
			stepSound = ev.eventData.unit:getSounds().stealthStep			
		else
			stepSound = ev.eventData.unit:getSounds().step
		end

		local frames = foot_frames
		local sounds =  { stepSound, ev.eventData.unit:getSounds().rustle,	}

		if self._rig:getUnit():getSounds().move then
			table.insert(frames,2)
			table.insert(sounds,self._rig:getUnit():getSounds().move)
		end

		self:wait(self._easeDriver,{ 
									{
										frames = frames,
										sounds = sounds,
										x = to_cell.x,
										y = to_cell.y,
									},
									} )

		self._easeDriver = nil

	elseif self._beenSeen then
		self:waitDuration( walkTime )
	end

	self._rig:refreshHUD( self._rig:getUnit() )
	self:destroyGhostFade()

	self._wasSeen = isSeen
	self._beenSeen = self._beenSeen or isSeen
end

-------------------------------------------------------------

local shoot_state = class( unitrig.base_state )

function shoot_state:init( rig )
	unitrig.base_state.init( self, rig, "shoot")	
	--save cam location
end

function shoot_state:onSimEvent( ev, eventType, eventData )

	local animName = nil

	if eventType == simdefs.EV_UNIT_STOP_SHOOTING then

		if self._rig:getUnit():getTraits().hasObjectCover then 
			animName = "shootcover_pst" 
		else
			animName = "shoot_pst"
		end

		self:waitForAnim(animName)

		self._rig:refreshLocation()	
		self._rig:refreshProp( false)
		self._rig:transitionUnitState( self._rig._idleState )

	elseif eventType == simdefs.EV_UNIT_SHOT then
		local branch = nil
		if eventData.dmgt.shots > 1 then
			branch = 2
		end
		local shotAnim = 1
		local x0,y0 = self._rig:getUnit():getLocation()
		for shotNum = 1, eventData.dmgt.shots do
			self._rig:playSound( eventData.dmgt.sound )
 		
			if shotNum > 1 then
				shotAnim = math.ceil( math.random() *3) 
			end

			if self._rig:getUnit():getTraits().hasObjectCover then 
				animName = "shootcover" .. shotAnim
			else
				animName = "shoot" .. shotAnim
			end

			self._rig:setCurrentAnim( animName, self._rig:getFacing() )
			self._rig._prop:setFrame( 0 )
			self:waitForAnim(animName, nil, branch)
		end

		self._rig._boardRig._game:cameraPanToCell( eventData.x1, eventData.y1 )
		self._rig._boardRig:wait( 30 )
	end
end

function shoot_state:onEnter( ev )
	local unit = self._rig:getUnit()

	if ev.eventData.overwatch and not unit:getPlayerOwner():isNPC() and not unit:getTraits().isDrone then

		local facing = ev.eventData.newFacing
		local oldFacing = ev.eventData.oldFacing
			

		local orientation = self._rig._boardRig._game:getCamera():getOrientation()*2
		facing = facing - orientation
		if facing < 0 then
			facing = facing + simdefs.DIR_MAX
		end
		oldFacing = oldFacing - orientation
		if oldFacing < 0 then
			oldFacing = oldFacing + simdefs.DIR_MAX
		end
		
		if oldFacing == 2 or oldFacing == 3 or oldFacing == 4 then
			if facing == 6 then
				facing = 4 
			elseif facing == 4 then
				facing = 6
			elseif facing == 7 then
				facing= 3 
			elseif facing == 3 then
				facing = 7
			elseif facing == 0 then
				facing = 2
			elseif facing == 2 then
				facing = 0
			end
		end


	 	self:waitForAnim( "overwatch_switch_"..facing, oldFacing)
	else
		if self._rig:getUnit():getTraits().hasObjectCover then 
			self:waitForAnim( "shootcover_pre" ,nil, 8 )
		else
			self:waitForAnim( "shoot_pre" ,nil, 8 )
		end
	end
end

function shoot_state:onExit()
	unitrig.base_state.onExit( self )

	self._rig._prop:setListener( KLEIAnim.EVENT_ANIM_END, nil )
end

-------------------------------------------------------------

local hit_state = class( unitrig.base_state )

function hit_state:init( rig )
	unitrig.base_state.init( self, rig, "hit" )
end


function hit_state:onEnter( ev, previousState, ... )
	unitrig.base_state.onEnter( self )

	if previousState then
		self._previousState = previousState
		self._previousStateArgs = { ... }
	else
		self._previousState, self._previousStateArgs = nil, nil
	end
	
	self:doHit(ev)
end

function hit_state:doHit(ev)
	local unit = self._rig:getUnit()
	local x1, y1 = unit:getLocation()
	local prop  = self._rig._prop

	if ev.eventData.txt then
		self._rig._boardRig:showFloatText( x1, y1, ev.eventData.txt )
	end

	self._rig:refreshHUD( unit )

	if ev.eventData.fx == "emp" then
		self._rig:addAnimFx( "fx/emp_effect", "character", "idle", true )
	end

	if ev.eventData.crit == true then
		if unit:getTraits().hits == "blood" then
			prop:setSymbolVisibility( "blood_crit", true)	
		elseif unit:getTraits().hits == "spark" then
			prop:setSymbolVisibility( "sparks2", true )	
		end
	else
		prop:setSymbolVisibility( "sparks2", "blood_crit", false )	
	end

	if unit:isDead() then
		self._rig:transitionUnitState( self._rig._idleState )

	elseif unit:isKO() then
		self._rig:transitionUnitState( self._rig._idleState )

	else
		if ev.eventData.dir == "frt" then 
			self:waitForAnim( "hitfrt", self._rig:getFacing() )
			self:waitForAnim( "hitfrt_pst" )
		else
			self:waitForAnim( "hitbck", self._rig:getFacing() )
			self:waitForAnim( "hitbck_pst" )
		end

		local idleAnim, idleFacing, folleySnd = getIdleAnim( self._rig._boardRig:getSim(), unit )
		if folleySnd then
			self._rig:playSound(folleySnd)			
		end			
		self:waitForAnim( idleAnim.."_pre", idleFacing )

		self._rig:transitionUnitState( self._previousState, unpack( self._previousStateArgs ) )			
	end

end

-------------------------------------------------------------

local reload_state = class( unitrig.base_state )

function reload_state:init( rig )
	unitrig.base_state.init( self, rig, "reload" )
end

function reload_state:onEnter( ev )
	unitrig.base_state.onEnter( self )

	
	local unit = self._rig:getUnit()
	if getCoverDir(unit) then
		self:waitForAnim( "hide_reload", getCoverDir(unit) )
	elseif getLeanDir(unit) then
		self:waitForAnim( "lean_reload", getLeanDir(unit) )
	else
		self:waitForAnim( "shoot_pre" )
		self:waitForAnim( "reload")
		self:waitForAnim( "shoot_pst" )
	end

	
	self._rig:transitionUnitState( self._rig._idleState )
end

--------------------------------------------------------------------

local usedoor_state = class( unitrig.base_state )

function usedoor_state:init( rig )	
	unitrig.base_state.init( self, rig, "usedoor" )		
end

function usedoor_state:onSimEvent( ev, eventType, eventData )
	if eventType == simdefs.EV_UNIT_USEDOOR_PST then
		self:waitForAnim( "use_door_pst", eventData.facing )	


		local unit = self._rig:getUnit()
		
		local idleAnim, idleFacing, folleySnd = getIdleAnim( self._rig._boardRig:getSim(), unit )
		if folleySnd then
			self._rig:playSound(folleySnd)			
		end
		if idleAnim ~= "idle" then
			self:waitForAnim( idleAnim.."_pre", idleFacing )
		end

		self._rig:transitionUnitState( self._rig._idleState )
	elseif eventType == simdefs.EV_UNIT_REFRESH then
		--this usually happens when we open a door to a room with a camera/other agent in it, and they call refresh on us because we became seen
		--do nothing with it for now, and hope that doesn't lead to werid behaviour later if we actually need to refresh
		return true
	elseif eventType == simdefs.EV_UNIT_HIT then
		self._rig:transitionUnitState( self._rig._hitState, ev, self._rig._idleState )
		return true
	end

end

function usedoor_state:onEnter( ev )
	unitrig.base_state.onEnter( self )


	local unit = self._rig:getUnit()
	if simquery.isUnitPinning(unit:getSim(), unit ) then
		self:waitForAnim("pin_stand")
	elseif getCoverDir(unit) then
		self:waitForAnim( "hide_pst", getIdleFacing(unit:getSim(), unit) )
	elseif getLeanDir(unit) then
		self:waitForAnim( "lean_pst", getIdleFacing(unit:getSim(), unit) )
	end

	local sounds = {{sound=ev.eventData.sound ,soundFrames=ev.eventData.soundFrame}}
	self:waitForAnim( "use_door", ev.eventData.facing, nil, sounds )
end
--------------------------------------------------------------------

local heal_state = class( unitrig.base_state )

function heal_state:init( rig )	
	unitrig.base_state.init( self, rig, "heal" )		
end

function heal_state:onEnter( ev )
	unitrig.base_state.onEnter( self )

	self._rig:playSound("SpySociety/Actions/heal") 
	if ev.eventData.revive then
		self:waitForAnim( "revive", ev.eventData.facing )
	elseif ev.eventData.unit ==  ev.eventData.target then
		self:waitForAnim( "heal", ev.eventData.facing )
	else
		self:waitForAnim( "heal_team", ev.eventData.facing )
	end
	
	local idleAnim, idleFacing, folleySnd = getIdleAnim( self._rig._boardRig:getSim(), self._rig:getUnit() )
	if folleySnd then
		self._rig:playSound(folleySnd)		
	end		
	self:waitForAnim( idleAnim.."_pre", idleFacing )

	self._rig:transitionUnitState( self._rig._idleState )
end
--------------------------------------------------------------------

local pickup_state = class( unitrig.base_state )

function pickup_state:init( rig )	
	unitrig.base_state.init( self, rig, "pickup" )		
end

function pickup_state:onEnter( ev )
	unitrig.base_state.onEnter( self )

	self._rig:refreshProp()
	self:waitForAnim( "pick_up" )


	self._rig:transitionUnitState( self._rig._idleState )
end

--------------------------------------------------------------------

local grappled_state = class( unitrig.base_state )

function grappled_state:onSimEvent( ev, eventType, eventData )
	if eventType == simdefs.EV_UNIT_DEATH then
		self._rig:transitionUnitState( self._rig._idleState )
	else
		unitrig.base_state.onSimEvent( ev, eventType, eventData )
	end
end
--------------------------------------------------------------------

local melee_state = class( unitrig.base_state )

function melee_state:init( rig )	
	unitrig.base_state.init( self, rig, "melee" )		
end

function melee_state:onEnter( ev )
	unitrig.base_state.onEnter( self )

	local targetUnitID = ev.eventData.targetUnit:getID()
	local targetRig = self._rig._boardRig:getUnitRig(targetUnitID)

	if ev.eventData.meleeSuccess == true and ev.eventData.grapple == true then 
		targetRig:transitionUnitState( grappled_state( targetRig ))

		local presounds = {}
		if self._rig:getUnit():getUnitData().gender == "male" then
			presounds = {
				{sound="SpySociety/HitResponse/hitby_grab_flesh",soundFrames=4},
				{sound="SpySociety/Agents/<voice>/grabbed_vocals",soundFrames=5, source=targetRig}
			}
		end

		self:waitForAnim( "melee_grp_pre",nil,nil,presounds )

		local grp_build = targetRig._kanim[ "grp_build" ][1]
		self._rig._prop:bindBuild(KLEIResourceMgr.GetResource(grp_build))

        local enemyWpn = simquery.getEquippedGun(targetRig:getUnit())
        if enemyWpn then
            local weaponAnim = animmgr.lookupAnimDef( enemyWpn:getUnitData().weapon_anim )
            if weaponAnim and weaponAnim.grp_build then
        		self._rig._prop:bindBuild(KLEIResourceMgr.GetResource(weaponAnim.grp_build))
            end
        end

		local OB = { self._rig._prop:getBounds() }
		local TWB = { targetRig._prop:getWorldBounds() }
		local OWB = { self._rig._prop:getWorldBounds() }
		local CWB =
		{
			math.min( TWB[1], OWB[1] ), --min x
			math.min( TWB[2], OWB[2] ), --min y
			math.min( TWB[3], OWB[3] ), --min z
			math.max( TWB[4], OWB[4] ), --max x
			math.max( TWB[5], OWB[5] ), --max y
			math.max( TWB[6], OWB[6] ), --max z
		}
		self._rig._prop:setWorldBounds( unpack( CWB ) )

		targetRig._prop:setVisible(false)

		local unit = self._rig:getUnit()

		if unit:getSounds().grab then
			self._rig:playSound( unit:getSounds().grab)
		end

		local targetUnit = targetRig:getUnit()
		if targetUnit:getSounds().grabbed then
			self._rig:playSound( targetUnit:getSounds().grabbed)
		end		

		local sounds = {}
		if self._rig:getUnit():getUnitData().gender == "male" then
			sounds = {
				--{sound="SpySociety/HitResponse/hitby_punch_flesh",soundFrames=5},
				{sound="SpySociety/HitResponse/hitby_energy_flesh",soundFrames=5},
				{sound="SpySociety/Agents/<voice>/hurt_small",soundFrames=6, source=targetRig},
				{sound="SpySociety/Movement/bodyfall_agent_hardwood",soundFrames=47},
                {sound="SpySociety/HitResponse/hitby_floor_flesh",soundFrames=48}
            }
		else
			sounds = {
				{sound="SpySociety/HitResponse/hitby_grab_flesh",soundFrames=1},
				{sound="SpySociety/Agents/<voice>/grabbed_vocals",soundFrames=2, source=targetRig},
		        {sound="SpySociety/HitResponse/hitby_floor_flesh",soundFrames=17},
				{sound="SpySociety/Movement/bodyfall_agent_hardwood",soundFrames=18},
				{sound="SpySociety/HitResponse/hitby_energy_flesh",soundFrames=35},
				{sound="SpySociety/Agents/<voice>/hurt_small",soundFrames=36, source=targetRig},
			}
		end			
	
		if unit:getSounds().fall then
			table.insert(sounds,{sound=unit:getSounds().fall,soundFrames=12})
		end

		self:waitForAnim( "melee_grp",nil, nil, sounds )

		self._rig._prop:unbindBuild(KLEIResourceMgr.GetResource(grp_build))
		targetRig:setCurrentAnim( "idle_ko" )
		self._rig._prop:setBounds( unpack( OB ) )

		targetRig._prop:setVisible(true)

		self._rig:transitionUnitState( self._rig._idleState )

	else
		self._rig:playSound("SpySociety/HitResponse/hitby_punch_flesh")
		self:waitForAnim( "melee" )

		if not ev.eventData.meleeSuccess then 
			local x1, y1 = ev.eventData.targetUnit:getLocation()
			self._rig._boardRig:showFloatText( x1, y1, "ENEMY ARMORED!" )
		end

		local thread = ev.viz:spawnViz(
			function()
				self:waitForAnim( "melee_pst" )
				self:waitForAnim( "idle_pre" )
				self._rig:transitionUnitState( self._rig._idleState )
			end )
		thread:unblock()
	end
end

--------------------------------------------------------------------
local dragbody_state = class( unitrig.base_state )

function dragbody_state:init( rig )	
	unitrig.base_state.init( self, rig, "dragbody" )		
end

function dragbody_state:onEnter( ev )
	unitrig.base_state.onEnter( self )

	local targetUnitID = ev.eventData.targetUnit:getID()
	local targetRig = self._rig._boardRig:getUnitRig(targetUnitID)
	local targetUnit = targetRig:getUnit()
	local unit = self._rig:getUnit()



	local grp_build = targetRig._kanim[ "grp_build" ][1]
	self._rig._prop:bindBuild(KLEIResourceMgr.GetResource(grp_build))
	targetRig._prop:setVisible(false)

	local sounds = {}
	if self._rig:getUnit():getUnitData().gender == "male" then
		sounds = {
			--{sound="SpySociety/HitResponse/hitby_punch_flesh",soundFrames=5},
			-- {sound="SpySociety/HitResponse/hitby_energy_flesh",soundFrames=5},
			-- {sound="SpySociety/Agents/<voice>/hurt_small",soundFrames=6, source=targetRig},
			-- {sound="SpySociety/Movement/bodyfall_agent_hardwood",soundFrames=22},
   --          {sound="SpySociety/HitResponse/hitby_floor_flesh",soundFrames=23}
        }
	else
		sounds = {
			-- {sound="SpySociety/HitResponse/hitby_grab_flesh",soundFrames=1},
			-- {sound="SpySociety/Agents/<voice>/grabbed_vocals",soundFrames=2, source=targetRig},
	  --       {sound="SpySociety/HitResponse/hitby_floor_flesh",soundFrames=17},
			-- {sound="SpySociety/Movement/bodyfall_agent_hardwood",soundFrames=18},
			-- {sound="SpySociety/HitResponse/hitby_energy_flesh",soundFrames=38},
			-- {sound="SpySociety/Agents/<voice>/hurt_small",soundFrames=39, source=targetRig},
		}
	end	
	self._rig:setPlayMode( KLEIAnim.ONCE )	
	self:waitForAnim("body_pick_up", targetUnit:getFacing(), nil, sounds)

	-- self._rig:transitionUnitState(self._rig._idleState)
end

function dragbody_state:onExit()
	local unit = self._rig:getUnit()
	if unit:getTraits().movingBody and not unit:getTraits().movePath then
		--drop the body!
	end
end

function dragbody_state:onSimEvent( ev, eventType, eventData )
	local unit = self._rig:getUnit()
	if unit:isGhost() then
		if eventType == simdefs.EV_UNIT_START_WALKING then
			self._rig:transitionUnitState( self._rig._walkState, ev )
		end

	else
		unitrig.base_state.onSimEvent( self, ev, eventType, eventData )
	
		if eventType == simdefs.EV_UNIT_START_WALKING then
			self._rig:transitionUnitState( self._rig._walkState, ev )
		elseif eventType == simdefs.EV_UNIT_DROP_BODY then
			self._rig:refreshLocation()
			self._rig:refreshHUD( unit )
			self._rig:transitionUnitState( self._rig._dropBodyState, ev )	
		end
	end
end


--------------------------------------------------------------------
local dropbody_state = class( unitrig.base_state )

function dropbody_state:init( rig )	
	unitrig.base_state.init( self, rig, "dropbody" )		
end

function dropbody_state:onEnter( ev )
	unitrig.base_state.onEnter( self )

	local unit = self._rig:getUnit()
	local targetUnitID = ev.eventData.targetUnit and ev.eventData.targetUnit:getID()
	local targetRig = self._rig._boardRig:getUnitRig(targetUnitID)
	local targetUnit = targetRig:getUnit()




	local sounds = {}
	if self._rig:getUnit():getUnitData().gender == "male" then
		sounds = {
			--{sound="SpySociety/HitResponse/hitby_punch_flesh",soundFrames=5},
			-- {sound="SpySociety/HitResponse/hitby_energy_flesh",soundFrames=5},
			-- {sound="SpySociety/Agents/<voice>/hurt_small",soundFrames=6, source=targetRig},
			-- {sound="SpySociety/Movement/bodyfall_agent_hardwood",soundFrames=22},
   --          {sound="SpySociety/HitResponse/hitby_floor_flesh",soundFrames=23}
        }
	else
		sounds = {
			-- {sound="SpySociety/HitResponse/hitby_grab_flesh",soundFrames=1},
			-- {sound="SpySociety/Agents/<voice>/grabbed_vocals",soundFrames=2, source=targetRig},
	  --       {sound="SpySociety/HitResponse/hitby_floor_flesh",soundFrames=17},
			-- {sound="SpySociety/Movement/bodyfall_agent_hardwood",soundFrames=18},
			-- {sound="SpySociety/HitResponse/hitby_energy_flesh",soundFrames=38},
			-- {sound="SpySociety/Agents/<voice>/hurt_small",soundFrames=39, source=targetRig},
		}
	end			
	self:waitForAnim("body_drop", simquery.getReverseDirection(unit:getFacing() ), nil, sounds)
	local grp_build = targetRig._kanim.grp_build[1]
	self._rig._prop:unbindBuild(KLEIResourceMgr.GetResource(grp_build))
	local targetAnim = getIdleAnim(targetUnit:getSim(), targetUnit)
	targetRig._prop:setVisible(true)
	targetRig:setCurrentAnim(targetAnim)

	self._rig:transitionUnitState(self._rig._idleState)
end
--------------------------------------------------------------------

local bodydrop_state = class( unitrig.base_state )

function bodydrop_state:init( rig )	
	unitrig.base_state.init( self, rig, "bodydrop" )		
end

function bodydrop_state:onEnter( ev )
	unitrig.base_state.onEnter( self )

	local unit = self._rig:getUnit()
	local sounds = {}
	self._rig:setCurrentAnim("body_fall", nil, nil, sounds)
	self._rig._prop:setListener( KLEIAnim.EVENT_ANIM_END,
		function( anim, animname )
			self._rig._prop:setListener( KLEIAnim.EVENT_ANIM_END, nil )
			self._rig:transitionUnitState(self._rig._idleState)
		end )

end

--------------------------------------------------------------------

local lookaround_state = class( unitrig.base_state )

function lookaround_state:init( rig )	
	unitrig.base_state.init( self, rig, "lookaround" )
end

function lookaround_state:onSimEvent( ev, eventType, eventData )
	if eventType == simdefs.EV_UNIT_LOOKAROUND then
		if eventData.part == "left" then
			self:performLeft(ev)
		elseif eventData.part == "post" then
			self:performPost(ev)
		end
		return true
	elseif eventType == simdefs.EV_UNIT_INTERRUPTED then
		self._rig:transitionUnitState( self._rig._idleState )
	end
end

function lookaround_state:refreshLOSCaster(seerID)
	if self.status ~= "left" and self.status ~= "right" and self.status ~= "both" and self.status ~= "post" then
		return false
	end

	local seer = self._rig:getUnit()
	local searchArc = math.pi
	local facingOffset = searchArc/4 - simquery.getLOSArc( seer )/8
	local losArc = simquery.getLOSArc( seer )/2 + searchArc/2
	if self.status == "both" or self.status == "post" then
		losArc = searchArc
	end
	local range = seer:getTraits().LOSrange and self._rig._boardRig:cellToWorldDistance( seer:getTraits().LOSrange )

	local facingRad = seer:getFacingRad()
	if self.status == "right" then
		facingRad = seer:getFacingRad() - facingOffset
	elseif self.status == "left" then
		facingRad = seer:getFacingRad() + facingOffset
	end
	local arcStart = facingRad + losArc/2
	local arcEnd = facingRad - losArc/2
	local arcAnimStart = facingRad
	local arcAnimEnd = facingRad
	if self.status == "both" or self.status == "post" then
		arcAnimStart = facingRad+simquery.getLOSArc( seer )/2
		arcAnimEnd = facingRad-simquery.getLOSArc( seer )/2
	end

	local function lerp( a, b, t )
		return a*(1-t) + t*b
	end

	local arcEndCurve
	if self.status == "right" or self.status == "both" then
		arcEndCurve = MOAIAnimCurve.new ()
		arcEndCurve:reserveKeys ( 2 )
		arcEndCurve:setKey ( 1, 0.0, lerp(arcAnimEnd, arcEnd, 0.00) )
		arcEndCurve:setKey ( 2, 0.2, lerp(arcAnimEnd, arcEnd, 1.00) )
	elseif self.status == "right_post" or self.status == "post" then
		arcEndCurve = MOAIAnimCurve.new ()
		arcEndCurve:reserveKeys ( 2 )
		arcEndCurve:setKey ( 1, 0.0, lerp(arcEnd, arcAnimEnd, 0.00) )
		arcEndCurve:setKey ( 2, 0.2, lerp(arcEnd, arcAnimEnd, 1.00) )
	end
	if arcEndCurve then
		local arcEndCurveTimer = MOAITimer.new ()
		arcEndCurveTimer:setSpan ( 0, arcEndCurve:getLength() )
		arcEndCurveTimer:setMode( MOAITimer.NORMAL )
		arcEndCurve:setAttrLink ( MOAIAnimCurve.ATTR_TIME, arcEndCurveTimer, MOAITimer.ATTR_TIME )
		arcEndCurveTimer:start()
	end

	local arcStartCurve
	if self.status == "left" or self.status == "both" then
		arcStartCurve = MOAIAnimCurve.new ()
		arcStartCurve:reserveKeys ( 2 )
		arcStartCurve:setKey ( 1, 0.0, lerp(arcAnimStart, arcStart, 0.00) )
		arcStartCurve:setKey ( 2, 0.3, lerp(arcAnimStart, arcStart, 1.00) )
	elseif self.status == "left_post" or self.status == "post" then
		arcStartCurve = MOAIAnimCurve.new ()
		arcStartCurve:reserveKeys ( 2 )
		arcStartCurve:setKey ( 1, 0.0, lerp(arcStart, arcAnimStart, 0.00) )
		arcStartCurve:setKey ( 2, 0.3, lerp(arcStart, arcAnimStart, 1.00) )
	end
	if arcStartCurve then
		local arcStartCurveTimer = MOAITimer.new ()
		arcStartCurveTimer:setSpan ( 0, arcStartCurve:getLength() )
		arcStartCurveTimer:setMode( MOAITimer.NORMAL )
		arcStartCurve:setAttrLink ( MOAIAnimCurve.ATTR_TIME, arcStartCurveTimer, MOAITimer.ATTR_TIME )
		arcStartCurveTimer:start()
	end

	if arcStartCurve and arcEndCurve then
		self._rig._boardRig._game.shadow_map:insertLOS( KLEIShadowMap.ELOS_DIRECT, seerID, arcEndCurve, arcStartCurve, range, self._rig._prop)
	elseif arcStartCurve then
		self._rig._boardRig._game.shadow_map:insertLOS( KLEIShadowMap.ELOS_DIRECT, seerID, arcEnd, arcStartCurve, range, self._rig._prop)
	elseif arcEndCurve then
		self._rig._boardRig._game.shadow_map:insertLOS( KLEIShadowMap.ELOS_DIRECT, seerID, arcEndCurve, arcStart, range, self._rig._prop)
	end
	return true
end

function lookaround_state:onEnter( ev )
	unitrig.base_state.onEnter( self )
	--self:performBoth(ev)	--go straight into both, until anim updates allow righ then left
	self:performRight(ev)	--requires anim updates
end

function lookaround_state:performLeft(ev)
	rig_util.wait(16)
	self.status = "left"
	local isSeen = self._rig._boardRig:canPlayerSeeUnit( ev.eventData.unit )
	if self._wasSeen or isSeen then
		self:refreshLOSCaster( self._rig._unitID )
	end
	rig_util.wait(16)
	self.status = "left_post"
end

function lookaround_state:performRight(ev)
	self.status = "right"
	local isSeen = self._rig._boardRig:canPlayerSeeUnit( ev.eventData.unit )
	if self._wasSeen or isSeen then
		self:refreshLOSCaster( self._rig._unitID )
	end
	self:waitForAnim("peek_fwrd")	--3 frames
	self._rig:setCurrentAnim( "peek_pst_fwrd" )
	rig_util.wait(13)
	self.status = "right_post"
end

function lookaround_state:performBoth(ev)
	self.status = "both"
	local isSeen = self._rig._boardRig:canPlayerSeeUnit( ev.eventData.unit )
	if self._wasSeen or isSeen then
		self:refreshLOSCaster( self._rig._unitID )
	end
	self:waitForAnim("peek_fwrd")
	self._rig:setCurrentAnim( "peek_pst_fwrd" )
	rig_util.wait(50)
	self.status = "post"
end

function lookaround_state:performPost(ev)
	local isSeen = self._rig._boardRig:canPlayerSeeUnit( ev.eventData.unit )
	if (self._wasSeen or isSeen) and self._rig._prop:getFrame() < self._rig._prop:getFrameCount()-1 then
		local animDone = false
		self._rig._prop:setListener( KLEIAnim.EVENT_ANIM_END,
			function( anim, animname )
				animDone = true
			end )
		while not animDone do
			coroutine.yield()
		end
		self._rig._prop:setListener( KLEIAnim.EVENT_ANIM_END, nil )
	end


	self._rig:transitionUnitState( self._rig._idleState )
end
--------------------------------------------------------------------

local shrug_state = class( unitrig.base_state )

function shrug_state:init( rig )	
	unitrig.base_state.init( self, rig, "shrug" )		
end

function shrug_state:onEnter( ev )
	unitrig.base_state.onEnter( self )
	self:waitForAnim( "shrug" )
	self._rig:transitionUnitState( self._rig._idleState )
end

--------------------------------------------------------------------
-- agentrig

local agentrig = class( unitrig.rig )

function agentrig:init( boardRig, unit )
	unitrig.rig.init( self, boardRig, unit )

	if unit:getPlayerOwner() and not unit:getPlayerOwner():isNPC() then
	--	self._coverRig = coverrig.rig( boardRig, self._prop )
	end

	self._HUDteamCircle = self:createHUDProp("kanim_hud_agent_hud", "CharacterRing", "0", false, self._prop )
	
	self._HUDzzz = self:createHUDProp("kanim_sleep_zees_fx", "character", "sleep", boardRig:getLayer("ceiling"), self._prop )
	self._HUDzzz:setVisible(false)

	self._HUD_shield = self:createHUDProp("kanim_shield_fx", "shield", "idle", true, self._prop )
	self._HUD_shield:setVisible(false)

	if unit:getPlayerOwner() and unit:getPlayerOwner():isNPC() then
		self._HUDheart =   self:createHUDProp("kanim_hud_fx", "health_monitor", "alive", boardRig:getLayer("ceiling"), self._prop )
		self._HUDheart:setSymbolModulate("line",1,0,0,1)
		self._HUDheart:setSymbolModulate("line_blip",1,0,0,1)
		self._HUDheart:setSymbolModulate("line_flat",1,0,0,1)
		self._HUDheart:setSymbolModulate("monitor",1,0,0,1)
		self._HUDheart:setSymbolModulate("monitor_bg",1,0,0,1)
		self._HUDheart:setVisible(false)
	end

	self._idleState = idle_state( self )
	self._walkState = walking_state( self )
	self._shootState = shoot_state( self )
	self._reloadState = reload_state( self )
	self._hitState = hit_state( self )
	self._usedoorState = usedoor_state( self )
	self._healState = heal_state( self )
	self._pickupState = pickup_state( self )
	self._meleeState = melee_state( self )
	self._lookaroundState = lookaround_state( self )
	self._shrugState = shrug_state( self )
	self._dragBodyState = dragbody_state( self )
	self._dropBodyState = dropbody_state( self )
	self._bodyDropState = bodydrop_state( self )

	local prop = self._prop

	if self:getUnit():getTraits().hits == "blood" then
		prop:setSymbolVisibility( "blood", true )
		prop:setSymbolVisibility( "blood_crit", "sparks2", "electricity", "hit", "blood_pool", "oil_pool", false )	
	elseif self:getUnit():getTraits().hits == "spark" then
		prop:setSymbolVisibility( "blood", "blood_crit", "sparks2", "blood_pool", "oil_pool", false )
		prop:setSymbolVisibility( "electricity", "hit", true )
	end

end

function agentrig:destroy()

	if self._bWireframe then		
		self._boardRig._game:removeWireframeProp( self._prop )
	end
	
	self._boardRig:getLayer("ceiling"):removeProp( self._HUDzzz )

	self._prop:removeProp(self._HUDteamCircle )
	self._prop:removeProp( self._HUD_shield, true)	

	if self._flagUI then
		self._flagUI:destroy()
		self._flagUI = nil
	end
	if self._coverRig then
		self._coverRig:destroy()	
		self._coverRig = nil
	end

	if self.interestProp then
		self._boardRig:getLayer("ceiling"):removeProp( self.interestProp )
	end

	if self._HUDheart then
		self._boardRig:getLayer("ceiling"):removeProp( self._HUDheart )
	end

	unitrig.rig.destroy( self )
end



function agentrig:onSimEvent( ev, eventType, eventData )
	unitrig.rig.onSimEvent( self, ev, eventType, eventData )
	
	if eventType == simdefs.EV_UNIT_INTERRUPTED then

		self:setPlayMode( KLEIAnim.STOP )

		local fxmgr = self._boardRig._game.fxmgr
		local x0, y0 = self:getUnit():getLocation()
		if self:getUnit():getPlayerOwner() == self._boardRig:getLocalPlayer() and self._boardRig:canPlayerSee( x0, y0 ) then
			x0, y0 = self._boardRig:cellToWorld( x0, y0 )
			if eventData.unitSeen and  eventData.unitSeen:getPlayerOwner() and eventData.unitSeen:getPlayerOwner():isNPC() then
				fxmgr:addFloatLabel( x0, y0, "Enemy Sighted!", 2 )			
			else
				--don't do this... it looks ugly and it almost never is good
				--fxmgr:addFloatLabel( x0, y0, "Interrupted!", 2 )			
			end
		end

	elseif eventType == simdefs.EV_UNIT_ADD_INTEREST then
		self:drawInterest(eventData.interest, self:getUnit():getTraits().alerted)
	elseif eventType == simdefs.EV_UNIT_UPDATE_INTEREST then
		if eventData.unit and not eventData.unit:isKO() and eventData.unit:getBrain():getInterest() and not eventData.unit:getBrain():getInterest().investigated  then
			self:drawInterest(eventData.unit:getBrain():getInterest(), self:getUnit():getTraits().alerted)
		else		
			self:eraseInterest()
		end
	elseif eventType == simdefs.EV_UNIT_DEL_INTEREST then
		self:eraseInterest()
	elseif eventType == simdefs.EV_UNIT_RESET_ANIM_PLAYBACK then		
		self:setPlayMode( KLEIAnim.LOOP )
	
	elseif eventType == simdefs.EV_UNIT_WIRELESS_SCAN then
	
		self:playSound("SpySociety/Actions/Engineer/wireless_emitter")
		
		if eventData.hijack then
			self:addAnimFx( "gui/hud_fx", "wireless_console_takeover", "idle" )
			self._boardRig:getUnitRig( eventData.targetUnitID ):addAnimFx( "gui/hud_fx", "wireless_console_takeover", "idle" )
		else	
			self:addAnimFx( "gui/hud_fx", "wireless", "idle" )
		end

	elseif eventType == simdefs.EV_UNIT_PSIFX then
		local x0, y0 = eventData.unit:getLocation()
		if  self._boardRig:canPlayerSee(x0, y0 ) then
			self._boardRig._game:cameraPanToCell( x0, y0 )
			if eventData.fx then
				self:addAnimFx( "fx/" ..eventData.fx, "effect", eventData.anim or "idle" )
			end
			if eventData.txt then
				self._boardRig:showFloatText( x0, y0, eventData.txt )
			end
			self._boardRig:wait( 60 )
		end

	elseif eventType == simdefs.EV_UNIT_HIT_SHIELD then	
		
		self:playSound( "SpySociety/HitResponse/hitby_ballistic_shield")
		self:addAnimFx( "fx/shield_fx", "shield", "break", true )

		self:refreshHUD( eventData.unit )


	elseif eventType == simdefs.EV_UNIT_APPEARED then		
		local sim =  self._boardRig:getSim()
		local unit = sim:getUnit(ev.eventData.unitID)
		local x0,y0 = unit:getLocation()
		self._boardRig:cameraFit( self._boardRig:cellToWorld( x0, y0 ) )
		
		local fx = self:addAnimFx( "gui/hud_agent_hud", "enemy_sighting", "front" )
		-- UGLY: just set these colours in the anim directly, so we can delete this
		fx._prop:setSymbolModulate("wall",1, 0, 0, 1 )
		fx._prop:setSymbolModulate("outline_side",1, 0, 0, 1 )
	end
end

function agentrig:refreshLOSCaster( seerID )
	if self._state and self._state.refreshLOSCaster then
		return self._state:refreshLOSCaster( seerID )
	end
	return false
end

function agentrig:drawInterest(interest, alerted)
	local x0,y0 =  self._boardRig:cellToWorld(interest.x, interest.y) 
	local sim = self._boardRig:getSim()
	if sim:drawInterestPoints() or self:getUnit():getTraits().patrolObserved or self:getUnit():getTraits().drawInterestPoint then 
		if not self.interestProp then
			self._boardRig._game.fxmgr:addAnimFx( { kanim="gui/guard_interest_fx", symbol="effect", anim="in", x=x0, y=y0 } )
			self.interestProp = self:createHUDProp("kanim_hud_interest_point_fx", "interest_point", "idle", self._boardRig:getLayer("ceiling"), nil, x0, y0  )
			self.interestProp:setSymbolModulate("interest_border",1, 0, 0, 1 )
			self.interestProp:setSymbolModulate("down_line",1, 0, 0, 1 )
			self.interestProp:setSymbolModulate("down_line_moving",1, 0, 0, 1 )
			self.interestProp:setSymbolModulate("interest_line_moving",1, 0, 0, 1 )
		end

		if interest.alerted or alerted then
			self.interestProp:setSymbolVisibility("thought_alert", true)
			self.interestProp:setSymbolVisibility("thought_investigate", false)
			self.interestProp:setSymbolVisibility("thought_bribe", false)
		else
			self.interestProp:setSymbolVisibility("thought_alert", false)
			self.interestProp:setSymbolVisibility("thought_investigate", true)
			self.interestProp:setSymbolVisibility("thought_bribe", false)
		end

	 	self.interestProp:setVisible( true )
		self.interestProp:setLoc( x0, y0 )	
	end 
end

function agentrig:eraseInterest()
	if self.interestProp then
		self._boardRig:getLayer("ceiling"):removeProp( self.interestProp )
		self.interestProp = nil

		if self:getUnit():getTraits().drawInterestPoint then 
			self:getUnit():getTraits().drawInterestPoint = nil 
		end
	end
end

function agentrig:hideFlags( isHidden )
	self._hideFlags = isHidden
	self:refreshHUD( self:getUnit() )
end

function agentrig:previewMovement( moveCost )
	if self._flagUI then
		self._flagUI:previewMovement( moveCost )
	end
end

function agentrig:generateTooltip( debugMode )
	local tooltip = unitrig.rig.generateTooltip( self, debugMode ) 
	return tooltip	
end

function agentrig:refreshAnim( unit )

	if self._draggingBody ~= unit:getTraits().movingBody then
		if self._draggingBody then
			local bodyRig = self._boardRig:getUnitRig(self._draggingBody:getID() )
			if bodyRig then
				local grp_build = bodyRig._kanim.grp_build[1]
				self._prop:unbindBuild(KLEIResourceMgr.GetResource(grp_build))
			end
		end

		if unit:getTraits().movingBody then
			local bodyRig = self._boardRig:getUnitRig(unit:getTraits().movingBody:getID() )
			if bodyRig then
				local grp_build = bodyRig._kanim.grp_build[1]
				self._prop:bindBuild(KLEIResourceMgr.GetResource(grp_build))
			end
		end

		self._draggingBody = unit:getTraits().movingBody
	end

	local weapon = simquery.getEquippedGun(unit)

	if weapon and weapon:getUnitData() ~= self._weaponUnitData then

		local rawUnit = unit:getSim():getUnit(unit:getID() )
		local unloadedAnims = {}
		if self._weaponUnitData then
			unapplyKanim( animmgr.lookupAnimDef( self._weaponUnitData.weapon_anim ), self._prop )
			util.tmerge( unloadedAnims, self._kanim[ self._weaponUnitData.agent_anim ] )
		elseif rawUnit and rawUnit:getPlayerOwner():isNPC() then
			util.tmerge( unloadedAnims, self._kanim[ "anims_1h" ] )
		end

		for _,anim in pairs(unloadedAnims) do
			assert(KLEIResourceMgr.GetResource(anim), anim)
			self._prop:unbindAnim( KLEIResourceMgr.GetResource(anim) )
		end

		self._weaponUnitData = weapon:getUnitData()

		local loadedAnims = {}
		if self._weaponUnitData then
			applyKanim( animmgr.lookupAnimDef( self._weaponUnitData.weapon_anim ), self._prop )
			util.tmerge( loadedAnims, self._kanim[ self._weaponUnitData.agent_anim ] )		
		end

		for _,anim in pairs(loadedAnims) do
			assert(KLEIResourceMgr.GetResource(anim), anim)
			self._prop:bindAnim( KLEIResourceMgr.GetResource(anim) )
		end

	elseif not weapon then
		local rawUnit = unit:getSim():getUnit(unit:getID() )
		local unloadedAnims = {}
		if self._weaponUnitData then
			unapplyKanim( animmgr.lookupAnimDef( self._weaponUnitData.weapon_anim ), self._prop )
			util.tmerge( unloadedAnims, self._kanim[ self._weaponUnitData.agent_anim ] )

		elseif rawUnit and rawUnit:getPlayerOwner():isNPC() then
			util.tmerge( unloadedAnims, self._kanim[ "anims" ] )
		end

		for _,anim in pairs(unloadedAnims) do
			assert(KLEIResourceMgr.GetResource(anim), anim)
			self._prop:unbindAnim( KLEIResourceMgr.GetResource(anim) )
		end

		self._weaponUnitData = nil

		local loadedAnims = {}
		util.tmerge( loadedAnims, self._kanim[ "anims" ] )

		for _,anim in pairs(loadedAnims) do
			assert(KLEIResourceMgr.GetResource(anim), anim)
			self._prop:bindAnim( KLEIResourceMgr.GetResource(anim) )
		end

	end
end

function agentrig:refreshRenderFilter()
	if self._renderFilterOverride then
		self._prop:setRenderFilter( self._renderFilterOverride )
	else
		local unit = self._boardRig:getLastKnownUnit( self._unitID )
		if unit then
			local gfxOptions = self._boardRig._game:getGfxOptions()
			if gfxOptions.bMainframeMode then
				self._prop:setRenderFilter( cdefs.RENDER_FILTERS["mainframe_agent"] )
			elseif unit:isGhost() then
				self._prop:setPlayMode( KLEIAnim.STOP )
				assert(self._prop:getFrameCount() ~= nil or error( string.format("Missing Animation: %s, %s:%s", unit:getUnitData().kanim, self._prop:getCurrentAnim(), self._prop:getAnimFacing() ) )) --throw an error if the animation is missing
				self._prop:setFrame( self._prop:getFrameCount() - 1 ) -- Always want to be ghosted at the last frame (aim, death, etc.)
				self._prop:setRenderFilter( cdefs.RENDER_FILTERS["ghost"] )
			else
				self._prop:setPlayMode( self._playMode )

				if unit:getTraits().invisible or unit:getTraits().cloak_activated then
					self._prop:setRenderFilter( cdefs.RENDER_FILTERS["cloak"] )
				else
					self._prop:setRenderFilter( cdefs.RENDER_FILTERS["shadowlight"] )
				end
				
			end
		end
	end
end

function agentrig:selectedToggle( toggle )
	if self._flagUI then
		if toggle == true then
			self._flagUI:moveToFront()
			self._flagUI:refreshFlag( nil, true )
		else
			self._flagUI:refreshFlag( nil, false )
		end
	end
end

function agentrig:onUnitAlerted( viz, eventData )
	local x,y = self:getLocation()
	if self._boardRig:canPlayerSee(x, y ) then		
		self._boardRig:cameraFit( self._boardRig:cellToWorld( x, y )  )
	end
end

function agentrig:refreshHUD( unit )

	local unitOwner = unit:getPlayerOwner()

	self._HUDzzz:setVisible(false)
	if unit:isKO() and not unit:isDead() then
		self._HUDzzz:setVisible(true)
	end

	self._HUD_shield:setVisible( (unit:getTraits().shields or 0) > 0 and not unit:isKO() )

	local gfxOptions = self._boardRig._game:getGfxOptions()
	if gfxOptions.bMainframeMode then
		if self._HUDheart then
			if unit:getTraits().heartMonitor == "enabled" then
				self._HUDheart:setVisible(false)  -- Do we even need these anymore?
			else
				self._HUDheart:setVisible(false)
			end
		end

	else
		if self._HUDheart then
			self._HUDheart:setVisible(false)
		end

		if self._coverRig then
			self._coverRig:refresh( unit:getLocation() )			
		end
		

		if unitOwner and unitOwner:isNPC() then
			local rawUnit = self._boardRig:getSim():getUnit(unit:getID())

			if rawUnit and not rawUnit:isKO() and rawUnit:getBrain() and rawUnit:getBrain():getInterest() and not rawUnit:getBrain():getInterest().investigated  then
				self:drawInterest(rawUnit:getBrain():getInterest(), rawUnit:getTraits().alerted)	
			else		
				self:eraseInterest()
			end
		end
	end

	if self._flagUI then
		self._flagUI:refreshFlag( unit )
	end	
end


function agentrig:refreshProp( refreshLoc )
	unitrig.rig.refreshProp( self, refreshLoc )

	self:refreshAnim( self:getUnit() )
end

function agentrig:refreshLocation( facing )
	unitrig.rig.refreshLocation( self, facing )

	
	local x, y = self:getLocation()
	local occluded = self._boardRig:queryCellOcclusion( self:getUnit(), x, y )
	if occluded and not self._bWireframe then
		self._bWireframe = true
		self._boardRig._game:insertWireframeProp( self._prop )
	elseif not occluded and self._bWireframe then
		self._bWireframe = false
		self._boardRig._game:removeWireframeProp( self._prop )
	end
end


function agentrig:refresh()
	unitrig.rig.refresh( self )


	-- Determine what state the unit should be in.
	self:transitionUnitState( nil )
	self:transitionUnitState( self._idleState )

	local unit = self:getUnit()
	local hud = self._boardRig._game.hud
	if hud ~= nil and hud:canShowElement( "agentFlags" ) and not unit:isGhost() and unit:getPlayerOwner() ~= nil then
		if self._flagUI == nil then
			self._flagUI = flagui( self, unit )
		end

	elseif self._flagUI then
		self._flagUI:destroy()
		self._flagUI = nil
	end

	if self._flagUI then
		self._flagUI:refreshFlag( unit )
	end
end

function agentrig:refreshObstructionVisibility()
end

local OBSTRUCT_PATTERN =
{
	-- dx, dy, obstruction value
	{1, 0, 50},
	{0, 1, 50},
	{1, 1, 75},
	{2, 1, 25},
	{2, 2, 50},
	{1, 2, 25},
}

function agentrig:setLocation( x, y )
	
	if x and y and ( self._x ~= x or self._y ~= y )then
		self._x, self._y = x, y
		--self:setObstructionVisibility( x, y, OBSTRUCT_PATTERN )
	end
end

return
{
	rig = agentrig,
}

