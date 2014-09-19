----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local util = include( "client_util" )
local resources = include( "resources")
local animmgr = include("anim-manager")
local gameobj = include( "modules/game" )
local modalDialog = include("states/state-modal-dialog")
local simparams = include( "sim/simparams" )
local cdefs = include( "client_defs" )

----------------------------------------------------------------

local loading = {}

----------------------------------------------------------------

local function runUnloadThread( nextState, ... )
	util.timeYield() -- Ensure busy dialog appears immediately.

	KLEIResourceMgr.ClearResources()

	MOAIFmodDesigner.playSound("SpySociety/AMB/office", "AMB1")
	MOAIFmodDesigner.setVolume( "AMB1", 0 )	
	MOAIFmodDesigner.playSound("SpySociety/AMB/mainframe", "AMB2")
	MOAIFmodDesigner.setVolume( "AMB2", 0 )	

	statemgr.activate( nextState, ... )
end

local function runLoadThread( params, stateGame, campaign, simHistoryIdx )
	util.timeYield() -- Ensure busy dialog appears immediately.

	local sim_history = nil
	local uiMemento = nil
	local simCore, levelData = gameobj.constructSim( params )
	if campaign and campaign.sim_history then
		local serializer = include( "modules/serialize" )
		sim_history = campaign.sim_history and serializer.deserialize( campaign.sim_history )
		uiMemento = campaign.uiMemento
		simHistoryIdx = simHistoryIdx or #sim_history
		local simguard = include( "modules/simguard" )
		local st = os.clock()
		simguard.start()
		for i = 1, simHistoryIdx do
			local action = sim_history[i]
			simCore:applyAction( action )
		end
		simguard.finish()
		log:write( "\tAdvanced %d/%d sim actions (Took %.2f ms).", simHistoryIdx, #sim_history, (os.clock() - st) * 1000 )
	end

	MOAIFmodDesigner.playSound("SpySociety/AMB/office", "AMB1")
	MOAIFmodDesigner.setVolume( "AMB1", 0 )	
	MOAIFmodDesigner.playSound("SpySociety/AMB/mainframe", "AMB2")
	MOAIFmodDesigner.setVolume( "AMB2", 0 )	
	FMODMixer:popMix( "nomusic" ) -- Matches to the pushMix in playMusic().

	statemgr.activate( stateGame, nil, params, simCore, levelData, sim_history, simHistoryIdx, uiMemento )
end

local function onLoadError( self, result )
	moai.traceback( "Loading traceback:\n".. tostring(result), self.loadThread )

	local simguard = include( "modules/simguard" )
	simguard.finish()
	statemgr.deactivate( self )
	local stateMainMenu = include( "states/state-main-menu" )
	statemgr.activate( stateMainMenu )
	util.coDelegate(
		function()
			local errMsg = util.formatGameInfo() .. "\n" .. tostring(result)
			modalDialog.show( errMsg, "Loading Error" )
		end )
end

local function onLoadCampaignError( campaign, self, result )
	local errMsg = util.formatGameInfo() .. "\n" .. tostring(result)
	moai.traceback( "Loading traceback:\n".. errMsg, self.loadThread )

	local simguard = include( "modules/simguard" )
	simguard.finish()
	statemgr.deactivate( self )

	util.coDelegate(
		function()
			local body = string.format( "There was an error loading: %s\nDo you want to try loading from the start of the level?", result )
			local result = modalDialog.showYesNo( body, "Loading Error", "Try A Different Level" )
			if result == modalDialog.OK then
				self:loadCampaign( campaign, 1 )
			elseif result == modalDialog.AUX then
				local user = savefiles.getCurrentGame()
				local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]
				if campaign then
					campaign.seed = campaign.seed + 1
					campaign.uiMemento = nil
					campaign.sim_history = nil
					log:write( "Load failure: user opted to try new seed (now %u)", campaign.seed )
					user:save()
				end
				self:loadCampaign( campaign )
			else
				local stateMainMenu = include( "states/state-main-menu" )
				statemgr.activate( stateMainMenu )
			end
		end )
end

local function playMusic( params )
	MOAIFmodDesigner.stopSound("theme")
	FMODMixer:popMix("frontend")

	MOAIFmodDesigner.startMusic( params.music )
	MOAIFmodDesigner.setMusicProperty("intensity",0)
	MOAIFmodDesigner.setMusicProperty("mode",0)
	MOAIFmodDesigner.setMusicProperty("proximity",0)
	-- Not the best, but this lets mission script control when exactly the music comes in.
	FMODMixer:pushMix( "nomusic" )
end

----------------------------------------------------------------

loading.loadCampaign = function( self, campaign, simHistoryIdx )
	local params = simparams.createCampaign( campaign )

	playMusic( params )

	MOAIFmodDesigner.playSound( "SpySociety/Music/stinger_start" )

	self.errorFn = util.makeDelegate( nil, onLoadCampaignError, campaign )

	log:write( "### CAMPAIGN [ %s, mission %u, %u hrs ]\n### PARAMS: [ %s, seed = %u, difficulty = %u]",
		campaign.situation.name, campaign.missionCount, campaign.hours, params.world, params.seed, params.difficulty )

	local stateCampaignGame = include( "states/state-campaigngame" )
	statemgr.activate( loading, runLoadThread, params, stateCampaignGame, campaign, simHistoryIdx )
end

loading.loadLocalGame = function( self, params )

	playMusic( params )

	MOAIFmodDesigner.playSound( "SpySociety/Music/stinger_start" )

	log:write( "### LOCAL GAME PARAMS: [ %s, seed = %u ]",
		params.levelFile, params.seed )

	local stateGame = include( "states/state-localgame" )
	statemgr.activate( loading, runLoadThread, params, stateGame, nil, nil )
end

loading.loadFrontEnd = function( self )
	local stateMainMenu = include( "states/state-main-menu" )
	statemgr.activate( loading, runUnloadThread, stateMainMenu )
end

loading.loadUpgradeScreen = function( self, agency )
	local stateUpgradeScreen = include( "states/state-upgrade-screen" )
	statemgr.activate( loading, runUnloadThread, stateUpgradeScreen, agency )
end

loading.loadMapScreen = function( self, campaign )
	local stateMapScreen = include( "states/state-map-screen" )
	assert( campaign )
	statemgr.activate( loading, runUnloadThread, stateMapScreen, campaign )
end

----------------------------------------------------------------
loading.onLoad = function ( self, fn, ... )

	self.startTime = os.clock()

	self.loadThread = coroutine.create( fn )
	self.loadParams = { ... }
end

----------------------------------------------------------------
loading.onUnload = function ( self )
	self.loadThread = nil
	self.errorFn = nil

	util.fullGC()
	log:write( "## Load screen took: %.1f ms", 1000 * (os.clock() - self.startTime) )
end

loading.onUpdate = function( self )
	local ok, result = coroutine.resume( self.loadThread, unpack(self.loadParams) )
	if not ok then
		util.callDelegate( self.errorFn or onLoadError, self, result )

	elseif coroutine.status( self.loadThread ) == "dead" then
		statemgr.deactivate( self )
	end
end

return loading
