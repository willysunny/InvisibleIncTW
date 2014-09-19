----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "modules/util" )
local array = include( "modules/array" )
local basegame = include( "states/state-game" )
local localgame = util.tcopy(basegame)
local gameobj = include( "modules/game" )
local serializer = include('modules/serialize')
local serverdefs = include( "modules/serverdefs" )
local mui = include("mui/mui")
local mui_defs = include("mui/mui_defs")
local metrics = include( "metrics" )
local mission_complete = include( "hud/mission_complete" )

----------------------------------------------------------------
--

localgame.getCamera = function( self )
	if self.cameraHandler == nil then
		local camhandler = include( "gameplay/camhandler" )
		self.cameraHandler = camhandler( self.layers["main"], self )
	end

	return self.cameraHandler
end

localgame.quitToMainMenu = function( self )
	local playTime = os.time() - self.onLoadTime
	metrics.level_finished():send( self, playTime )

	statemgr.deactivate( self )
	local stateLoading = include( "states/state-loading" )
	stateLoading:loadFrontEnd()
end

localgame.onLoad = function( self, ... )
	basegame.onLoad( self, ... )

	if util.tempty( self.simHistory ) then
		local playerData = self.players[ self.playerIndex ]
		self:doAction( "reserveAction", playerData.agency.unitDefs, playerData.agency.unitDefsPotential, playerData.agency.abilities )
	end
end

localgame.onUpdate = function( self )
	basegame.onUpdate( self )

	if self.simCore:isGameOver() then
		self:quitToMainMenu()
	end
end

----------------------------------------------------------------

return localgame
