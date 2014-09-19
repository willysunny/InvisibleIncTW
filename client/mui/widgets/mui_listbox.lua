-----------------------------------------------------
-- MOAI UI
-- Copyright (c) 2012-2012 Klei Entertainment Inc.
-- All Rights Reserved.

local array = require( "modules/array" )
local util = require( "modules/util" )
local mui_defs = require( "mui/mui_defs" )
local mui_widget = require( "mui/widgets/mui_widget" )
local mui_button = require( "mui/widgets/mui_button" )
local mui_texture = require( "mui/widgets/mui_texture" )
local mui_container = require( "mui/widgets/mui_container" )
local mui_scroller = require( "mui/widgets/mui_scroller" )
local mui_scrollbar = require( "mui/widgets/mui_scrollbar" )

--------------------------------------------------------
-- Local Functions

local ITEM_Inactive = 1
local ITEM_Active = 2
local ITEM_Hover = 3

local function updateItem( item )
	if item.image and item.hitbox then
		if item.hitbox:getState() == mui_button.BUTTON_Inactive then
			item.image:setImageIndex( ITEM_Inactive )
		elseif item.hitbox:getState() == mui_button.BUTTON_Active then
			item.image:setImageIndex( ITEM_Active )
		elseif item.hitbox:getState() == mui_button.BUTTON_Hover then
			item.image:setImageIndex( ITEM_Hover )
		end
	end
end

local function calculateItemY( listbox, idx )
	-- TODO: calculate item height dynamically instead of hijacking spcaing
	local item_height = listbox._item_spacing

	-- top_of_listbox - half_item_height - (zero_based_idx * item_height)
	return (listbox._h / 2) - 0.5 * item_height - (idx - listbox._scrollIndex - 1) * item_height
end

local function attachItem( listbox, item )
	assert( not item.isAttached )
	item.isAttached = true

	-- Parent the custom widget to the listbox.  Handles widget activation.
	listbox:addChild( item.widget )

	updateItem( item )
end

local function detachItem( listbox, item )
	assert( item.isAttached )
	item.isAttached = nil

	-- Unparent the widget from the listbox.  Handles widget deactivation.
	listbox:removeChild( item.widget )
end

local function updateItemPosition( listbox, idx )
	local y = calculateItemY( listbox, idx )
	local item = listbox._items[idx]
	local topIndex = listbox._scrollIndex
	local botIndex = listbox._scrollIndex + listbox:getMaxVisibleItems() - 1

	if (idx-1) < topIndex or (idx-1) > botIndex then
		if item.isAttached then
			detachItem( listbox, item )
		end
	else
		if not item.isAttached then
			attachItem( listbox, item )
		end
		item.widget:setPosition( 0, y )
	end
end


local function createItem( listbox, user_data, noHitbox )
	local item = {}

	item.cont = mui_container( { x=0, y=0, w=0, h=0, xpx = listbox._wpx, ypx = listbox._hpx, wpx = listbox._wpx, hpx = listbox._hpx } )
	
	if listbox._item_images then
		item.image = mui_texture( listbox._screen, {x=0, y=0, w=listbox._w, h=listbox._item_spacing, xpx = listbox._wpx, ypx = listbox._hpx, wpx = listbox._wpx, hpx = listbox._hpx, images=listbox._item_images} )
		item.cont:addComponent( item.image )
	end

	item.widget = listbox._item_ctor()

	if not listbox._no_hitbox then
		item.hitbox = mui_button( {x=0, y=0, w=listbox._w, h=listbox._item_spacing, xpx = listbox._wpx, ypx = listbox._hpx, wpx = listbox._wpx, hpx = listbox._hpx } )
		item.hitbox:addEventHandler( listbox, mui_defs.EVENT_ALL )
		item.cont:addComponent( item.hitbox )
	end

	item.user_data = user_data
	item.widget._cont:addComponent( item.cont )
	
	return item
end

local function updateLayout( listbox )
	local scrollbar = listbox._scrollbar.binder.scrollbar
	if scrollbar:getOrientation() == mui_scrollbar.ORIENT_H then
		scrollbar:setPosition( 0, (listbox._h + scrollbar._w) / 2 )
		scrollbar:setSize( listbox._w, nil )
	else
		scrollbar:setPosition( (listbox._w + scrollbar._w) / 2, 0.5 * (listbox._h - listbox:getMaxVisibleItems() * listbox._item_spacing) )
		scrollbar:setSize( nil, listbox:getMaxVisibleItems() * listbox._item_spacing )
	end
end

--------------------------------------------------------

local mui_listbox = class( mui_widget )

function mui_listbox:init( screen, def )
	mui_widget.init( self, def )

	self._screen = screen
	self._item_ctor = function() return screen:createFromSkin( def.item_template, { xpx = def.wpx, ypx = def.hpx } ) end
	self._item_spacing = def.item_spacing
	self._item_images = def.images
	self._no_hitbox = def.no_hitbox
	self._selectedIndex = nil
	self._scrollIndex = 0
	self._w, self._h = def.w, def.h
	self._wpx, self._hpx = def.wpx, def.hpx
	self._cont = mui_container( def )
	self._cont._prop:setBounds( -def.w / 2, -def.h / 2, 0, def.w / 2, def.h / 2, 0 )

	if def.scrollbar_template then
		self._scrollbar = screen:createWidget( { skin = def.scrollbar_template, hpx = true, wpx = true } )
		self:addChild( self._scrollbar )
		self._scrollbar.binder.scrollbar.onValueChanged =
			function( scrollbar, value )
				self:scrollItems( value )
			end
	end

	-- Scroller is not childed to self._cont, only prop-linked to it for location inheritance.
	-- Needs to be separate so that it can be in front of child widgets (items), while self._cont is behind.
	self._scroller = mui_scroller( util.inherit( def ){ x = 0, y = 0 })
	self._scroller:link( self._cont )
	self._scroller:addEventHandler( self, mui_defs.EVENT_Scroll )

	self._items = {}
end

function mui_listbox:findWidget( name )
	if self._name == name then
		return self
	end

	local found = nil
	for i,item in ipairs(self._items) do
		found = item.widget:findWidget( name )
		if found then
			break
		end
	end
	
	return found
end

function mui_listbox:getScrollbar()
	return self._scrollbar.binder.scrollbar
end

function mui_listbox:getScrollIndex()
	return self._scrollIndex
end

function mui_listbox:scrollItems( idx )
	-- TODO: calculate item height dynamically instead of hijacking spcaing
	local item_height = self._item_spacing
	local maxIndex = #self._items - math.floor(self._h / item_height)

	self._scrollIndex = math.max( 0, math.min( maxIndex, idx ))
	if self._scrollbar then
		self._scrollbar.binder.scrollbar:setValue( self._scrollIndex )
	end

	-- This is a little inefficient if we ever have huge numbers in listboxes, but will serve for now.
	-- Ideally, only iterate through the items that we need to.
	for i = 1,#self._items do
		updateItemPosition( self, i )
	end
end

function mui_listbox:onActivate( screen )
	mui_widget.onActivate( self, screen )

	self._scroller:onActivate( screen, self )
	if self._scrollbar then
		updateLayout( self )
	end
end

function mui_listbox:onDeactivate( screen )
	mui_widget.onDeactivate( self, screen )

	self._scroller:onDeactivate( screen )
end

function mui_listbox:updatePriority( priority )
	priority = mui_widget.updatePriority( self, priority )

	priority = self._scroller:updatePriority( priority )

	return priority
end

function mui_listbox:handleEvent( ev )
	if ev.eventType == mui_defs.EVENT_Scroll then
		if ev.delta > 0 then
			self:scrollItems( self._scrollIndex - 1 )
		elseif ev.delta < 0 then
			self:scrollItems( self._scrollIndex + 1 )
		end
	else
		-- find the associated hitbox
		for i,item in ipairs(self._items) do
			if item.hitbox == ev.widget then
				updateItem( item )
				if ev.eventType == mui_defs.EVENT_ButtonClick then
					
					MOAIFmodDesigner.playSound( "SpySociety/HUD/menu/click" )

					if self.onItemClicked then
						util.callDelegate( self.onItemClicked, i, self._items[ i ].user_data )
					end

					self:selectIndex( i )
					return true
				end
				break
			end
		end
	end
end

function mui_listbox:addItem( user_data, noHitbox )
	
	local item = createItem( self, user_data, noHitbox )
	table.insert( self._items, item )

	updateItemPosition( self, #self._items )

	if self:getScreen() then
		self:getScreen():refreshPriority()
	end

	if self._scrollbar then
		local count = self:getMaxVisibleItems()
		if #self._items > count then
			self._scrollbar.binder.scrollbar:setRange( 0, #self._items - count )
			self._scrollbar:setVisible( true )
		else
			self._scrollbar:setVisible( false )
		end
	end
	
	return item.widget
end


function mui_listbox:removeItem( idx )
	
	if idx > 0 and idx <= #self._items then
		local item = self._items[idx]

		if item.isAttached then
			detachItem( self, item )
		end
		table.remove( self._items, idx )
		
		if self._selectedIndex == idx then
			self:selectIndex( nil )
		end
		
		for i = idx,#self._items do
			updateItemPosition( self, i )
		end
	end
end


function mui_listbox:getItem( idx )
	return self._items[ idx ]
end

function mui_listbox:getItemCount()
	return #self._items
end

function mui_listbox:getMaxVisibleItems()
	return math.floor( self._h / self._item_spacing )
end

function mui_listbox:getItems()
	return self._items
end


function mui_listbox:clearItems()

	self:selectIndex( nil )
	self._scrollIndex = 0

	while #self._items > 0 do
		self:removeItem( #self._items ) -- Remove from the tail, to avoid updating positions for all following items.
	end
end


function mui_listbox:selectIndex( idx )
	if idx and (idx < 1 or idx > #self._items) then
		idx = nil
	end

	local old_idx = self._selectedIndex
	local new_idx = idx

	if old_idx ~= new_idx then
		self._selectedIndex = new_idx

		if self.onItemSelected then
			if self._selectedIndex then
				util.callDelegate( self.onItemSelected, old_idx, new_idx, self:getSelectedUserData() )
			else
				util.callDelegate( self.onItemSelected, old_idx, new_idx )
			end
		end
	end
end

function mui_listbox:disableIndex( idx, isDisabled )
	local item = self._items[ idx ]
	if item and item.hitbox then
		item.hitbox:setDisabled( isDisabled )
	end
end

function mui_listbox:getSelectedIndex()
	return self._selectedIndex
end

function mui_listbox:getSelectedUserData()
	if self._selectedIndex and self._items[ self._selectedIndex ] then
		return self._items[ self._selectedIndex ].user_data
	end
	
	return nil
end

function mui_listbox:getSelectedItem( idx )
	if self._selectedIndex and self._items[ self._selectedIndex ] then
		return self._items[ self._selectedIndex ]
	end
	
	return nil
end

function mui_listbox:inside( x, y )
	if self._cont._prop:inside( x, y ) then
		return true
	end
	
	if self._scrollbar:isVisible() then
		if self._scrollbar.binder.scrollbar._cont._prop:inside( x, y ) then
			return true
		end
	end

	return false
end

function mui_listbox:handleTooltip()
	return nil -- listboxes themselves can't have tooltips, let it pass through
end

return mui_listbox
