----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

require 'class'

StateGraph = class('StateGraph')
function StateGraph:init()
	self._states = {}
end

function StateGraph:addState( stateEnum, stateData, onEnter, onExit )
	assert( self._states ~= nil, "not initialized" )
	assert( self._states[stateEnum] == nil, "state " .. tostring(stateEnum) .. " already exists" )
	assert( onEnter == nil or type(onEnter) == "function" )
	assert( onExit == nil or type(onExit) == "function" )

	self._states[stateEnum] = { _stateEnum = stateEnum, _stateData = stateData, _onEnter = onEnter, _onExit = onExit, _transitions = {} }
end

function StateGraph:addTransition( fromState, toState, func )
	assert( self._states ~= nil, "not initialized")
	assert( self._states[fromState] ~= nil, "fromState " .. tostring(fromState) .. " not found" )
	assert( self._states[toState] ~= nil, "toState " .. tostring(toState) .. " not found" )
	assert( self._states[fromState]._transitions[toState] == nil, "fromState " .. tostring(fromState) .. " already has a transition to state " .. tostring(toState) )
	assert( func == nil or type(func) == "function", "function must be of 'function' type or nil" )
	self._states[fromState]._transitions[toState] = func or true
end

function StateGraph:transition( newState, ... )
	assert( self._states, "not initilized" )
	assert( self._currentState ~= nil, "attempting to transition from a nil state" )
	assert( self._states[newState] ~= nil, "attempting to transition from " .. tostring(self._currentState) .. " to state " .. tostring(newState) .. " but there is no state entry" )
	assert( self._states[self._currentState]._transitions[newState] ~= nil, "attempting to transition from " .. tostring(self._currentState) .. " to state " .. tostring(newState) .. " but there is no transition entry" )

	--print("StateGraph:transition( " .. tostring(self._currentState) .." -> " .. tostring(newState) .. " )" )

	if newState ~= self._transitState then
		assert( self._transitState == nil )
		self._transitState = newState

		local currentState = self._states[self._currentState]
		local nextState = self._states[newState]
		local transition = currentState._transitions[newState]

		if type(currentState._onExit) == "function" then
			currentState._onExit( ... )
		end
		if type(transition) == "function" then
			transition( currentState, nextState, ... )
		end
		if type(nextState._onEnter) == "function" then
			nextState._onEnter( ... )
		end

		self._currentState = newState
		self._transitState = nil
	end
end

function StateGraph:getCurrentStateEnum()
	return self._currentState
end

function StateGraph:getCurrentState()
	assert( self._states ~= nil, "not initialized" )
	assert( self._currentState ~= nil, "current state is nil" )
	return self._states[self._currentState]
end

function StateGraph:getCurrentStateData()
	assert( self._states ~= nil, "not initialized" )
	assert( self._currentState ~= nil, "current state is nil" )
	return self._states[self._currentState]._stateData
end

function StateGraph:setCurrentState( state )
	assert( self._states ~= nil, "not initialized" )
	assert( self._currentState == nil, "current state is not nil" )
	assert( self._states[state] ~= nil, "state is not found" )
	self._currentState = state
end