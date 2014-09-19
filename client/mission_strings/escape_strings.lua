----------------------------------------------------------------
-- Copyright (c) 2014 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------



local _M = 
{
	MISSION_TITLE = "ASSET LIBERATION",

	MISSION_DESCRIPTION_1 = "Operator, we've found a useful vulnerability. The <Corporation> satellite network has no visibility in this sector.",
	MISSION_ENDER_1 = "Keep a low profile, and this should be profitable.",

	MISSION_DESCRIPTION_2 = "They're rebooting their regional servers, and aren't recording the security telemetry from this installation.",
	MISSION_ENDER_2 = "Information is power, Operator, so try to get as much intel as you can find.",

	MISSION_DESCRIPTION_3 = "Operator, we've gained one-time access to the facility here.",
	MISSION_ENDER_3 = "Grab what you can, but don't take any unnecessary risks. Good luck.",

	MISSION_DESCRIPTION_4 = "Incognita says that there's something interesting in this building.",
	MISSION_ENDER_4 = "There's no contract for this one, Operator. Be subtle.",

	MISSION_DESCRIPTION_5 = "We have a chance to settle an old score. There's a gap in their security coverage at this facility",
	MISSION_ENDER_5 = "I'll send their regional manager our personal condolences once you're out. Oh, to see the look on his face!",

	MISSION_DESCRIPTION_6 = "This is a by-the-numbers infiltration, Operator. You will be going here.",
	MISSION_ENDER_6 = "Play it cautiously - there's no sense in risking valuable assets on a fishing expedition.",

	MISSION_DESCRIPTION_7 = "We've got them right where we want them. Look at the grid around this building",
	MISSION_ENDER_7 = "Grab as much as you can, but don't take any stupid risks. A healthy agent is far more valuable than the contents of any safe.",

	MISSION_DESCRIPTION_8 = "I want to send them a message. We're going to hit them at this location.",
	MISSION_ENDER_8 = "No need for subtlety this time - I want them to know who did this.",

	MISSION_DESCRIPTION_9 = "Bureaucracy is a beautiful thing. They're decommissioning this facility.",
	MISSION_ENDER_9 = "The chopper is fueled and ready to go. Bring us back something nice, will you?",

	MISSION_DESCRIPTION_10 =  "They've been acting against our interests lately, and it would be prudent to strike back. We're sending you here.",
	MISSION_ENDER_10 = "Try not to lose any agents, Operator. I don't want to deal with the paperwork.",

	MISSION_DESCRIPTION_11 =  "It looks like we've found a hole in the security here",
	MISSION_ENDER_11 = "The window on this won't last long. Get out before they can get reinforcements on site.",

	OBJECTIVE = "Find the elevator",	

	FIRST_LEVEL = "Alright, time to make a profit. Remember, your agents are good, but not bullet proof. Get as much as you can, then get out of here.",	

	OPERATOR_ESCAPE_PRISONER = "The Prisoner is clear, good work Operator. His finders fee will be a nice boost.",
	OPERATOR_SEEPRISONER = "Incognita has detected a prisoner in one of the cells. Enemies of our enemies may be our friends as they say.",
	PRISONER_NAME = "Prisoner KSC2-303",

	PRISONER_CONVO1 = "I don't know who you are, but if you get me out of here, you won't regret it.",
	OPERATOR_PRISONER_CONVO1 = "Incognita has scanned his identity, he has wealthy benefactors. It may be worth our while to help him.",
	OBJ_RESCUE_PRISONER = "Rescue the prisoner",

	OPERATOR_ESCAPE_AGENT = "%s is out, excellent work Operator.",
	OPERATOR_SEEAGENT = "Incognita has detected an agent currently logged as MIA. They would be an incredible asset if you can get them back on the team.",
	OBJ_RESCUE_AGENT = "Rescue %s",

	OPERATOR_SCANNER_DETECTED_1 = "Incognita has detected an ECCM signal. There must be one of FTM's powerful scanning devices in the complex.",
	OPERATOR_SCANNER_DETECTED_2 = "It'll detect your team's location each alarm level, make sure to shut it down.",
	OPERATOR_SCANNER_DETECTED_3 = "Good job, Operator. At least you won't need to worry about that one anymore.",

	OPERATOR_PWR_DRAIN_DETECTED_1 = "Operator, Incognita is detecting fluctuation in your PWR levels. FTM may be powering up their PWR reversal node.",
	OPERATOR_PWR_DRAIN_DETECTED_2 = "Be careful, once it's operational it will drain your PWR every turn until hacked.",
	OPERATOR_PWR_DRAIN_DETECTED_3 = "Your PWR levels have returned to normal. Well done, Operator.",

	CELLBLOCK_1 = "Look for a cellblock, there may be someone useful in there.",
	CELLBLOCK_2 = "There's a high-security detention center on-site. I wonder who they're keeping in there.",
	CELLBLOCK_3 = "They're keeping someone under detention here. It's high security, so they must be important.",
	CELLBLOCK_4 = "There is a detention facility on the grounds. Keep an eye open for agents.",

	GENERIC_1 = "This is a target of opportunity. Get in, steal anything of value, and get out.",
	GENERIC_2 = "There's no contract here, we're simply taking what's theirs.",
	GENERIC_3 = "Try to find as much intel and valuables as you can, and get back to the elevator.",
	GENERIC_4 = "You'll have a small window of opportunity to grab as much materiel as you can.",
	GENERIC_5 = "Find anything of value that isn't bolted to the floor. Incognita will erase all records of our intrusion.",
	GENERIC_6 = "See what you can find. You never know what they're keeping at these unlisted sites.",
	GENERIC_7 = "This one's just for personal gain. See what you can find, and get back before they know you've been there.",

	GUARDROOM_1 = "There's a guard station here. You may be able to secure some untraceable weapons.",
	GUARDROOM_2 = "Keep an eye out for an armoury. We could certainly use the ammunition.",
	GUARDROOM_3 = "There are a large number of guards on staff. Keep an eye out for loose weaponry.",
	GUARDROOM_4 = "This is a training facility for new security staff. You may be able to steal some unlicensed armaments.",

	NANOFAB_1 = "There is a nanofab on-site. You should be able to re-stock our supplies.",
	NANOFAB_2 = "Records indicate a nanofab somewhere in the facility. I recommend you bring surplus credits.",
	NANOFAB_3 = "Keep your eyes peeled for a nanofab. You should be able to override its security clearance.",
	NANOFAB_4 = "We think there's a nanofab in the building. That should be your highest priority.",

	SECURITYROOM_1 = "They've got a high-security data vault here. It may provide us with new mission targets.",
	SECURITYROOM_2 = "They use this facility for debriefings. Potential mission information is probably stored on-site.",
	SECURITYROOM_3 = "Look for a secure holding facility. They use them to deprogram contractors - it's a good way to find new vulnerabilities.",
	SECURITYROOM_4 = "Watch for a secure holding cell. There should be extracted target information nearby.",

	SERVER_1 = "There's an unusually powerful server in the building. Don't miss it.",
	SERVER_2 = "There's a lot of data going through that place. Look for a central server.",
	SERVER_3 = "There's hiding a central server there. We could use that data.",
	SERVER_4 = "They're keeping an off-grid server here. Interesting.",
	SERVER_5 = "It looks like a secret software development lab. See if there's anything interesting on their central server.",

	VAULT_1 = "There's a vault on-site. Probably an executive slush-fund.",
	VAULT_2 = "This facility handles payroll for the entire region. Look for a large stash of credits.",
	VAULT_3 = "The local executive has been embezzling credits. Find the vault, and they are ours.",
	VAULT_4 = "There have been anomalous financial transactions coming from this facility. Keep your eyes peeled for a credit vault.",


--[[
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

	]]


}

return _M

