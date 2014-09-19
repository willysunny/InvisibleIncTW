----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

module ( "savefiles", package.seeall )

----------------------------------------------------------------
----------------------------------------------------------------
-- variables
----------------------------------------------------------------
local files = { [KLEIPersistentStorage.PST_SaveGame] = {}, [KLEIPersistentStorage.PST_Settings] = {} }
local saveFiles = {}
local currentSaveFile = nil
local settingsFile = nil

----------------------------------------------------------------
-- local functions
----------------------------------------------------------------
local function makeFile ( type, filename )

	local savefile = {}
	
	savefile.filename = filename
	savefile.fileexist = false
	savefile.data = nil
	savefile.type = type
	
	----------------------------------------------------------------
	function savefile:load()
		local save = KLEIPersistentStorage.loadFile( self.type, self.filename )
		if save then
			local fn, err = loadstring(save)
			if fn then
				self.data = fn()
				self.fileexist = true
			else
				log:write( "savefile.load( %s ) failed with err:\n%s", self.filename, err )
			end
		end

		if not self.data then
			self.data = {}
			self.fileexist = false
		end
		
		setmetatable( self,
			{
				__newindex = function( t, k, v )
					assert(false, "Use the data sub-table to store actual save data for key '"..tostring(k).."'") 
				end
			} )

		return self.fileexist
	end
	
	----------------------------------------------------------------
	function savefile:save()
		local serializer = MOAISerializer.new ()

		self.fileexist = true
		serializer:serialize ( self.data )
		local gamestateStr = serializer:exportToString ()

		KLEIPersistentStorage.saveFile( self.type, self.filename, gamestateStr )
	end

	return savefile
end

----------------------------------------------------------------
-- exposed functions
----------------------------------------------------------------

function getFile ( type, filename )
	if not files[type][filename] then
		files[type][filename] = makeFile( type, filename .. ".lua" )
		files[type][filename]:load()
	end
	return files[type][filename]
end

function getGame ( filename )
	return getFile( KLEIPersistentStorage.PST_SaveGame, filename )
end

function getCurrentGame()
	return currentSaveFile
end

function makeCurrentGame( filename )

	local savefile = getGame( filename )
	if savefile.fileexist then
		currentSaveFile = savefile
	end

	return currentSaveFile
end

function getSettings( filename )
	return getFile( KLEIPersistentStorage.PST_Settings, filename )
end

------------------------------------------------------------------------------
-- Save game helpers.

MAX_TOP_GAMES = 6

-- Initializes default savegame data.
function initSaveGame()
	if not makeCurrentGame( "savegame" ) then
		local user = savefiles.getGame( "savegame" )
		user.data.name = "default"
		user.data.top_games = {}
		user.data.num_games = 0
		user.data.saveSlots = {}
		user.data.xp = 0

		user:save()

		makeCurrentGame( "savegame" )
	end
end

local function compareCampaigns( campaign1, campaign2 )
	-- Should be based on some score factor?
	if campaign1.hours == campaign2.hours then
		return campaign1.agency.cash > campaign2.agency.cash
	else
		return (campaign1.hours or 0) > (campaign2.hours or 0)
	end
end

-- Adds the current campaign to the list of completed games, then clears the current campaign.
function addCompletedGame( result )
	local metadefs = include( "sim/metadefs" )
	local user = getCurrentGame()
	assert( user and user.data.currentSaveSlot )
	local campaign = user.data.saveSlots[ user.data.currentSaveSlot ]

	-- Add xpgain
	local xpgained = 0
	xpgained = xpgained + campaign.agency.security_hacked * metadefs.XP_PER_SMALL_ACTION
	xpgained = xpgained + campaign.agency.guards_kod * metadefs.XP_PER_SMALL_ACTION
	xpgained = xpgained + campaign.agency.safes_looted * metadefs.XP_PER_BIG_ACTION
	xpgained = xpgained + campaign.agency.credits_earned * 1
	xpgained = xpgained + campaign.agency.programs_earned * metadefs.XP_PER_BIG_ACTION
	xpgained = xpgained + campaign.agency.items_earned * metadefs.XP_PER_SMALL_ACTION
	xpgained = xpgained + campaign.agency.missions_completed * metadefs.XP_PER_MISSION

	local oldXp = (user.data.xp or 0)
	user.data.xp = math.min( metadefs.GetXPCap(), oldXp + xpgained )

	-- See if fits within the top scores.
	campaign.complete_time = os.time()
	campaign.result = result
	table.insert( user.data.top_games, campaign )

	if not user.data.lastGames then 
		user.data.lastGames = {}
	end

	table.insert( user.data.lastGames, 1, campaign.hours )

	while #user.data.lastGames > 50 do 
		table.remove(user.data.lastGames, 51) 
	end

	local totalDepth = 0;
	local totalGames = 0; 

	for i,depth in ipairs(user.data.lastGames) do 
		totalGames = totalGames + 1 
		totalDepth = totalDepth + depth
	end

	user.data.avgDepth = totalDepth / totalGames
	if result == "VICTORY" then
		user.data.storyWins = (user.data.storyWins or 0) + 1
	end

	table.sort( user.data.top_games, compareCampaigns )
	while #user.data.top_games > MAX_TOP_GAMES do
		table.remove( user.data.top_games )
	end

	user.data.saveSlots[ user.data.currentSaveSlot ] = nil

	user:save()
end
