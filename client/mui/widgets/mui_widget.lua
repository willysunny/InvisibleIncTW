-----------------------------------------------------
-- MOAI UI
-- Copyright (c) 2012-2012 Klei Entertainment Inc.
-- All Rights Reserved.

local array = require( "modules/array" )
local util = require( "modules/util" )
local mui_defs = require( "mui/mui_defs" )
local mui_util = require("mui/mui_util")
local mui_tooltip = require( "mui/mui_tooltip" )
require( "class" )

--------------------------------------------------------

local mui_widget = class()

function mui_widget:init( def )
	self._name = def.name
	if def.tooltipHeader or def.tooltipFooter then
		self._tooltip = mui_tooltip( def.tooltipHeader, def.tooltip, def.tooltipFooter )
	else
		-- Simply cheaper to store as a string if that's all it is, and lazy-create the tooltip
 		self._tooltip = def.tooltip
	end
end

function mui_widget:getName()
	return self._name
end

function mui_widget:getAlias()
	return self._alias
end

function mui_widget:setAlias( alias )
	self._alias = alias
end

function mui_widget:seekLoc( xGoal, yGoal, length, mode )
	self._cont:getProp():seekLoc( xGoal, yGoal, length, mode)
end


function mui_widget:seekScl( xGoal, yGoal, zGoal, length, mode )
	self._cont:getProp():seekScl( xGoal, yGoal, zGoal, length, mode)
end

function mui_widget:setTopmost( isTopmost )
	if isTopmost then
		self._priority = mui_util.TOP_PRIORITY
	else
		self._priority = nil
	end
end

function mui_widget:getScreen()
	local parent = self._parent
	while parent and parent._parent ~= nil do
		parent = parent._parent
	end
	
	local mui_screen = include( "mui/mui_screen" )
	if parent ~= nil and not parent:is_a( mui_screen ) then
		return nil
	end

	return parent
end

function mui_widget:attach( parent, container )
	-- Link root component to container.
	self._cont:link( container )

	-- We are attaching to the parent (which might be another widget, or a screen)
	self._parent = parent
	
	-- If we are now newly added to the active tree, need to trigger activation.
	local screen = self:getScreen()
	if screen and screen:isActive() then
		self:onActivate( screen )
		screen:refreshPriority()
	end
end

function mui_widget:detach( container )
	-- Trigger deactivation cleanup.
	local screen = self:getScreen()
	if screen and screen:isActive() then
		self:onDeactivate( screen )
		screen:refreshPriority()
	end

	-- Remove parenting.
	self._parent = nil

	-- Unlink from container.
	self._cont:unlink( container )
end

function mui_widget:updatePriority( nextPriority )
	local priority = self._cont:updatePriority( self._priority or nextPriority )
	if self._children then
		for i,widget in ipairs(self._children) do
			priority = widget:updatePriority( priority + 1 )
		end
	end

	-- don't return the overriden priority, but the original one.
	if self._priority then
		return nextPriority
	else
		return priority
	end
end

function mui_widget:reorderWidget( widget, newIdx )
	assert( array.find( self._children, widget ) ~= nil )
	array.removeElement( self._children, widget )
	if newIdx then
		assert( #self._children + 1 >= newIdx )
		table.insert( self._children, newIdx, widget )
	else
		table.insert( self._children, widget )
	end
	self:getScreen():refreshPriority()
end


function mui_widget:addChild( widget )
	if self._children == nil then
		self._children = {}
	end

	table.insert( self._children, widget )
	widget:attach( self, self._cont )
end

function mui_widget:removeChild( widget )
	array.removeElement( self._children, widget )
	widget:detach( self._cont )
end

function mui_widget:onActivate( screen )
	self._cont:recurse(
		function( component )
			component:onActivate( screen, self )
		end )

	if self._children then
		for i,widget in ipairs(self._children) do
			widget:onActivate( screen )
		end
	end
end

function mui_widget:onDeactivate( screen )
	self._cont:recurse(
		function( component )
			component:onDeactivate( screen )
		end )

	if self._children then
		for i,widget in ipairs(self._children) do
			widget:onDeactivate( screen )
		end
	end
end

function mui_widget:setTooltip( tooltip )
	self._tooltip = tooltip
end

function mui_widget:handleTooltip()
	return self._tooltip
end

function mui_widget:setPosition( x, y )
	self._cont:setPosition( x, y )
end

function mui_widget:getSize()
	return self._cont:getSize()
end

function mui_widget:getPosition(  )
	return self._cont:getPosition()
end

function mui_widget:getAbsolutePosition()
	return self._cont:getProp():modelToWorld( 0, 0 )
end

function mui_widget:calculateBounds()
	local x, y, w, h
	if self._cont.calculateTotalBounds then
		x, y, w, h = self._cont:calculateTotalBounds()
	else
		x, y, w, h = self._cont:calculateBounds()
	end

	if self._children == nil or #self._children == 0 then
		return x, y, w, h
	end

	local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
	for i,widget in ipairs(self._children) do
		local x, y, w, h = widget:calculateBounds()
		minx = math.min( minx, x - w/2 )
		maxx = math.max( maxx, x + w/2 )
		miny = math.min( miny, y - h/2 )
		maxy = math.max( maxy, y + h/2 )
	end

	return (minx + maxx) / 2 + x, (miny + maxy) / 2 + y, (maxx - minx), (maxy - miny)
end


function mui_widget:setScale( sx, sy )
	self._cont:setScale( sx, sy )
end

function mui_widget:findWidget( path )
	if path then
		local name, more = path:match( "([^.]*)[.]?(.*)" )
		if self._name == name or self._alias == name then
			path = more -- Matched ourselves; leave the remaining path
		end

		-- If there's nothing left in the path, then return this widget.
		if path == "" then
			return self
		end

		local found = nil
		if self._children then
			for i,widget in ipairs(self._children) do
				found = widget:findWidget( path )
				if found then
					break
				end
			end
		end
			
		return found
	end
end



function mui_widget:setVisible( isVisible )
	self._cont:setVisible( isVisible )
end

function mui_widget:isVisible()
	return self._cont:isVisible()
end

function mui_widget:handleEvent( ev )
end

function mui_widget:createTransition( name, fn, params )
	if self:hasTransition() then
		self:clearTransition()
	end

	local transitionDef = self:getScreen()._transitions[ name ]
	assert( transitionDef, name )

	if params then
		transitionDef = util.inherit( transitionDef )( params )
	end

	self._cont:createTransition( transitionDef, fn )
end

function mui_widget:clearTransition()
	self._cont:clearTransition()
end

function mui_widget:hasTransition( ... )
	if self._cont:hasTransition( ... ) then
		return true
	end

	local parent = self._parent
	while parent ~= nil and not parent:hasTransition( ... ) do
		parent = parent._parent
	end

	return parent ~= nil
end

return mui_widget
