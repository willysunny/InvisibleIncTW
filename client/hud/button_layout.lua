----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local mathutil = include( "modules/mathutil" )
local array = include( "modules/array" )
local mui = include("mui/mui")
local mui_defs = include( "mui/mui_defs")
local cdefs = include( "client_defs" )

--------------------------------------------------------------------------------------
-- Dynamically arranges things according to some vague sense of aesthetic sensibility.

local function updateTensionForce( fx, fy, x0, y0, x1, y1 )
	local d = mathutil.dist2d( x0, y0, x1, y1 )
	local dx, dy = x1 - x0, y1 - y0
	local k = -10000
	fx, fy = fx + k * dx, fy + k * dy
	return fx, fy
end

local function updateGravForce( fx, fy, i )
	return fx + 0, fy + 20
end


local function updateFriction( fx, fy, vx, vy )
	local k = -1
	local dfx, dfy = k * vx, k * vy
	return fx + dfx, fy + dfy
end

local function updateConstantForce( fx, fy, x0, y0, x1, y1, mag )
	local d = mathutil.dist2d( x0, y0, x1, y1 )
	local dx, dy = x1 - x0, y1 - y0
	if d <= 1 then
		mag = 0
	else
		mag = mag
		dx, dy = dx / d, dy / d
	end
	
	fx, fy = fx + mag * dx, fy + mag * dy
	return fx, fy
end

local function updateForce( fx, fy, x0, y0, x1, y1, mag )
	local d = mathutil.dist2d( x0, y0, x1, y1 )
	local dx, dy = x1 - x0, y1 - y0
	mag = mag or 0.1
	if d <= 1 then
		mag = 0
	elseif d >= 200 then
		mag = 0
	else
		mag = mag / (d * d * 0.01) -- inverse sqr mag.
		dx, dy = dx / d, dy / d
	end
	
	fx, fy = fx + mag * dx, fy + mag * dy
	return fx, fy
end

local function doPass( cx, cy, layout ) -- start, pos, dpos, ddpos )
	for w, l in pairs(layout) do
		-- Get the force on this widget.
		local fx, fy = 0, 0
		local x0, y0 = l.startx, l.starty
		local x1, y1 = l.posx, l.posy
		fx, fy = updateFriction( fx, fy, l.dposx, l.dposy )
		fx, fy = updateConstantForce( fx, fy, cx, cy, x1, y1, 1000 )
		--fx, fy = updateGravForce( fx, fy, (i-1)/2 )
--		fx, fy = updateTensionForce( fx, fy, x0, y0, x1, y1 )
		for w2, ll in pairs(layout) do
			if w2 ~= w then
				local x0, y0 = ll.posx, ll.posy
				fx, fy = updateForce( fx, fy, x0, y0, x1, y1, 1000 )
			end
		end
		l.fx, l.fy = fx, fy
	end
	
	-- Apply forces
	local total_d = 0
	local DT = 1 / 40
	for w, l in pairs(layout) do
		local fx, fy = l.fx, l.fy
		-- A.
		l.ddposx, l.ddposy = fx / 2, fy / 2
		local ax0, ay0 = l.ddposx, l.ddposy
		-- V.
		l.dposx, l.dposy = l.dposx + ax0 * DT, l.dposy + ay0 * DT
		local vx0, vy0 = l.dposx, l.dposy
		-- Pos
		local x0, y0 = l.posx, l.posy
		local x1, y1 = x0 + vx0 * DT, y0 + vy0 * DT
		l.posx, l.posy = x1, y1
	
		total_d = total_d + mathutil.dist2d( x0, y0, x1, y1 )
	end

	return total_d
end


local button_layout = class()

function button_layout:init( originx, originy )
	self._originx, self._originy = originx, originy
	self._layout = {}
end

function button_layout:destroy( screen )
	for layoutID, layout in pairs( self._layout ) do
		screen:removeWidget( layout.leaderWidget )
	end
	self._layout = nil
end

function button_layout:calculateLayout( screen, game, widgets )
	for i, widget in ipairs( widgets ) do
		if widget.worldx then
			local wx, wy = game:worldToWnd( widget.worldx, widget.worldy, widget.worldz )
			local layoutID = widget.layoutID or widget
			local layout = self._layout[ layoutID ]
			if layout == nil then
				local leaderWidget = screen:createFromSkin( "LineLeader" )
				screen:addWidget( leaderWidget )
				leaderWidget.binder.line:appear( 0.5 )

				layout =
					{
						widgets = { widget },
						leaderWidget = leaderWidget
					}
				self._layout[ layoutID ] = layout
			end

			local idx = array.find( layout.widgets, widget )
			if idx == nil then
				table.insert( layout.widgets, widget )
			elseif idx == 1 then
				layout.startx = wx
				layout.starty = wy
				layout.posx = wx + 10 * math.cos( i )
				layout.posy = wy + 10 * math.sin( i )
				layout.dposx = 0
				layout.dposy = 0
				layout.ddposx = 0
				layout.ddposy = 0
			end
		end
	end

	local total_d = 100
	local iters = 0
	local cx, cy = game:worldToWnd( self._originx, self._originy )
	while total_d > 0.01 and iters < 20 do
		total_d = doPass( cx, cy, self._layout )
		iters = iters + 1
	end
end

function button_layout:setPosition( widget )
	local layoutID = widget.layoutID or widget
	local layout = self._layout[ layoutID ]
	if layout ~= nil then
		local W, H = widget:getScreen():getResolution()
		local OFFSET_X, OFFSET_Y = (40/W), (22/H)
		local x, y = widget:getScreen():wndToUI( layout.posx, layout.posy )
		local startx, starty = widget:getScreen():wndToUI( layout.startx, layout.starty )
		local idx = util.indexOf( layout.widgets, widget )
		x = x + (idx - 1) * OFFSET_X
		widget:setPosition( x, y )
		if idx == 1 then
			layout.leaderWidget:setPosition( startx, starty )
			local x0, y0 = x - OFFSET_X/2 - startx, y - starty
			local x1, y1 = x + OFFSET_X * #layout.widgets - startx - OFFSET_X/2, y - starty
			if y > starty then
				y0, y1 = y0 - OFFSET_Y, y1 - OFFSET_Y
			else
				y0, y1 = y0 + OFFSET_Y, y1 + OFFSET_Y
			end
			if math.abs( x0 ) < math.abs( x1 ) then
				layout.leaderWidget.binder.line:setTarget( x0, y0, x1, y1 )
			else
				layout.leaderWidget.binder.line:setTarget( x1, y1, x0, y0 )
			end
		end
		return true
	end
end


return button_layout


