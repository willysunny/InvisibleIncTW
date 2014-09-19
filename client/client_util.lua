----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

--
-- Client-side helper functions.  Mostly these deal with MOAI userdata, as the
-- server will not support these.
-- For convenience, these are merged into the general util table.

local util = include( "modules/util" )
local mui_tooltip = include( "mui/mui_tooltip" )
----------------------------------------------------------------
-- Local functions

local tooltip_section  = class()

function tooltip_section:init( tooltip,color )
	self._tooltip = tooltip
	self._widget = tooltip._screen:createFromSkin( "tooltip_section" )
	self._children = {}
	if color then
		self._widget.binder.bg:setColor( color:unpack() )
	end	
end

function tooltip_section:appendHeader( actionTxt, infoTxt )
    self:addLine( string.format( "%s: <tthotkey>%s</>", actionTxt, infoTxt ))
end

function tooltip_section:addLine( txt, lineRight )
	local widget = self._tooltip._screen:createFromSkin( "tooltip_section_line" )
	widget.binder.line:setText( txt )
	widget.binder.lineRight:setText( lineRight )
	self._widget:addChild( widget )
	table.insert( self._children, widget )
end

function tooltip_section:addDesc( txt )
	local widget = self._tooltip._screen:createFromSkin( "tooltip_section_desc" )
	widget.binder.desc:setText( txt )
	self._widget:addChild( widget )
	widget.activate = function( self, screen )
		local W, H = screen:getResolution()
		local xmin, ymin, xmax, ymax = widget.binder.desc:getStringBounds()
		local th = math.floor(H * (ymax - ymin) / 2) * 2 + 12
		widget.binder.desc:setSize( nil, th )
		widget.binder.desc:setPosition( nil, th / -2)
		local tooltipBg = widget.binder.bg
		tooltipBg:setSize( nil, th )
		tooltipBg:setPosition( nil, th / -2 )
	end
	
	table.insert( self._children, widget )
end

function tooltip_section:addRange( hud, cells, color )
	self._hud = hud
	self._hiliteCells = cells
	self._hiliteColor = color or { 0.5, 0.5, 0.5, 0.5 }
end

function tooltip_section:addRequirement( txt )
	local widget = self._tooltip._screen:createFromSkin( "tooltip_section_line" )
	widget.binder.line:setText( "<c:ff0000>" .. txt .. "</>" )
	widget.binder.lineRight:setText( nil )
	self._widget:addChild( widget )
	table.insert( self._children, widget )
end

function tooltip_section:addAbility( line1, line2, icon, color )
	
	local widget = self._tooltip._screen:createFromSkin( "tooltip_section_ability" )	
	widget.binder.desc:setText( string.format( "<c:8CFFFF>%s</>\n%s", util.toupper(line1),line2 or "" ))

	widget.binder.img:setImage( icon )
	self._widget:addChild( widget )

	widget.binder.divider:setVisible( (self._abilityCount or 0) == 0 )
    self._abilityCount = (self._abilityCount or 0) + 1

	widget.activate = function( self, screen )
		local W, H = screen:getResolution()
		local xmin, ymin, xmax, ymax = widget.binder.desc:getStringBounds()		
		local th = math.floor(H * (ymax - ymin) / 2) * 2 +12 		
		widget.binder.desc:setSize( nil, th )
		widget.binder.desc:setPosition( nil,  math.floor(th / -2) ) 
		local tooltipBg = widget.binder.bg
		tooltipBg:setSize( nil, th )
		tooltipBg:setPosition( nil, math.floor(th  / -2) )
	end

	if color then
		widget.binder.bg:setColor(color:unpack())
	end
	
	table.insert( self._children, widget )
end

function tooltip_section:addWarning( title, line, icon, color )
	
	local widget = self._tooltip._screen:createFromSkin( "tooltip_section_warning" )	
	widget.binder.descTitle:setText( string.format( "%s", util.toupper(title) ))
	widget.binder.desc:setText( string.format( "%s\nTest\nTest", line or "" ))
	self._widget:addChild( widget )

	if color then
		widget.binder.bar1:setColor(color:unpack())
		widget.binder.bar2:setColor(color:unpack())
		widget.binder.bar3:setColor(color:unpack())
		widget.binder.bar4:setColor(color:unpack())
		widget.binder.descTitle:setColor(color:unpack())
		widget.binder.desc:setColor(color:unpack())
		widget.binder.img:setColor(color:unpack())
	end
	
	table.insert( self._children, widget )
end

function tooltip_section:activate( screen )
	self._screen = screen
	screen:addWidget( self._widget )

	self._widget:updatePriority( mui_tooltip.TOOLTIP_PRIORITY )

	if self._w == nil then
		local W, H = screen:getResolution()
		local ty = 0
		if #self._children > 0 then
			ty = -4 / H -- The buffer from the top of the tooltip.
 		end

		for _, child in ipairs( self._children ) do
			if child.activate then
				child:activate( screen )
			end

			child:setPosition( nil, ty )
			local x, y, w, h = child:calculateBounds()
			ty = math.floor((y - h/2) * H ) / H
		end

		if #self._children > 0 then
			self._widget.binder.bg:setSize( nil, math.floor( H * math.abs(ty) ) + 2 )
			self._widget.binder.bg:setPosition( nil, math.floor( H * -math.abs(ty) / 2 ) )
		end

		local x, y, w, h = self._widget:calculateBounds()
		self._w, self._h = w, h
	end

	if self._hiliteCells then
		self._rangeHiliteID = self._hud._game.boardRig:hiliteCells( self._hiliteCells, self._hiliteColor )
	end
end

function tooltip_section:deactivate( )
	self._screen:removeWidget( self._widget )
	if self._rangeHiliteID then
		self._hud._game.boardRig:unhiliteCells( self._rangeHiliteID )
		self._rangeHiliteID = nil
	end
end

function tooltip_section:getSize()
	return self._w, self._h
end

function tooltip_section:setPosition( tx, ty )
	self._widget:setPosition( tx, ty )
end


local tooltip = class( mui_tooltip )

function tooltip:init( screen )
	self._screen = screen
	self._sections = {}
end

function tooltip:clear()
	while #self._sections > 0 do
		table.remove( self._sections ):deactivate()
	end
end

function tooltip:addSection(color)
	local section = tooltip_section( self,color )
	table.insert( self._sections, section )
	return section
end

function tooltip:activate( screen )
	for _, section in ipairs( self._sections ) do
		section:activate( screen )
	end
end

function tooltip:deactivate()
	for _, section in ipairs( self._sections ) do
		section:deactivate()
	end
end

function tooltip:setPosition( wx, wy )	
	if #self._sections > 0 then
		local W, H = self._screen:getResolution()
		local YSPACING =  4 / H

		-- Need to calculate the total tooltip bound so we can fit it on screen.
		local tw, th = 0, 0
		for _, section in ipairs( self._sections ) do
			local sectionw, sectionh = section:getSize()
			tw = math.max( tw, sectionw )
			th = th + sectionh + YSPACING
		end

		-- Now position each tooltip section accordingly.
		local tx, ty = self:fitOnscreen( tw, th, self._screen:wndToUI( wx + mui_tooltip.TOOLTIPOFFSETX, wy + mui_tooltip.TOOLTIPOFFSETY ))
		for _, section in ipairs( self._sections ) do
			section:setPosition( tx, ty )
			local sectionw, sectionh = section:getSize()
			ty = ty - sectionh - YSPACING			
		end
	end
end

local function formatGameInfo( params )
	local str = string.format( "%sINVISIBLE, INC. %s.%s USER '%s'",
		MOAIEnvironment.isVerified() and "" or "MODDED ",
		MOAIEnvironment.Build_Branch, MOAIEnvironment.Build_Version,
		MOAIEnvironment.UserID or "" )
    str = str .. string.format( "\nOS: %s.%s.%s", MOAIEnvironment.OS, MOAIEnvironment.OS_Version, MOAIEnvironment.OS_Build )
	if params then
		str = str .. string.format("\nGAME %d.%d.%s.%s.%u", params.difficulty, params.gameDifficulty, params.situationName, params.location, params.seed )
	end
	return str
end

local function colorToRGBA( color )
	local r = color:getAttr( MOAIColor.ATTR_R_COL )
	local g = color:getAttr( MOAIColor.ATTR_G_COL )
	local b = color:getAttr( MOAIColor.ATTR_B_COL )
	local a = color:getAttr( MOAIColor.ATTR_A_COL )

	return r, g, b, a
end

local function formatTT( header, body, hotkey )
	assert( header and body )
	local tt = string.format( "<ttheader>%s</>\n<ttbody>%s</>", header, body )
	if hotkey then
		tt = tt .. string.format( "\nHOTKEY: <tthotkey>%s</>", hotkey )
	end
	return tt
end

local function assignTT( widget, header, body, hotkey )
	widget:setTooltip( formatTT( header, body, hotkey ))
end

local function applyUserSettings( settings )
	--log:write( "applyUserSettings: music: %f, SFX: %f", settings.volumeMusic, settings.volumeSfx )
	MOAIFmodDesigner.setMusicVolume( settings.volumeMusic )
	MOAIFmodDesigner.setCategoryVolume( "music/game", settings.volumeMusic )
	MOAIFmodDesigner.setCategoryVolume( "sfx", settings.volumeSfx )
end

local function applyGfxSettings( settings )
	return MOAISim.setGfxDisplayMode( settings )
end

----------------------------------------------------------------
-- Export table

return util.tmerge( util,
{
	applyUserSettings = applyUserSettings,
	applyGfxSettings = applyGfxSettings,
	colorToRGBA = colorToRGBA,
	formatGameInfo = formatGameInfo,
	tooltip = tooltip,
	formatTT = formatTT,
	assignTT = assignTT,

})
