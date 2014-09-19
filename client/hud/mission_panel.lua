----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local mui = include( "mui/mui" )
local util = include( "client_util" )  
local mathutil = include( "modules/mathutil" )
local modalDialog = include( "states/state-modal-dialog" )
local level = include( "sim/level" )
local cdefs = include( "client_defs" )
include( "class" )

----------------------------------------------------------------
---  in-world hilite arrow

local hilite_arrow = class()

function hilite_arrow:init( hud, name, scale, x, y )	
	self._boardrig = hud._game.boardRig
	self._name = name
	self._prop = self._boardrig:createHUDProp("kanim_tutorial_tile_arrow", "character", "idle", self._boardrig:getLayer("ceiling"), nil, x, y )
end

function hilite_arrow:destroy( screen )
	self._boardrig:getLayer("ceiling"):removeProp( self._prop )
end

function hilite_arrow:getName()
	return self._name
end

----------------------------------------------------------------
---  widget hilite

local function hiliteAnimHandler( anim, animname )
	if animname == "in" then
		anim:setCurrentAnim( "loop" )
	end
end

local hilite_widget = class()

function hilite_widget:init( hud, name, scale, widgetName, rectangle )
	assert( type(widgetName) == "string" )

	self._name = name
	self._scale = scale or 1
	if rectangle then
		self._widget = hud._screen:createFromSkin( "tutorialCircle_rectangle" )
	else
		self._widget = hud._screen:createFromSkin( "tutorialCircle" )
	end
	self._widget:setTopmost( true )
	--self._widget.binder.circle:getProp():setListener( KLEIAnim.EVENT_ANIM_END, hiliteAnimHandler )

	self._parent = nil -- The parent widget it is anchored to
	self._parentName = widgetName

	self:refresh( hud )
end

function hilite_widget:refresh( hud )
	local parent = hud._screen:findWidget( self._parentName ) or hud._world_hud._screen:findWidget( self._parentName )
	if parent == nil and hud._itemsPanel then
		parent = hud._itemsPanel:findWidget( self._parentName )
	end

	if parent and self._parent == parent then
		return -- still attached to ther right thing!
	
	else
		if self._parent then
			-- Had a parent, but it's no longer active
			self._parent:removeChild( self._widget )
			self._parent = nil
		end

		if parent then
			self._parent = parent
			self._parent:addChild( self._widget )
			self._widget.binder.circle:setAnim( "in" )
			self._widget:setScale( self._scale, self._scale )
		end
	end
end

function hilite_widget:destroy( screen )
	if self._parent then
		self._parent:removeChild( self._widget )
		self._parent = nil
	end
end

function hilite_widget:getName()
	return self._name
end


local blink_widget = class()

function blink_widget:init( hud, widgetName, blinkData )
	assert( type(widgetName) == "string" )

	self._blinkData = blinkData
	self._parentName = widgetName
	self:refresh( hud )
end

function blink_widget:refresh( hud )
	local parent = hud._screen:findWidget( self._parentName ) or hud._world_hud._screen:findWidget( self._parentName )
	if parent == nil and hud._itemsPanel then
		parent = hud._itemsPanel:findWidget( self._parentName )
	end

	if parent and self._parent == parent then
		return -- still attached to ther right thing!
	
	else
		if self._parent then
			-- Had a parent, but it's no longer active
			local btn = self._parent
			if self._parent.binder and self._parent.binder.btn then
				btn = self._parent.binder.btn
			end

			btn:blink( nil )
			self._parent = nil
		end

		if parent then
			self._parent = parent
			local btn = self._parent
			if self._parent.binder and self._parent.binder.btn then
				btn = self._parent.binder.btn
			end
			btn:blink( self._blinkData.period, self._blinkData.blinkCountPerPeriod, self._blinkData.periodInterval, {r=1,g=1,b=1,a=1} )
		end
	end
end

function blink_widget:destroy( screen )
	if self._parent then
		local btn = self._parent
		if self._parent.binder and self._parent.binder.btn then
			btn = self._parent.binder.btn
		end

		btn:blink( nil )
		self._parent = nil
	end
end

function blink_widget:getName()
	return "blink-"..self._parentName
end

local function setupWidgetAnims( self, widgetName )
	local animWidget = self._hud._screen:findWidget(widgetName)
	animWidget:getProp():setListener( KLEIAnim.EVENT_ANIM_END,
				function( anim, animname )
					if animname == "in" then
						animWidget:setAnim("loop")
					elseif animname == "out" then
						animWidget:setVisible(false)
					end
				end )
end	
----------------------------------------------------------------
-- Interface functions

local mission_panel = class()

function mission_panel:init( hud, screen )
	self._hud = hud
	self._screen = screen
	self._screen._operator_screen = mui.createScreen( "operator-message.lua" )
	self._screen._enemy_screen = mui.createScreen( "enemy-message.lua" )
	self._screen._message_screen = mui.createScreen( "connection-message.lua" )
	self._screen._black_screen = mui.createScreen( "black.lua" )

	--for glowing instructional text
	self._instructionsHighlightTimer = 0
	self._guardStatusHighlightTimer = 0
	
	self._instructionsHighlightDirection = 1
	self._guardStatusHighlightDirection = 1

	self._instructionsHighlightColor1 ={r=255/255,g=255/255,b=255/255,a=1}
	self._instructionsHighlightColor2 ={r=255/255,g=255/255,b=255/255,a=0.6}

	self.hiliteObjects = {}
	self.lastOperatorMessage = {}

	-- Mission panel event queue handled in its own coroutine.
	self._thread = MOAICoroutine.new()
	self._thread:run( function() self:processQueue() end )
	self._thread:resume()	

	-- make the anim in the insturction widget loop after it finished coming in
	setupWidgetAnims( self, "instructionGroup.anim" )
	setupWidgetAnims( self, "guardStatusGroup.anim" )
end	

function mission_panel:startBlackScreen()
	if not self._screen._black_screen:isActive() then
		mui.activateScreen( self._screen._black_screen )
		self._screen._black_screen:findWidget("black"):setColor(0,0,0,1)
		MOAIFmodDesigner.setAmbientReverb( "mainframe" )
		FMODMixer:pushMix("nomusic")
	end
end

function mission_panel:deleteObject(name)	
	for i,object in ipairs (self.hiliteObjects) do 
	 	if name == object:getName() then
	 		object:destroy( self._screen )
	 		table.remove(self.hiliteObjects,i)
	 		break
	 	end				 	
	end
end

function mission_panel:processEvent( event )
	--log:write("processEvent( %s )", util.stringize(event,2))

	if type(event) == "number" then
		while event > 0 do
			coroutine.yield()
			event = event - 1
		end

	elseif event.type == "ui" then
		local w = self._hud._screen.binder[event.widget]
		w:setVisible( event.visible )

	elseif event.type == "blink" then
		local object = blink_widget( self._hud, event.target, event.blink )
		table.insert( self.hiliteObjects, object )

	elseif event.type == "arrow" then
		local x, y
		if event.unit then
			x, y = event.unit:getLocation()
		elseif event.pos then
			x, y = event.pos.x, event.pos.y
		end
		x, y = self._hud._game.boardRig:cellToWorld( x, y )

		local object = hilite_arrow ( self._hud, event.name, event.scale, x, y )
		table.insert( self.hiliteObjects, object )

	elseif event.type == "tutorialCircle" then
		local object = hilite_widget( self._hud, event.name, event.scale, event.target , event.rectangle)
		table.insert( self.hiliteObjects, object )

	elseif event.type == "pan" then
		self._hud._game:cameraPanToCell( event.x, event.y )
	elseif event.type == "unlockDoor" then		
		MOAIFmodDesigner.playSound( "SpySociety/Actions/door_passcardunlock", nil, nil, {event.x, event.y,0}, nil )

	elseif event.type == "stopVO" then	
		MOAIFmodDesigner.stopSound( "VO" )

	elseif event.type == "operatorVO" then	
		MOAIFmodDesigner.stopSound( "VO" )
		MOAIFmodDesigner.playSound( event.soundPath, "VO" )

	elseif event.type == "operatorMessage" then	
		MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/textbox" )
		--MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/levelup" )
		mui.activateScreen( self._screen._operator_screen )
		
		self._screen._operator_screen:findWidget("bodyTxt"):spoolText( event.body )
		self._screen._operator_screen:findWidget("instructionsTxt"):setText( event.instructions )

		local friends = self._screen._operator_screen:findWidget("Friends")
		if not friends:hasTransition() then
			self._screen._operator_screen:findWidget("Friends"):createTransition( "activate_left" )
		end

		local label = event.label or "main"
		self.lastOperatorMessage[ label ] = event

		if event.profileAnim then
			self._screen._operator_screen:findWidget("profileAnim"):bindBuild( event.profileBuild )
			self._screen._operator_screen:findWidget("profileAnim"):bindAnim( event.profileAnim )
		end

	elseif event.type == "lastOperatorMessage" then	
		event = self.lastOperatorMessage[ event.label ]
		if event then
			self:processEvent( event )
		end
	elseif event.type == "displayGuardStatus" then
		self._hud._screen:findWidget("guardStatusGroup.instructionsTxt"):setVisible(false)
		self._hud._screen:findWidget("guardStatusGroup.instructionsSubTxt"):setVisible(false)

		local anim = self._hud._screen:findWidget("guardStatusGroup.anim")

		self._hideGuardStatus = false
		self._guardStatusTxt = nil
		self._guardStatusSubText = nil

		if event.x and event.y then
			self._guardStatusOnCell = { x=event.x, y=event.y }
			self._guardStatusTxt = self._hud._screen:findWidget("guardStatusGroup.instructionsTxt")
			anim:setVisible(true)
			anim:setAnim("in")
		else
			assert(false and "NO PROPER DISPLAY TYPE")
		end

		self._guardStatusTxt:setVisible(true)
		self._guardStatusTxt:spoolText(event.text,10)
		self._guardStatusTxt:setColor(1,1,1,1)

		if event.subtext then
			self._guardStatusSubText = self._hud._screen:findWidget("guardStatusGroup.instructionsSubTxt")
			self._guardStatusSubText:spoolText(event.subtext, 10)
			self._guardStatusSubText:setVisible(true)
		end

	elseif event.type == "hideGuardStatus" then
		self._hideGuardStatus = true

		local anim = self._hud._screen:findWidget("guardStatusGroup.anim")		
		anim:setAnim("out")

		self._guardStatusOnCell = nil
		self._guardStatusHighlightTimer = 0

	elseif event.type == "displayICEpulse" then

		local widget = self._hud._world_hud._screen:findWidget("pulse")				
		
		widget:setVisible(true)

	elseif event.type == "hideICEpulse" then

		local widget = self._hud._world_hud._screen:findWidget("pulse")				
		
		widget:setVisible(false)

	elseif event.type == "displayHUDpulse" then
	
		self._pulse = self._hud._screen:findWidget("pulse")				

		self._pulseOffset = {x=0,y=0}
		if event.offset then
			--transform to UI space
			self._pulseOffset.x, self._pulseOffset.y = self._hud._screen:wndToUI( event.offset.x, event.offset.y )
			self._pulseOffset.y = 1 - self._pulseOffset.y
		end		

		local widget = self._hud._screen:findWidget(event.widget) or self._hud._world_hud._screen:findWidget(event.widget)

		if widget then
			local x, y = widget:getAbsolutePosition()
			self._pulse:setPosition( x + self._pulseOffset.x, y + self._pulseOffset.y )
		end
		
	 	self._pulse:setVisible(true)	
		self._pulse:getProp():setCurrentAnim("idle")
--[[
		self._pulse:getProp():setListener( KLEIAnim.EVENT_ANIM_END,
				function( anim, animname )
					if animname == "idle" then
						self._pulse:setVisible(false)
					end
				end )
]]

	elseif event.type == "hideHUDpulse" then

		self._pulse = self._hud._screen:findWidget("pulse")				
		self._pulse:setVisible(false)


	elseif event.type == "displayHUDInstruction" then

		self._hud._screen:findWidget("instructionGroup.instructionsTxt"):setVisible(false)
		self._hud._screen:findWidget("instructionGroup.instructionsTxtDrop"):setVisible(false)
		self._hud._screen:findWidget("instructionGroup.instructionsTxtNoLine"):setVisible(false)
		self._hud._screen:findWidget("instructionGroup.instructionsTxtNoLineDrop"):setVisible(false)
		self._hud._screen:findWidget("instructionGroup.instructionsSubTxtNoLine"):setVisible(false)
		self._hud._screen:findWidget("instructionGroup.instructionsSubTxtNoLineDrop"):setVisible(false)
		self._hud._screen:findWidget("instructionGroup.instructionsSubTxt"):setVisible(false)

		self._instructionOffset = {x=0,y=0}
		if event.offset then
			--transform to UI space
			self._instructionOffset.x, self._instructionOffset.y = self._hud._screen:wndToUI( event.offset.x, event.offset.y )
			self._instructionOffset.y = 1 - self._instructionOffset.y
		end

		local anim = self._hud._screen:findWidget("instructionGroup.anim")

		self._hideInstruction = false
		self._instructionTxt = nil
		self._instructionTxtDrop = nil
		self._instructionSubText = nil
		self._instructionSubTextDrop = nil
		self._followMovement = event.followMovement
		self._followWidget = event.widget
		if self._followMovement then
			self._instructionTxt = self._hud._screen:findWidget("instructionGroup.instructionsTxtNoLine")
			self._instructionTxtDrop = self._hud._screen:findWidget("instructionGroup.instructionsTxtNoLineDrop")
			anim:setVisible(false)

			--move the widget behind the hud elements
			local w = self._hud._screen:findWidget("instructionGroup")
			self._hud._screen:reorderWidget( w, 1 )
		elseif event.x and event.y then
			self._instructionOnCell = { x=event.x, y=event.y }
			self._instructionTxt = self._hud._screen:findWidget("instructionGroup.instructionsTxt")
			self._instructionTxtDrop = self._hud._screen:findWidget("instructionGroup.instructionsTxtDrop")
			anim:setVisible(true)
			anim:setAnim("in")

			--move the widget behind the hud elements
			local w = self._hud._screen:findWidget("instructionGroup")
			self._hud._screen:reorderWidget( w, 1 )
		elseif event.widget then
			self._followWidget = event.widget
			self._instructionTxt = self._hud._screen:findWidget("instructionGroup.instructionsTxt")
			self._instructionTxtDrop = self._hud._screen:findWidget("instructionGroup.instructionsTxtDrop")
			anim:setVisible(true)
			anim:setAnim("in")

			--move the widget in front of the hud elements
			local w = self._hud._screen:findWidget("instructionGroup")
			self._hud._screen:reorderWidget( w, nil )
		else
			assert(false and "NO PROPER DISPLAY TYPE")
		end

		self._instructionTxt:setVisible(true)
		self._instructionTxtDrop:setVisible(true)
		self._instructionTxt:spoolText(event.text,10)
		self._instructionTxtDrop:spoolText(event.text,10)

		if event.subtext then
			if self._followMovement then
				self._instructionSubText = self._hud._screen:findWidget("instructionGroup.instructionsSubTxtNoLine")
				self._instructionSubTextDrop = self._hud._screen:findWidget("instructionGroup.instructionsSubTxtNoLineDrop")
			else
				self._instructionSubText = self._hud._screen:findWidget("instructionGroup.instructionsSubTxt")
				self._instructionSubTextDrop = nil
			end

			if self._instructionSubTextDrop then
				self._instructionSubTextDrop:spoolText(event.subtext, 10)
				self._instructionSubTextDrop:setVisible(true)
				self._instructionSubTextDrop:setColor(0,0,0)
			end

			self._instructionSubText:spoolText(event.subtext, 10)
			self._instructionSubText:setVisible(true)
			self._instructionSubText:setColor(1,1,1,1)
		end

		self._hud._screen:findWidget("instructionGroup.leftclick"):setVisible(event.leftclick or false)
		self._hud._screen:findWidget("instructionGroup.rightclick"):setVisible(event.rightclick or false)

	elseif event.type == "hideHUDInstruction" then
		self._hideInstruction = true
		self._hud._screen:findWidget("instructionGroup.leftclick"):setVisible(false)
		self._hud._screen:findWidget("instructionGroup.rightclick"):setVisible(false)
		if self._instructionOnCell or self._followWidget then
			local anim = self._hud._screen:findWidget("instructionGroup.anim")		
			anim:setAnim("out")
		end
		self._instructionOnCell = nil
		self._followMovement = false
		self._followWidget = nil
		self._instructionsHighlightTimer = 0
		--self._hud._screen:findWidget("instructionGroup"):setVisible(false)

	elseif event.type == "enemyMessage" then	
		MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/textbox2" )
		mui.activateScreen( self._screen._enemy_screen )
		self._screen._enemy_screen:findWidget("bodyTxt"):spoolText( event.body )
		self._screen._enemy_screen:findWidget("headerTxt"):spoolText( event.header )
		self._screen._enemy_screen:findWidget("Enemies"):createTransition( "activate_left" )
		self._hud:setAlarmVisible(false)

		if event.profileAnim then
			self._screen._enemy_screen:findWidget("profileAnim"):bindBuild( event.profileBuild )
			self._screen._enemy_screen:findWidget("profileAnim"):bindAnim( event.profileAnim )
		end

	elseif event.type == "clearEnemyMessage" then
		if self._screen._enemy_screen:isActive() then
			mui.deactivateScreen( self._screen._enemy_screen )	
			if not self._hud._game.simCore:getTags().isTutorial then
				self._hud:setAlarmVisible(true)
			end
		end

	elseif event.type == "clearOperatorMessage" then	
		if self._screen._operator_screen:isActive() then
			mui.deactivateScreen( self._screen._operator_screen )	
		end

	elseif event.type == "startConnection" then
		self:startBlackScreen()

	elseif event.type == "establishConnection" then
		--jcheng: update connection to agent
		if event.name then
			mui.activateScreen( self._screen._message_screen )
			self._screen._message_screen:findWidget("headerTxt"):spoolText( event.name, 30 )
			--MOAIFmodDesigner.playSound( "SpySociety/HUD/menu/popdown" )
			MOAIFmodDesigner.playSound( "SpySociety/HUD/menu/loading" )
			--MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/makingconnection" )
			--MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/listenTemp" )
			
		else
			mui.deactivateScreen( self._screen._message_screen )
		end

	elseif event.type == "fadeIn" then
		local camera = self._hud._game:getCamera()
		camera:rotateOrientation( event.orientation )

		self:startBlackScreen()
		self._fadingIn = true
		self._fadeInIndex = 0
		KLEIRenderScene:pulseUIFuzz( 0.5 )
		self._screen._black_screen:findWidget("black"):setColor(1,1,1,1)

		MOAIFmodDesigner.setAmbientReverb( "office" )
		FMODMixer:popMix("nomusic")
		
		--MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/purchase" )
		MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/Operator/largeconnection" )
		--MOAIFmodDesigner.playSound( "SpySociety/HUD/gameplay/tutorial/connectionmade" )
		--self._hud._game:cameraPanToCell( event.x, event.y )

	else
		assert( false, event.type )
	end
end

function mission_panel:onUpdate()
	for i, hilite in ipairs( self.hiliteObjects ) do
		if hilite.refresh then
			hilite:refresh( self._hud )
		end
	end

	if self._fadingIn == true then
		self._fadeInIndex = self._fadeInIndex + 3
		if self._fadeInIndex < 100 then
			local t = self._fadeInIndex / 100
			self._screen._black_screen:findWidget("black"):setColor(1,1,1,mathutil.lerp(1,0,t))
		else
			self._fadingIn = false
			mui.deactivateScreen( self._screen._black_screen )
			--KLEIRenderScene:pulseUIFuzz( 0.2 )
		end
	end

	--jcheng: update the instructions so it glows
	if self._instructionTxt then
		if self._hideInstruction then
			self._instructionsHighlightTimer = self._instructionsHighlightTimer + 4
			local t = self._instructionsHighlightTimer / 100
			if t >=1 then t = 1 end

			self._instructionTxt:setColor(
				mathutil.inQuad( self._instructionsHighlightColor1.r , self._instructionsHighlightColor2.r ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.g , self._instructionsHighlightColor2.g ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.b , self._instructionsHighlightColor2.b ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.a , 0 ,t)
			)
			self._instructionTxtDrop:setColor(0,0,0,
				mathutil.inQuad( self._instructionsHighlightColor1.a , 0 ,t)
			)

			if self._instructionSubText then
				self._instructionSubText:setColor(1,1,1,
					mathutil.inQuad( self._instructionsHighlightColor1.a , 0 ,t)
				)
			end

			if self._instructionSubTextDrop then
				self._instructionSubTextDrop:setColor(0,0,0,
					mathutil.inQuad( self._instructionsHighlightColor1.a , 0 ,t)
				)
			end

			if t >= 1 then
				--done fading out, set everything to nil
				self._hideInstruction = false
				self._instructionTxt = nil
				self._instructionTxtDrop = nil
				--self._hud._screen:findWidget("instructionGroup"):setVisible(false)
			end
		else
			if self._instructionsHighlightDirection > 0 then
				self._instructionsHighlightTimer = self._instructionsHighlightTimer + 2
				if self._instructionsHighlightTimer >= 100 then
					self._instructionsHighlightTimer = 100
					self._instructionsHighlightDirection = -1
				end
			else
				self._instructionsHighlightTimer = self._instructionsHighlightTimer - 2
				if self._instructionsHighlightTimer <= 0 then
					self._instructionsHighlightTimer = 0
					self._instructionsHighlightDirection = 1
				end
			end

			local t = self._instructionsHighlightTimer / 100

			self._instructionTxt:setColor(
				mathutil.inQuad( self._instructionsHighlightColor1.r , self._instructionsHighlightColor2.r ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.g , self._instructionsHighlightColor2.g ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.b , self._instructionsHighlightColor2.b ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.a , self._instructionsHighlightColor2.a ,t)
			)
			self._instructionTxtDrop:setColor(0,0,0,
				mathutil.inQuad( self._instructionsHighlightColor1.a , self._instructionsHighlightColor2.a ,t)
			)
		end
	end

	if self._guardStatusTxt then
		if self._hideGuardStatus then
			self._guardStatusHighlightTimer = self._guardStatusHighlightTimer + 4
			local t = self._guardStatusHighlightTimer / 100
			if t >=1 then t = 1 end

			self._guardStatusTxt:setColor(
				mathutil.inQuad( self._instructionsHighlightColor1.r , self._instructionsHighlightColor2.r ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.g , self._instructionsHighlightColor2.g ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.b , self._instructionsHighlightColor2.b ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.a , 0 ,t)
			)

			if self._guardStatusSubText then
				self._guardStatusSubText:setColor(1,1,1,
					mathutil.inQuad( self._instructionsHighlightColor1.a , 0 ,t)
				)
			end

			if t >= 1 then
				--done fading out, set everything to nil
				self._hideGuardStatus = false
				self._guardStatusTxt = nil
				--self._hud._screen:findWidget("instructionGroup"):setVisible(false)
			end
		else
			if self._guardStatusHighlightDirection > 0 then
				self._guardStatusHighlightTimer = self._guardStatusHighlightTimer + 2
				if self._guardStatusHighlightTimer >= 100 then
					self._guardStatusHighlightTimer = 100
					self._guardStatusHighlightDirection = -1
				end
			else
				self._guardStatusHighlightTimer = self._guardStatusHighlightTimer - 2
				if self._guardStatusHighlightTimer <= 0 then
					self._guardStatusHighlightTimer = 0
					self._guardStatusHighlightDirection = 1
				end
			end

			local t = self._guardStatusHighlightTimer / 100

			self._guardStatusSubText:setColor(
				mathutil.inQuad( self._instructionsHighlightColor1.r , self._instructionsHighlightColor2.r ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.g , self._instructionsHighlightColor2.g ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.b , self._instructionsHighlightColor2.b ,t),
				mathutil.inQuad( self._instructionsHighlightColor1.a , self._instructionsHighlightColor2.a ,t)
			)

			--self._guardStatusTxt:setColor(0,0,0, mathutil.inQuad( self._instructionsHighlightColor1.a , self._instructionsHighlightColor2.a ,t)	)
		end

	end

	--instructions
	if self._followMovement then

		local widget = self._hud._screen:findWidget("instructionGroup")
		if self._hud._bValidMovement then
			--local cell = self._hud._game.simCore:getCell( self._hud._game:wndToCell( inputmgr.getMouseXY() ) )
			--local wx, wy = self._hud._game:cellToWorld( cell.x, cell.y )
			local wndx, wndy = inputmgr.getMouseXY() --self._hud._game:worldToWnd( wx, wy )
			local uix, uiy = self._hud._screen:wndToUI( wndx, wndy )
			widget:setPosition( uix + self._instructionOffset.x, uiy + self._instructionOffset.y )
			widget:setVisible(true)
		else
			widget:setVisible(false)
		end

	elseif self._instructionOnCell then

		local wx, wy = self._hud._game:cellToWorld( self._instructionOnCell.x, self._instructionOnCell.y )
		local wndx, wndy = self._hud._game:worldToWnd( wx, wy )
		local widget = self._hud._screen:findWidget("instructionGroup")
		local uix, uiy = self._hud._screen:wndToUI( wndx, wndy )
		widget:setPosition( uix + self._instructionOffset.x, uiy + self._instructionOffset.y )
		widget:setVisible(true)

	elseif self._followWidget then

		local instructionWidget = self._hud._screen:findWidget("instructionGroup")
		local widget = self._hud._screen:findWidget(self._followWidget) or self._hud._world_hud._screen:findWidget(self._followWidget)
		
		if widget then
			local x, y = widget:getAbsolutePosition()

			instructionWidget:setPosition( x + self._instructionOffset.x, y + self._instructionOffset.y )
			instructionWidget:setVisible(true)
		else
			instructionWidget:setVisible(false)
		end
	end

	if self._guardStatusOnCell then

		local wx, wy = self._hud._game:cellToWorld( self._guardStatusOnCell.x, self._guardStatusOnCell.y )
		local wndx, wndy = self._hud._game:worldToWnd( wx, wy )
		local widget = self._hud._screen:findWidget("guardStatusGroup")
		local uix, uiy = self._hud._screen:wndToUI( wndx, wndy )
		widget:setPosition( uix, uiy )
		widget:setVisible(true)

	end
end

function mission_panel:processQueue( eventQueue )
	local eventQueue = self._hud._game.simCore:getLevelScript():getQueue()

	while true do
		if #eventQueue > 0 then
			local event = table.remove( eventQueue, 1 )
			self:processEvent( event )
		else
			coroutine.yield()
		end
	end
end

function mission_panel:clear()
	self._fadingIn = nil

	if self._screen._operator_screen and self._screen._operator_screen:isActive() then
		mui.deactivateScreen( self._screen._operator_screen )
	end

	if self._screen._enemy_screen and self._screen._enemy_screen:isActive() then
		mui.deactivateScreen( self._screen._enemy_screen )
	end

	if self._screen._black_screen and self._screen._black_screen:isActive() then
		mui.deactivateScreen( self._screen._black_screen )
	end
	
	if self._screen._message_screen and self._screen._message_screen:isActive() then
		mui.deactivateScreen( self._screen._message_screen )
	end
	
	while #self.hiliteObjects > 0 do
		self:deleteObject( self.hiliteObjects[1]:getName() )
	end
end

function mission_panel:destroy()
	self:clear()

	self._thread:stop()
	self._thread = nil
end

return mission_panel
