----------------------------------------------------------------
-- Copyright (c) 2013 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

require("class")

local Mix = class()

function Mix:init( name, fadetime, priority, categoryVolumes )
	self._name = name
	self._fadetime = fadetime or 1
	self._priority = priority or 0
	self._categoryVolumes = {}
	for category,volume in pairs( categoryVolumes or {} ) do
		self._categoryVolumes[ category ] = volume
	end
end

function Mix:destroy()
end

function Mix:apply()
	for category,volume in pairs( self._categoryVolumes ) do
		MOAIFmodDesigner.setCategoryVolume( category, volume )
	end
end

function Mix:setCategoryVolume( category, volume )
	self._categoryVolumes[ category ] = volume
end

function Mix:getCategoryVolume( category )
	return self._categoryVolumes[ category ] or 0
end

----------------------------------------------------------------

local Mixer = class()

function Mixer:init()
	self._mixes = {}
	self._stack = {}
	self._updateThread = MOAICoroutine.new()
	self._updateThread:run( function() while true do self:update() coroutine.yield() end end )
	
end

function Mixer:destroy()
	self._updateThread:stop()
end

function Mixer:addMix( name, fadetime, priority, categoryVolumes )
	self._mixes[ name ] = Mix( name, fadetime, priority, categoryVolumes )
end

function Mixer:getMixes()
	return self._stack
end

function Mixer:pushMix( name )
	local mix = self._mixes[ name ]
	if mix then
		local top = self._stack[1]

		table.insert( self._stack, mix )
		table.sort( self._stack, function(l,r) return l._priority > r._priority end )

		if top and top ~= self._stack[1] then
			self:blend()
		elseif not top then
			mix:apply()
		end
	end
end

function Mixer:popMix( name )
	local top = self._stack[1]
	for i,mix in ipairs( self._stack ) do
		if name == mix._name then
			table.remove( self._stack, i )
			if top ~= self._stack[1] then
				self:blend()
			end
			break;
		end
	end
end

function Mixer:blend()
	self._snapshot = self:createSnapshot()
	self._fadetimer = 0
end

function Mixer:createSnapshot()
	local top = self._stack[1]
	if top then
		local snapshot = Mix()
		for category,volume in pairs( top._categoryVolumes ) do
			snapshot:setCategoryVolume( category, MOAIFmodDesigner.getCategoryVolume( category ) )
		end
		return snapshot
	end
end

function Mixer:update()
	local top = self._stack[1]
	if self._snapshot and top then
		self._fadetimer = self._fadetimer + 1/60
		local lerp = self._fadetimer / top._fadetime
		if lerp >= 1 then
			self._snapshot = nil
			top:apply()
		else
			for category,volume in pairs(self._snapshot._categoryVolumes) do
				local target_volume = top:getCategoryVolume( category )
				local eased_volume = volume * (1 - lerp) + target_volume * lerp
				MOAIFmodDesigner.setCategoryVolume( category, eased_volume )
			end
		end
	end
end

return Mixer