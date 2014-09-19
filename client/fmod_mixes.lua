----------------------------------------------------------------
-- Copyright (c) 2013 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local function createMixes()
	FMODMixer:addMix( "default", 2, 1, -- name, fade-in-time, priority
	{
		["music"]		= 0.7,
		["sfx/Ambience"]	= 0.5,
		["sfx/Movement"]	= 0.7,
		["sfx/Objects"]		= 0.7,
		["sfx/Attacks"]		= 0.7,
		["sfx/HitResponse"]	= 0.7,
		["sfx/HUD"]			= 0.7,
		["sfx/Actions"]		= 0.7,
		["sfx/Voice"]		= 0.7,
		["sfx/Mainframe"]	= 0.0,
		["sfx/Station"]		= 0.7,
		["sfx/Actions_2D"]		= 0.7,
	})

	FMODMixer:addMix( "quiet", .5, 2,
	{
		["music"]			= 0.3,
		["sfx/Ambience"]	= 0.0,
		["sfx/Movement"]	= 0.1,
		["sfx/Objects"]		= 0.0,
		["sfx/Attacks"]		= 0.4,
		["sfx/HitResponse"]	= 0.3,
		["sfx/HUD"]			= 0.7,
		["sfx/Actions"]		= 0.1,
		["sfx/Voice"]		= 0.2,
		["sfx/Mainframe"]	= 0.7,
		["sfx/Station"]		= 0.7,
		["sfx/Actions_2D"]		= 0.1,
	})

	FMODMixer:addMix( "mainframe", .5, 2,
	{
		["music"]			= 0.7,
		["sfx/Ambience"]	= 0.0,
		["sfx/Movement"]	= 0.1,
		["sfx/Objects"]		= 0.0,
		["sfx/Attacks"]		= 0.4,
		["sfx/HitResponse"]	= 0.3,
		["sfx/HUD"]			= 0.7,
		["sfx/Actions"]		= 0.1,
		["sfx/Voice"]		= 0.2,
		["sfx/Mainframe"]	= 0.7,
		["sfx/Station"]		= 0.0,
		["sfx/Actions_2D"]		= 0.1,
	})

	FMODMixer:addMix( "frontend", .5, 2,
	{
		["music"]			= 0.7,
		["sfx/Ambience"]	= 0.0,
		["sfx/Movement"]	= 0.0,
		["sfx/Objects"]		= 0.0,
		["sfx/Attacks"]		= 0.0,
		["sfx/HitResponse"]	= 0.0,
		["sfx/HUD"]			= 0.7,
		["sfx/Actions"]		= 0.0,
		["sfx/Voice"]		= 0.7,
		["sfx/Mainframe"]	= 0.0,
		["sfx/Station"]		= 0.7,
		["sfx/Actions_2D"]		= 0.7,
	})

	FMODMixer:addMix( "nomusic", 0, 2,
	{
		["music"]			= 0.0,
		["sfx/Ambience"]	= 0.5,
		["sfx/Movement"]	= 0.0,
		["sfx/Objects"]		= 0.0,
		["sfx/Attacks"]		= 0.0,
		["sfx/HitResponse"]	= 0.0,
		["sfx/HUD"]			= 0.7,
		["sfx/Actions"]		= 0.0,
		["sfx/Voice"]		= 0.0,
		["sfx/Mainframe"]	= 0.0,
		["sfx/Station"]		= 0.0,
		["sfx/Actions_2D"]		= 0.0,
	})

	FMODMixer:addMix( "missionbrief", 3, 2,
	{
		["music"]			= 0.3,
		["sfx/Ambience"]	= 0.2,
		["sfx/Movement"]	= 0.7,
		["sfx/Objects"]		= 0.7,
		["sfx/Attacks"]		= 0.7,
		["sfx/HitResponse"]	= 0.7,
		["sfx/HUD"]			= 0.7,
		["sfx/Actions"]		= 0.7,
		["sfx/Voice"]		= 0.7,
		["sfx/Mainframe"]	= 0.0,
		["sfx/Station"]		= 0.7,
		["sfx/Actions_2D"]		= 0.0,
	})

	FMODMixer:pushMix( "default" )
end

return
{
	createMixes = createMixes
}
