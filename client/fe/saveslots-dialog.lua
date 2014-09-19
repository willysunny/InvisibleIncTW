----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local mui = include( "mui/mui" )
local util = include( "client_util" )
local array = include( "modules/array" )
local serverdefs = include( "modules/serverdefs" )
local cdefs = include("client_defs")
local strings = include( "strings" )
local metrics = include( "metrics" )
local simparams = include( "sim/simparams" )
local unitdefs = include( "sim/unitdefs" )
local stateMainMenu = include( "states/state-main-menu" )
local serverdefs = include( "modules/serverdefs" )
local version = include( "modules/version" )
local modalDialog = include( "states/state-modal-dialog" )
local simdefs = include( "sim/simdefs" )

----------------------------------------------------------------
-- Local functions

local MAX_SAVE_SLOTS = 4

local STATE_SELECT_SAVE = 1
local STATE_CONTINUE_GAME = 2
local STATE_NEW_GAME = 3


local function checkFirstTimePlaying()
	local user = savefiles.getCurrentGame()

	local firstTime = true
	if user.data.gamesStarted then
		firstTime = false 
	end

	if user.data.top_games ~= nil and #user.data.top_games > 0 then
		firstTime = false
	end

	return firstTime
end

local function canContinueCampaign( campaign )
	if not campaign then
		return false
	end

	if campaign.version == nil or version.isCampaignIncompatible( campaign.version ) then
		local reason = "<ttheader>" .. STRINGS.UI.SAVE_NOT_COMPATIBLE.. "</>\n"
		if campaign.version then
			reason = reason .. string.format( "%s v%s\n", STRINGS.UI.SAVE_GAME_VERSION, campaign.version )
		end
		reason = reason .. string.format( "%s v%s", STRINGS.UI.CURRENT_VERSION, version.CAMPAIGN_VERSION )
		return false, reason
	end

	return true
end

local function continueCampaign( campaign )
	if campaign.situation == nil then
		-- Go to map screen if the campaign currently isn't mid-mission.
		local stateMapScreen = include( "states/state-map-screen" )
		statemgr.deactivate( stateMainMenu )
		statemgr.activate( stateMapScreen, campaign )

	elseif campaign.sim_history == nil then
		local stateCorpPreview = include( "states/state-corp-preview" )
		statemgr.deactivate( stateMainMenu )
		statemgr.activate( stateCorpPreview, campaign )

	else
		local stateLoading = include( "states/state-loading" )

		statemgr.deactivate( stateMainMenu )
		stateLoading:loadCampaign( campaign )
	end
end

local function onClickCancel( dialog )
	dialog:hide()
end

local function onSaveSlotClicked( dialog, idx, campaign )
	-- Update currently selected save slot.
	local user = savefiles.getCurrentGame()
	user.data.currentSaveSlot = idx

	if campaign == nil then
		dialog:showState( STATE_NEW_GAME )
	
	else
		dialog:showState( STATE_CONTINUE_GAME, campaign )
	end
end

local function onClickContinue( dialog )
	local user = savefiles.getCurrentGame()
	local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]
	local canContinue, reason = canContinueCampaign( campaign )
	assert( canContinue )

	if campaign.sim_history ~= nil and version.isSimIncompatible( campaign.sim_version ) then
		local result = modalDialog.showUpdateDisclaimer( STRINGS.UI.SAVESLOTS.CONTINUE, STRINGS.UI.SAVESLOTS.SEE_PATCHNOTES )
		if result == modalDialog.AUX then
			MOAISim.visitURL( config.PATCHNOTES_URL )
			return

		elseif result == modalDialog.OK then
			campaign.sim_history = nil
			campaign.situation = nil
			campaign.gameDifficulty = simdefs.HARD_DIFFICULTY
		else
			return
		end
	end

	if canContinue then
		dialog:hide()
		continueCampaign( campaign )
		metrics.app_metrics:incStat( "continued_games" )
	end
end

local function onClickDelete( dialog )
	local modalDialog = include( "states/state-modal-dialog" )
	local result = modalDialog.showYesNo( STRINGS.UI.SAVESLOTS.DELETE_AREYOUSURE, STRINGS.UI.SAVESLOTS.DELETE_SAVE, nil, STRINGS.UI.SAVESLOTS.DELETE_SAVE )
	if result == modalDialog.OK then
		local user = savefiles.getCurrentGame()
		user.data.saveSlots[ user.data.currentSaveSlot ] = nil
		user.data.currentSaveSlot = nil
		user:save()
		
		dialog:populateSaveSlots()
		dialog:showState( STATE_SELECT_SAVE )
	end
end

local function onClickCancelContinue( dialog )
	dialog:showState( STATE_SELECT_SAVE )
end

local function launchGame(dialog)

	local user = savefiles.getCurrentGame()
	user.data.gamesStarted= true
	user:save()

	dialog:hide()
	statemgr.deactivate( stateMainMenu )
	local stateTeamPreview = include( "states/state-team-preview" )
	statemgr.activate( stateTeamPreview )
end

local function launchTutorial(dialog)
	dialog:hide()
	local campaign = serverdefs.createNewCampaign( serverdefs.createTutorialAgency(), true )

	local user = savefiles.getCurrentGame()
	user.data.campaign = campaign
	user.data.num_campaigns = (user.data.num_campaigns or 0) + 1
	user.data.gamesStarted= true
	user.data.noGamesStarted= true
	user:save()

	local stateCorpPreview = include( "states/state-corp-preview" )
	statemgr.deactivate( stateMainMenu )
	statemgr.activate( stateCorpPreview, campaign )
end

local function onClickStory( dialog )
	
	if checkFirstTimePlaying() then 
		
		local modalDialog = include( "states/state-modal-dialog" )
		local result = modalDialog.showYesNo( STRINGS.UI.SAVESLOTS.PLAYED_TUTORIAL, STRINGS.UI.SAVESLOTS.PLAY_TUTORIAL, nil, STRINGS.UI.SAVESLOTS.PLAY_TUTORIAL, STRINGS.UI.SAVESLOTS.PLAY_STORY )
		if result == modalDialog.OK then
			launchTutorial(dialog)
		elseif 	result == modalDialog.CANCEL then
			launchGame(dialog)
		end		
	else
		launchGame(dialog)
	end
end

local function onClickEndless( dialog )
	dialog:hide()
	statemgr.deactivate( stateMainMenu )
	local stateTeamPreview = include( "states/state-team-preview" )
	statemgr.activate( stateTeamPreview, true )
end

local function onClickTutorial( dialog )
	launchTutorial(dialog)
end

local function onClickCancelNewGame( dialog )
	dialog:showState( STATE_SELECT_SAVE )
end


----------------------------------------------------------------
-- Interface functions

local dialog = class()

function dialog:init(game)
	local screen = mui.createScreen( "modal-saveslots.lua" )
	self._screen = screen

	local user = savefiles.getCurrentGame()
	
	screen.binder.cancelBtn.binder.btn.onClick = util.makeDelegate( nil, onClickCancel, self )
	screen.binder.cancelBtn.binder.btn:setText( STRINGS.UI.BUTTON_CANCEL )

	screen.binder.listbox.onItemClicked = util.makeDelegate( nil, onSaveSlotClicked, self )

	screen.binder.storyBtn.onClick = util.makeDelegate( nil, onClickStory, self )
	screen.binder.tutorialBtn.onClick = util.makeDelegate( nil, onClickTutorial, self )
	screen.binder.endlessBtn.onClick = util.makeDelegate( nil, onClickEndless, self )
	screen.binder.endlessBtn:setDisabled( (user.data.storyWins or 0) <= 0 )
	screen.binder.cancelGameBtn.onClick = util.makeDelegate( nil, onClickCancelNewGame, self )

	screen.binder.continueBtn.onClick = util.makeDelegate( nil, onClickContinue, self )
	screen.binder.deleteBtn.onClick = util.makeDelegate( nil, onClickDelete, self )
	screen.binder.cancelContinueBtn.onClick = util.makeDelegate( nil, onClickCancelContinue, self )

	self:showState( STATE_SELECT_SAVE )
end

function dialog:showState( state, campaign )

	self._screen.binder.newGame:setVisible( state == STATE_NEW_GAME )
	self._screen.binder.continueGame:setVisible( state == STATE_CONTINUE_GAME )
	self._screen.binder.cover:setVisible( state ~= STATE_SELECT_SAVE )
	self._screen.binder.optionsBG:setVisible( state ~= STATE_SELECT_SAVE )

	if state == STATE_NEW_GAME then
		self._screen.binder.newGame:createTransition("activate_left")
		self._screen.binder.optionsBG:createTransition("activate_left")
	elseif state == STATE_CONTINUE_GAME then
		self._screen.binder.continueGame:createTransition("activate_left")
		self._screen.binder.optionsBG:createTransition("activate_left")
		self._screen.binder.continueBtn:setDisabled( not canContinueCampaign( campaign ))
	end

end

function dialog:show()
	mui.activateScreen( self._screen )

	self:populateSaveSlots()
end

function dialog:populateSaveSlots()
	local listbox = self._screen.binder.listbox

	listbox:clearItems()

	local user = savefiles.getCurrentGame()
	-- for backwards compatability
	if user.data.saveSlots == nil then
		user.data.saveSlots = { user.data.campaign }
	end

	for i = 1, MAX_SAVE_SLOTS do
		local campaign = user.data.saveSlots[i]
		local widget = listbox:addItem( campaign )
		local txt = nil

		if campaign then

			for i, portrait in widget.binder:forEach("img") do
				local unitDef = campaign.agency.unitDefs[i]
				if unitDef then
					local template = unitdefs.lookupTemplate( unitDef.template )
					portrait:setImage( template.profile_icon_64x64 )
				else
					portrait:setVisible(false)
				end
			end

			if campaign.gameDifficulty == nil or campaign.gameDifficulty == simdefs.HARD_DIFFICULTY then 
				txt = string.format("<font1_16_sb>%s %s</>", STRINGS.UI.HARD_DIFFICULTY, STRINGS.UI.DIFFICULTY_STR )
			else 
				txt = string.format("<font1_16_sb>%s %s</>", STRINGS.UI.NORMAL_DIFFICULTY, STRINGS.UI.DIFFICULTY_STR )
			end

			if campaign.endless then
				txt = txt .. "\n<font1_16_sb>"..STRINGS.UI.SAVESLOTS.ENDLESS_MODE.."</>"
			else
				txt = txt .. "\n<font1_16_sb>"..STRINGS.UI.SAVESLOTS.STORY_MODE.."</>"
			end

			local canContinue, reason = canContinueCampaign( campaign )
			if not canContinue then
				txt = txt .. "\n" .. reason
			else
				if campaign.situation and campaign.situation.name == serverdefs.TUTORIAL_SITUATION then
					txt = txt .. "\n"..STRINGS.UI.SAVESLOTS.TUTORIAL
				else
					local hours = serverdefs.calculateCurrentHours(campaign)
					txt = txt .. "\n"..string.format( STRINGS.UI.SAVESLOTS.DAYS_SPENT, math.floor(hours / 24) + 1, hours % 24 )
				end
			end
		else
			for i, portrait in widget.binder:forEach("img") do
				portrait:setVisible(false)
			end
			txt = STRINGS.UI.SAVESLOTS.EMPTY_SLOT
		end

		widget.binder.txt:setText( txt )
	end
end


function dialog:hide()
	if self._screen:isActive() then
		mui.deactivateScreen( self._screen )
	end
end

return dialog
