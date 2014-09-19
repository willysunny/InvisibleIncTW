----------------------------------------------------------------
-- Copyright (c) 2014 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local _M = 
{
	MISSION_TITLE = "INSOMNIAC",
	MISSION_DESCRIPTION = "<Corporation> has intercepted one of our client's couriers. He's got important intel stored in a cerebral implant.",
	MISSION_GOAL = "Your task is to break in, locate the courier, and recover the information. ",
	MISSION_ENDER = "One final note - the implant is set to explode if the courier loses consciousness, so we have to work fast.",
	MISSION_PERSON_OF_INTEREST = "GORDON, JONATHAN F.",
	MISSION_POI_TYPE = "DATA COURIER",
	
	OBJECTIVE_FIND_HOSTAGE = "Find the Courier",
	OBJECTIVE_RESCUE_HOSTAGE = "Rescue the Courier",
	OBJECTIVE_ESCAPE = "Escape with the Courier",

	OPERATOR_OPEN = "Alright, you're in. Their automated system is beginning to track you, so time is not on your side.\n\nFind the courier, and get out.",
	HOSTAGE_SIGHTED = "There's the courier. It looks like they've been thorough. He won't last much longer.",
	HOSTAGE_CONVO1 = "You. You're not one of them. Who are you?",
	OPERATOR_CONVO1 = "We're here to help. Keep quiet and keep your head down, and you might get out alive.",
	HOSTAGE_CONVO2 = "We better hurry... I can't hold up much longer",
	OPERATOR_CONVO2 = "Hmmmm. It looks like the drive was damaged. If we're going to get him out in one piece we had best do it quickly.",
	OPERATOR_ESCAPE = "Good job, team. We should be able to stabilize him in the helicopter.",

	HOSTAGE_VITALS = "VITAL STATUS",
	HOSTAGE_VITALS_SUBTEXT = "%d TURN(S) REMAINING",
	HOSTAGE_VITALS_SUBTEXT_DEATH = "EXPIRED",
	HOSTAGE_NAME = "THE COURIER",

	GUARD_INTERROGATE1 = "I'm getting tired of asking you. Tell me the unlock sequence, or I'll rip it out of your head with my bare hands.",
	COURIER_INTERROGATE1 = "I don't know, man! I just carry the thing. I can't see inside!",

	HOSTAGE_BANTER = 
	{
		"The task. Stay on the task. Get the data to the customer.",
		"I have to stay awake! My head...",
		"You'll get me out of here, right?",
		"Everything is moving so slowly!",
		"They can see your thoughts when you close your eyes.",
		"They caught me in the washroom. It's not fair!",
		"The probes! They can see your dreams.",
		"My head hurts. Like, really hurts.",
		"Do you smell that?",
	},

	HOSTAGE_PASS_OUT = "Something's wrong. Oh God, something's wrong!",
	CENTRAL_PASS_OUT = "What part of 'quickly' did you misunderstand? Get to the elevator.",

	CENTRAL_HOSTAGE_DEATH = "Blast! There goes our bonus. Proceed to the extraction point.",

	CENTRAL_COMPLETE_MISSION_NO_COURIER = "At least you survived. We will discuss this further in debriefing.",
}

return _M

