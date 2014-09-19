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
local binops = include( "modules/binary_ops" )
local array = include( "modules/array" )
local rig_util = include( "gameplay/rig_util" )
include("class")

---------------------------------------------------------------
-- Local

local simdefs = nil -- Lazy initialized after the sim is mounted.
local simquery = nil -- Lazy initialized after the sim is mounted.

---------------------------------------------------------------


-------------------------------------------------------------
-- Base unit state.  This should be pretty agnostic about the
-- unit, supporting common functionality features common to
-- state implementations for any unit type.

local base_state = class()

function base_state:init( rig, name )
	assert(rig)
	self._name = name
	self._rig = rig
	self._targetX, self.targetY	= nil,nil
end

function base_state:onEnter()
end


function base_state:waitForAnim( animname,facing,exitFrame,sounds )
	assert( animname )

	local lastFrame = 0
	if not facing then
		facing = self._rig:getFacing()
	end

	if self._rig._prop:shouldDraw() then

		self._rig:setPlayMode( KLEIAnim.ONCE )
		self._rig:setCurrentAnim( animname, facing)

		assert(self._rig._prop:getFrameCount() ~= nil or error( string.format("Missing Animation: %s, %s:%s", self._rig:getUnit():getUnitData().kanim, animname, self._rig._prop:getAnimFacing() ) )) --throw an error if the animation is missing
		if self._rig._prop:getFrameCount() and self._rig._prop:getFrame() + 1 < self._rig._prop:getFrameCount() then
			local animDone = false
			self._rig._prop:setListener( KLEIAnim.EVENT_ANIM_END,
				function( anim, animname )
					animDone = true
				end )

			while not animDone do
				if exitFrame  and  self._rig._prop:getFrame() >= exitFrame then
					animDone = true
				end

				if sounds then
					for i,sound in pairs(sounds)do
						if sound.sound and sound.soundFrames then
							local frame = self._rig._prop:getFrame() % self._rig._prop:getFrameCount()
							if sound.soundFrames == frame and lastFrame ~= frame then
								local x0, y0 = self._rig:getUnit():getLocation()
								local sourceRig = sound.source or self._rig
								sourceRig:playSound( sound.sound, nil, x0, y0 )
								lastFrame = frame
							end					
						end	
					end
				end

				coroutine.yield()
			end

			self._rig._prop:setListener( KLEIAnim.EVENT_ANIM_END )
		end
	end
end

function base_state:wait( action, soundlist )
	local currentFrame = 0
	while action and not action:isDone() do
		local x0, y0 = self._rig:getUnit():getLocation()
		currentFrame = currentFrame + 1
		if soundlist then
			for _, info in ipairs(soundlist) do
				local frames = info.frames			
				if array.find( frames, currentFrame) then
					local sounds = info.sounds
					for _,sound in ipairs(sounds) do
						--MOAIFmodDesigner.playSound(sound,nil,nil,{x0,y0,0},nil )
						self._rig:playSound( sound, nil, soundlist.x or x0, soundlist.y or y0 )
					end
				end
			end
		end
		coroutine.yield()
	end
end

function base_state:waitDuration( duration )
	local timer = MOAITimer.new ()
	timer:setSpan( 0, duration )
	timer:start()
	self:wait( timer )
end

function base_state:onExit()
end

function base_state:onSimEvent( ev, eventType, eventData )
	if eventType == simdefs.EV_UNIT_SHOW_LABLE then		
		local fxmgr = self._rig._boardRig._game.fxmgr
		local x0, y0 = ev.eventData.unit:getLocation()
		x0, y0 = self._rig._boardRig:cellToWorld( x0, y0 )
		
		fxmgr:addFloatLabel( x0, y0, ev.eventData.txt, 2 )			

		if ev.eventData.sound then
			self:playSound(ev.eventData.sound)
		end	
	end
end

function base_state:generateTooltip()
	local str = string.format("State: %s\n", self._name )

	for k,v in pairs(self) do
		if type(v) ~= "function" then
			str = str .. tostring(k) .. " = " .. tostring(v) .. "\n"
		end
	end

	return str
end

------------------------------------------------------

local unitrig = class()

function unitrig:init( boardRig, unit )
	--log:write( "UNIT RIG -- %s", unitData.name )
	local unitID = unit:getID()
	local unitData = unit:getUnitData()

	simdefs = boardRig:getSim():getDefs()
	simquery = boardRig:getSim():getQuery()

	local prop, animdef = animmgr.createPropFromAnimDef( unitData.kanim )
	prop:setShadowMap( boardRig._game.shadow_map )

	prop:setDebugName( unitData.name .. "_" .. tostring(unitID) )
	boardRig:getLayer():insertProp( prop )

	if animdef.filterSymbols then
		for i,set in ipairs(animdef.filterSymbols) do
			prop:setRenderFilter( set.symbol, cdefs.RENDER_FILTERS[set.filter] )	
		end
	end

	self._spotSound = nil	
	self._boardRig = boardRig
	self._prop = prop
	self._unitID = unitID
	self._kanim = animdef
	self._x = nil
	self._y = nil
	self._facing = nil
	self._visible = nil
	self._state = nil
	self._playMode = KLEIAnim.LOOP	

	self._prop:setSymbolVisibility( "outline", "tile_outline", false )	

	if unit:getTraits().mainframe_item == true then		
		self._HUDmainframeBorder = self:createHUDProp("kanim_hud_mainframe_hud", "tileBorder", "0", boardRig:getLayer("floor"), self._prop )		
		self._HUDmainframeBorder:setVisible(false)
	end

	
	if  unit:getTraits().actionhilite == true then
		self._actionhilite = self:createHUDProp("kanim_console_hilite", "character", "idle", boardRig:getLayer("ceiling"), self._prop )				
		local dir = unit:getFacing()
		local orientation = self._boardRig._game:getCamera():getOrientation()
		self._actionhilite:setCurrentFacingMask( 2^((dir - orientation*2) % simdefs.DIR_MAX) )
	end
end

function unitrig:orientationToFacingMask( orientation, facing )
	facing = facing or self:getFacing()
	local orientation = (facing - orientation*2) % 8
	return 2^orientation
end

function unitrig:getProp()
	return self._prop
end

function unitrig:getUnit()
	return self._boardRig:getLastKnownUnit( self._unitID )
end

function unitrig:getRawUnit()
	-- Note that this MAY be nil even if the rig exists!  (we could be rigging a ghost)
	return self._boardRig:getSim():getUnit( self._unitID )
end

function unitrig:getLocation()
	return self._x, self._y
end

function unitrig:setLocation( x, y )
	if self._x ~= x or self._y ~= y then
		self._x = x
		self._y = y
	end
end

function unitrig:getFacing()
	return self._facing
end

function unitrig:isVisible()
	return self._visible
end

function unitrig:setPlayMode( playMode )
	self._playMode = playMode
	self._prop:setPlayMode( playMode )
end

function unitrig:playSound( soundPath, alias )
	local unit = self:getUnit()
	local x1,y1 = unit:getLocation()
	if unit:getTraits().voice then
		soundPath = string.gsub(soundPath, "<voice>", unit:getTraits().voice)
	end
	self._boardRig:getSounds():playSound( soundPath, alias, x1, y1 )
end

function unitrig:addAnimFx( kanim, symbol, anim, above, params )
	local fxmgr = self._boardRig._game.fxmgr
	local x, y = self._boardRig:cellToWorld( self:getLocation() )
	local args = util.extend(
	{
		x = x,
		y = y,
		kanim = kanim,
		symbol = symbol,
		anim = anim,
		above = above,
	})( params )

	if above == true then
		args.aboveProp = self._prop
	elseif above == false then
		args.belowProp = self._prop
	else
		-- spawn on the fx layer (as of right now, this is the "ceiling" layer)
	end

	return fxmgr:addAnimFx( args )
end

function unitrig:directionToAnimMask( dir, orientation )

	dir = (dir - orientation*2) % simdefs.DIR_MAX
	local flip, facing_mask = false, 2^dir

	local shouldFlip = self._kanim.shouldFlip

	if self._kanim.shouldFlipOverrides then
		for i,set in ipairs(self._kanim.shouldFlipOverrides) do
			if set.anim == self._prop:getCurrentAnim() then
				shouldFlip = set.shouldFlip
				break
			end
		end
	end

	if shouldFlip then
		if dir == simdefs.DIR_N then
			facing_mask = KLEIAnim.FACING_E
			flip = true
		elseif dir == simdefs.DIR_NW then
			facing_mask = KLEIAnim.FACING_SE
			flip = true
		elseif dir == simdefs.DIR_W then
			facing_mask = KLEIAnim.FACING_S
			flip = true
		end
	end

	return flip, facing_mask
end


function unitrig:generateTooltip( debugMode )
	local unit = self:getUnit()
	local tooltip = string.format( "<debug>%s [%d]</>\n", util.toupper(unit:getName()), self._unitID )
	if debugMode == cdefs.DBG_RIGS then
		if self._state then
			tooltip = tooltip .. self._state:generateTooltip()
		end
	end

	return tooltip
end

function unitrig:destroy()
	self:transitionUnitState( nil )
	self._boardRig:getLayer():removeProp( self._prop )
	self._boardRig:refreshLOSCaster( self._unitID )

	if self._spotSound then
		self._boardRig:getSounds():stopSound( self._spotSound )
		self._spotSound = nil
	end

	if self._HUDmainframeBorder then
		self._boardRig:getLayer("floor"):removeProp( self._HUDmainframeBorder  )			
	end

	if self._actionhilite then
		self._boardRig:getLayer("ceiling"):removeProp( self._actionhilite  )			
	end
			
end

function unitrig:refreshSpotSound(remove)
	local unit = self:getUnit()
	
	if self._spotSound then
		if not unit or remove then
			self._boardRig:getSounds():stopSound( self._spotSound )
			self._spotSound = nil
		else
			self._boardRig:getSounds():updateSound( self._spotSound, unit:getLocation() )
		end

	elseif unit and unit:getSounds() and unit:getSounds().spot then
		self._spotSound = "unitSound-" .. unit:getID()
		assert( self._boardRig:getSounds() )
		self._boardRig:getSounds():playSound( unit:getSounds().spot, self._spotSound, unit:getLocation() )
	end
end

function unitrig:getIdleAnim()
	local anim = "idle"

	return anim
end


function unitrig:onSimEvent( ev, eventType, eventData )
	-- Handle sim events if the rig state does not.
	if self._state == nil or not self._state:onSimEvent( ev, eventType, eventData ) then
		if eventType == simdefs.EV_UNIT_WARPED then
			local unit = self:getUnit()
			if unit:getTraits().warp_in_anim then
				if unit:getLocation() then
					self._state:waitForAnim(unit:getTraits().warp_in_anim)
					self:setCurrentAnim(self:getIdleAnim()) 
				else 				
					self._state:waitForAnim(unit:getTraits().warp_out_anim)
				end
			end
			self:refreshLocation()
			self:refreshProp()

		elseif eventType == simdefs.EV_UNIT_REFRESH then

			if eventData.reveal then
				self:addAnimFx( "gui/hud_fx", "aquire_console", "front", true )
				MOAIFmodDesigner.playSound("SpySociety/Actions/Engineer/wireless_emitter_reveal")			
			end

			if eventData.fx and eventData.fx == "emp" then
				self:addAnimFx( "fx/emp_effect", "character", "idle", true )
			end

			self:refresh()

        elseif eventType == simdefs.EV_UNIT_HIT then
            if eventData.unit:getTraits().hit_metal then
                self:addAnimFx( "fx/hit_fx", "character", "idle" )
            end

		elseif eventType == simdefs.EV_UNIT_UNGHOSTED then
			self:refresh()

		elseif eventType == simdefs.EV_UNIT_CAPTURE then
			self:refresh()
			MOAIFmodDesigner.playSound("SpySociety/HUD/mainframe/node_capture")		
			self:addAnimFx( "gui/hud_fx", "takeover_console", "front", true )

			local unit = self:getUnit()
			if unit:getTraits().spotSoundPowerDown then
				
				self:refreshSpotSound(true)				
				unit:getSounds().spot = nil			
			end

		elseif eventType == simdefs.EV_UNIT_MAINFRAME_UPDATE then

			if eventData.reveal then
				local x1,y1 = self:getLocation()
				self:playSound("SpySociety/Actions/mainframe_objectsreveled",x1,y1)		
								
				self:addAnimFx( "gui/hud_fx", "aquire_console", "front", true )
			end
	
			self:refresh()	
		elseif eventType == simdefs.EV_UNIT_PLAY_ANIM then
			if eventData.sound then
				local x1,y1 = self:getLocation()
				self:playSound(eventData.sound,x1,y1)		
			end
			
			self._state:waitForAnim(eventData.anim)
			
		end
	end
end

function unitrig:transitionUnitState( state, ... )

	if state ~= self._state then
		if self._state then
			self._state:onExit()
		end

		self._state = state

		if self._state then
			self._state:onEnter( ... )
		end

	end
end

function unitrig:setCurrentAnim( animName, facing )
	local unit = self:getUnit()


	if not facing then
		facing = unit:getFacing()
	end

	if not facing then
		return
	end

	-- Remap the anim if a mapping exists.
	if self._kanim.animMap then
		animName = self._kanim.animMap[ animName ] or animName
		if #animName == 0 then
			return -- (anim not available)
		end
	end

   	local gfxOptions = self._boardRig._game:getGfxOptions()
	local simCore = self._boardRig:getSim()
	local orientation = self._boardRig._game:getCamera():getOrientation()
	local flip, facing_mask = self:directionToAnimMask(facing, orientation)

	self._prop:setCurrentFacingMask( facing_mask )

	if gfxOptions.bMainframeMode and unit:getTraits().mainframe_icon == true then
		animName = animName .. "_icon"
	end		

	self._prop:setCurrentAnim( animName )

	local scale = self._kanim.scale
	if flip then
		self._prop:setScl( -scale, scale, scale )
	else
		self._prop:setScl( scale, scale, scale )
	end
end

function unitrig:startTooltip()
	self._prop:setSymbolVisibility( "outline", "tile_outline", true )
end

function unitrig:stopTooltip()
	self._prop:setSymbolVisibility( "outline", "tile_outline", false )
end

function unitrig:refresh()
	local unit = self:getUnit()
	self:refreshLocation()
	self:refreshProp()
	self:refreshHUD(unit)
end

function unitrig:refreshObstructionVisibility()
	local x, y = self:getLocation()
	if x and y then
		local po = 0
		local cell = self._boardRig:getClientCellXY( x, y )
		for obstruction,value in pairs( cell._obstruction_values ) do
			if obstruction:isVisible() then
				po = (value.p > po) and value.p or po
			end
		end
		self._prop:getShaderUniforms():setUniformFloat( "Opacity", 1 - po / 100 )
	end
end

function unitrig:resetObstructionVisibility()
	local boardRig = self._boardRig
	local decorRig = boardRig._decorig
	local sim = boardRig:getSim()	
	for _,cellrig in pairs(self._obstructingCells or {}) do
		local obstruction_value = cellrig._obstruction_values[ self ]
		if obstruction_value then
			cellrig._obstruction_values[ self ] = nil

			for _,rig in pairs( cellrig._dependentRigs ) do
				rig:refresh()
			end
			decorRig:refreshCell( obstruction_value.x, obstruction_value.y )
			local simcell = sim:getCell( obstruction_value.x, obstruction_value.y )
			if simcell then
				for _,unit in pairs(simcell.units) do
					if unit:getID() ~= self._unitID then
						local unit_rig = boardRig:getUnitRig( unit:getID() )
						if unit_rig then
							unit_rig:refresh()
						end
					end
				end
			end
		end
	end
	self._obstructingCells = {}
end

function unitrig:setObstructionVisibility( x, y, obstructingPattern )
	local boardRig = self._boardRig
	local decorRig = boardRig._decorig
	local sim = boardRig:getSim()
	self:resetObstructionVisibility()
	if x and y then
		local dx,dy = boardRig._game:getCamera():orientVector(1,1)
		for _,obstruction_info in pairs( obstructingPattern ) do
			local x, y, p = x + obstruction_info[1] * dx, y + obstruction_info[2] * dy, obstruction_info[3]
			local cellrig = boardRig:getClientCellXY( x, y )
			if cellrig then
				cellrig._obstruction_values[ self ] = {x=x,y=y,p=p}
				table.insert( self._obstructingCells, cellrig )

				for _,rig in pairs( cellrig._dependentRigs ) do
					rig:refresh()
				end
				decorRig:refreshCell( x, y )
				local simcell = sim:getCell( x, y )
				if simcell then
					for _,unit in pairs(simcell.units) do
						if unit:getID() ~= self._unitID then
							local unit_rig = boardRig:getUnitRig( unit:getID() )
							if unit_rig then
								unit_rig:refresh()
							end
						end
					end
				end
			end
		end
	end
end

function unitrig:refreshProp( refreshLoc )

	local x, y = self:getLocation()
	if x and y then
		if not refreshLoc then
			-- Set the actual prop to our current location!
			self._prop:setLoc( self._boardRig:cellToWorld( x, y ) )
		end

		-- Set the correct facing on the anim prop!
		local orientation = self._boardRig._game:getCamera():getOrientation()

		local flip, facing_mask = self:directionToAnimMask(self:getFacing(), orientation)

		self._prop:setCurrentFacingMask( facing_mask )

		local scale = self._kanim.scale
		if flip then
			self._prop:setScl( -scale, scale, scale )
		else
			self._prop:setScl( scale, scale, scale )
		end

		--self:refreshObstructionVisibility()
		
		animmgr.refreshIsoBounds( self._prop, self._kanim, self:getFacing() )

		self._boardRig:refreshLOSCaster( self._unitID )

		self:refreshRenderFilter()
		self:refreshSpotSound()
	end
end

function unitrig:refreshLocation( facing )

	local unit = self:getUnit()
	local x, y = unit:getLocation()
	facing = facing or unit:getFacing()

	local isVisible = (unit:isGhost() or self._boardRig:canPlayerSeeUnit( unit )) and not simquery.isUnitDragged( self._boardRig:getSim(), unit )
	self._prop:setVisible( isVisible )
	self._visible = isVisible

	if x ~= self._x or y ~= self._y or facing ~= self._facing then
		-- Remove rig from its old locations and add to the new location.
		self:setLocation( x, y )
		self._facing = facing
	end
end


function  unitrig:createHUDProp(kanim, symbolName, anim, layer, unitProp, x, y )
	return self._boardRig:createHUDProp(kanim, symbolName, anim, layer, unitProp, x, y )
end

function unitrig:refreshHUD( unit )	
	local rawUnit = self._boardRig:getSim():getUnit(self._unitID)
	if rawUnit == nil then
		-- Unit may have been despawned.  We may only exist as a ghost rig.
		return
	end
	
	local teamClr = self._boardRig:getTeamColour(rawUnit:getPlayerOwner()).primary
	local gfxOptions = self._boardRig._game:getGfxOptions()
	

	if  rawUnit:getTraits().actionhilite == true then
	   	if gfxOptions.bMainframeMode then
			self._actionhilite:setVisible(false)
	   	else
			self._actionhilite:setVisible(true)
	   	end
   	end


	if rawUnit:getTraits().mainframe_item == true then
		if rawUnit:getTraits().mainframe_status == "off" and not gfxOptions.bMainframeMode then
			self._prop:setSymbolVisibility( "red", "internal_red", "highlight", "teal", false )

		elseif not rawUnit:getTraits().mainframe_console then

			if gfxOptions.bMainframeMode then
				self._HUDmainframeBorder:setVisible(true)
				self._HUDmainframeBorder:setSymbolModulate("tileBorder_Internal", teamClr.r, teamClr.g, teamClr.b, 1 )
			else
				self._HUDmainframeBorder:setVisible(false)
			end

			if rawUnit:getPlayerOwner() and rawUnit:getPlayerOwner():isNPC() and not gfxOptions.bMainframeMode then 
				self._prop:setSymbolVisibility( "red", "internal_red", true )
				self._prop:setSymbolVisibility( "highlight", "teal", false )
			else
				self._prop:setSymbolVisibility( "red", "internal_red", false )
				self._prop:setSymbolVisibility( "highlight", "teal", true )
			end
		end

	end

end

function unitrig:refreshRenderFilter() 
	local cell = self._boardRig:getLastKnownCell( self:getLocation() )
	if cell then
		local gfxOptions = self._boardRig._game:getGfxOptions()
		local cellrig = self._boardRig:getClientCellXY( cell.x, cell.y )

		local render_filter
		if gfxOptions.bMainframeMode then
			local unit = self:getUnit()
			local playerOwner = unit:getPlayerOwner()

			if unit:getTraits().mainframe_status == "off" then
				render_filter = 'mainframe_fused'
			elseif playerOwner == nil or playerOwner:isNPC() then
				render_filter = 'mainframe_npc'
			else
				render_filter = 'default'
			end
		else
			if gfxOptions.bFOWEnabled then
				if cell and not cell.ghostID  then
					render_filter = cdefs.MAPTILES[ cellrig.tileIndex ].render_filter.dynamic or "shadowlight"
				else
					render_filter = cdefs.MAPTILES[ cellrig.tileIndex ].render_filter.fow or gfxOptions.FOWFilter
				end
			else
				render_filter = (cellviz and cdefs.MAPTILES[ cellrig.tileIndex ].render_filter.normal) or gfxOptions.KAnimFilter
			end
		end
		self._prop:setRenderFilter( cdefs.RENDER_FILTERS[ render_filter ] )
	
	end
	
end

return
{
	rig = unitrig,
	base_state = base_state,
}

