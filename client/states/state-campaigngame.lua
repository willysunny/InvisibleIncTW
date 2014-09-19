----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "modules/util" )
local array = include( "modules/array" )
local basegame = include( "states/state-game" )
local campaigngame = util.tcopy(basegame)
local gameobj = include( "modules/game" )
local serializer = include('modules/serialize')
local serverdefs = include( "modules/serverdefs" )
local mission_complete = include( "hud/mission_complete" )
local death_dialog = include( "hud/death_dialog" )
local mui = include("mui/mui")
local mui_defs = include("mui/mui_defs")
local metrics = include( "metrics" )

----------------------------------------------------------------
--

campaigngame.getCamera = function( self )
	if self.cameraHandler == nil then
		local camhandler = include( "gameplay/camhandler" )
		self.cameraHandler = camhandler( self.layers["main"], self )
	end

	return self.cameraHandler
end

campaigngame.saveCampaign = function( self )
	-- Save the current campaign game progress, if the game isn't over, and this isn't a 'debug' level.
	if self.params.campaignHours ~= nil then
		local user = savefiles.getCurrentGame()

		if not self.simCore:isGameOver() then
			local selectedUnit = self.hud:getSelectedUnit()
			local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]
			local playTime = os.time() - self.onLoadTime
			local res, err = pcall(
				function()
					campaign.sim_history = serializer.serialize( self.simHistory )
					campaign.play_t = campaign.play_t + playTime
					campaign.recent_build_number = "r" .. tostring(MOAIEnvironment.Build_Version)
					campaign.uiMemento =
						{
							cameraState = self:getCamera():getMemento(),
							selectedUnitID = selectedUnit and selectedUnit:getID()
						}
					user:save()
				end )
			if not res then
				log:write( "Failed to save slot %s:\n%s", tostring(user.data.currentSaveSlot), err )
			end
		end
	end
end

campaigngame.quitToMainMenu = function( self )
	local stateLoading = include( "states/state-loading" )

	self:saveCampaign()

	statemgr.deactivate( self )
	stateLoading:loadFrontEnd()
end

campaigngame.onLoad = function( self, ... )
	basegame.onLoad( self, ... )

	if util.tempty( self.simHistory ) then
		local playerData = self.players[ self.playerIndex ]
		self:doAction( "reserveAction", playerData.agency.unitDefs, playerData.agency.unitDefsPotential, playerData.agency.abilities )
	end
	self._rewardsDialog = nil 
end

campaigngame.doAction = function( self, ... )
    basegame.doAction( self, ... )

    if not config.DEV then
    	self:saveCampaign()
    end
end

campaigngame.onUpdate = function( self )
	basegame.onUpdate( self )

	if self.simCore:isGameOver() and not self.simCore:getTags().delayPostGame then
		if not self._rewardsDialog then
			local user = savefiles.getCurrentGame()
			local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]
			local campaignPlayTime = campaign.play_t or 0

			if self.simCore:getWinner() == nil then
				self._rewardsDialog = death_dialog()
				self._rewardsDialog:show( self, self.simCore )
			else 
				self._rewardsDialog = mission_complete()
				self._rewardsDialog:show( self, self.simCore )
			end 

			-- Send metrics after rewards dialog, as it calculates end-of-level bonuses.
			local playTime = os.time() - self.onLoadTime + campaignPlayTime
			metrics.level_finished():send( self, playTime )
		end
	end
end

----------------------------------------------------------------

return campaigngame
