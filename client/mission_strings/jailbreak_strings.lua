----------------------------------------------------------------
-- Copyright (c) 2014 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local _M = 
{
	MISSION_TITLE = "JAILBREAK",
	MISSION_DESCRIPTION = "Operator, we located your missing agent. He was off the grid for a while but we've tracked him to an FTM holding cell here.",
	MISSION_GOAL = "Once we re-establish neural uplink, guide the agent to the nearest elevator. Our extraction team will meet him on the roof.",
	MISSION_ENDER = "The agent has been undergoing extensive neural probing, and may be disoriented. Speak slowly, and don't use any big words.",
	MISSION_PERSON_OF_INTEREST = "DECKARD, BRIAN",
	MISSION_POI_TYPE = "INVISIBLE, INC. SPECIAL AGENT",
	
	INITIATING = "INITIATING FAIL SAFE PROTOCOL",
	CONNECTION_ESTABLISHED = "CONNECTION ESTABLISHED",
	GUARD = "GUARD",

	LOCKPICK_MODAL_TITLE = "W E L C O M E  T O  I N C O G N I T A:  Y O U R   P E R S O N A L  A I",
	LOCKPICK_MODAL_DESC = "The agency has provided you with <c:faff0a>LOCKPICK 1.0</>, allowing you to <c:faff0a>hack 1 Firewall for 2 Power (PWR)</>. When out in the field, you may install additional programs for added utility.",

	INSTRUCTIONS_SELECT = "STATUS: UNCONSCIOUS",
	INSTRUCTIONS_MOVE = "MOVE AGENT",
	INSTRUCTIONS_MOVE_SUBTEXT = "<c:8cffff>BLUE SQUARES:\nMOVEMENT RANGE</>",
	INSTRUCTIONS_END_TURN = "REFRESH ACTIONS",
	INSTRUCTIONS_END_TURN_SUBTEXT = "HOTKEY: [ENTER]",
	INSTRUCTIONS_WAITING = "APPROACH DOOR",
	--INSTRUCTIONS_PEEK = "<USE THE PEEK ACTION TO LOOK OUTSIDE THE DOOR>",
	INSTRUCTIONS_GET_TAZER = "DECKARD'S STASH",
	INSTRUCTIONS_GET_TAZER_SUBTEXT = "APPROACH TO OBTAIN",
	INSTRUCTIONS_KNOCK_OUT = "<KNOCK OUT THE GUARD FROM BEHIND>",
	INSTRUCTIONS_PINNED = "PINNED GUARDS DON'T AWAKEN",
	INSTRUCTIONS_SHUT_THE_DOOR = "CLOSED DOORS BLOCK LINE OF SIGHT",
	INSTRUCTIONS_CONSOLE = "VULNERABILITY DETECTED",
	INSTRUCTIONS_CAMERA = "ACCESS INCOGNITA",
	INSTRUCTIONS_CAMERA_SUBTEXT = "HOTKEY: [SPACE]",
	INSTRUCTIONS_HACK_CAMERA = "FIREWALL DETECTED",
	INSTRUCTIONS_HACK_CAMERA_SUBTEXT = "CLICK TO HACK",
	INSTRUCTIONS_EXIT_MAINFRAME = "EXIT INCOGNITA",
	INSTRUCTIONS_DOOR_CORNER = "RECON POINT",
	INSTRUCTIONS_OPEN_DOOR = "OPEN DOOR",
	INSTRUCTIONS_OPEN_DOOR_SUBTEXT = "LURE HIM OUT",
	INSTRUCTIONS_MELEE_OVERWATCH = "MELEE REACTION",
	INSTRUCTIONS_MELEE_OVERWATCH_SUBTEXT = "ENABLES MELEE ON ENEMY TURN",
	INSTRUCTIONS_DANGER_ZONE = "ENERGY SPIKE",
	INSTRUCTIONS_DANGER_ZONE_SUBTEXT = "RED IS DANGER",
	INSTRUCTIONS_CORNER = "RECON POINT",
	INSTRUCTIONS_CORNER_SUBTEXT = "",
	INSTRUCTIONS_CORNER_PEEK = "LOOK AROUND CORNERS",
	INSTRUCTIONS_CORNER_PEEK_SUBTEXT = "HOTKEY: [P]",
	--INSTRUCTIONS_EXIT = "<DISABLE THE SECURITY AND ESCAPE>",

	OPERATOR_AWAKE = "There he is. <c:faff0a>Wake him up</>.",
	OPERATOR_MOVE = "Deckard, you were captured. Again.\n<c:faff0a>Can you walk?</>",
	OPERATOR_END_TURN = "Let him catch his breath. But don't dally, they'll notice our intrusion soon.",	
	OPERATOR_WAITING = "<c:faff0a>Get to the door.</>",
	OPERATOR_PEEK = "We don't have visibility on the hallway. You'll have to manually check for hostiles.",
	OPERATOR_GET_OUT = "It's unlocked. Get out, and be careful not to alert the guard.",
	OPERATOR_TOOLS = "Your tools should be in that safe. We'll need your <c:faff0a>Neural Disrupter</> to take down these guards.",
	OPERATOR_KNOCK_OUT = "Good. Now <c:faff0a>approach the guard from behind</> and neutralize him.",
	OPERATOR_PINNED = "Sloppy, but effective. <c:faff0a>Proceed to the next door</>.",
	OPERATOR_AFTER_MOVE_AWAY = "That guard will reawaken in a couple minutes. I recommend you hurry.",
	OPERATOR_SHUT_THE_DOOR = "<c:faff0a>Close the door</> to cover our tracks. If they catch us we'll lose uplink again.",
	OPERATOR_CONSOLE = "We're going to need <c:faff0a>POWER (PWR)</> in order to hack their system. Jack that console for a quick boost.",
	OPERATOR_GOT_CONSOLE = "Good. That will help us bypass any security devices we encounter.",
	OPERATOR_CAMERA = "If that camera locks on, it will alert the whole building. We need <c:faff0a>Incognita</> to hack it.",
	OPERATOR_HACK_CAMERA = "Camera compromised. It's eyes are ours now. Let's keep moving.",
	OPERATOR_DOOR_CORNER = "Caution is our friend, agent. <c:faff0a>Get into position beside that door</> and scout the next room.",
	OPERATOR_DISTRACT = "That guard doesn't look like he's moving. <c:faff0a>Let's give him a reason to</>, shall we?",
	OPERATOR_MELEE_PREP = "Alright, he's coming. <c:faff0a>Prepare yourself</>.",
	OPERATOR_NEXT_ROOM = "Nice work. We're almost there. The exit is just up ahead.",
	OPERATOR_DANGER_ZONE = "Hold up - Incognita has <c:faff0a>detected danger</> around the next corner.",
	OPERATOR_AFTER_PEEK = "We should have enough power left for <c:faff0a>Incognita</> to bypass that hardware.",
	OPERATOR_NEED_POWER = "One more camera. We need more <c:faff0a>power for Incognita</> to bypass that hardware. Look for another console.",
	OPERATOR_REMIND_INCOGNITA = "Only one camera between you and the exit.\n<c:faff0a>Use Incognita</> to take it over.",
	OPERATOR_EXIT = "Alright Deckard, get to the roof. We have a helicopter enroute.",
	OPERATOR_WON = "We're done. Rendevous with your partner Internationale and get back to HQ. We've got money to make.",
	OPERATOR_CAUGHT = "Damn it, Operator!",
}

return _M

