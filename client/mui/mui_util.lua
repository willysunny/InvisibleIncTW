-----------------------------------------------------
-- MOAI UI
-- Copyright (c) 2012-2012 Klei Entertainment Inc.
-- All Rights Reserved.

local mui_defs = require("mui/mui_defs")

local function isMouseEvent( ev )
	return
		ev.eventType == mui_defs.EVENT_MouseDown or
		ev.eventType == mui_defs.EVENT_MouseUp or
		ev.eventType == mui_defs.EVENT_MouseMove or
		ev.eventType == mui_defs.EVENT_MouseWheel
end

local function setVisible( condition, ... )
	for i = 1, select( "#", ... ) do
		local widget = select( i, ... )
		widget:setVisible( condition )
	end
end

local KEY_NAMES =
{
	[ mui_defs.K_A ] = "A",
	[ mui_defs.K_B ] = "B",
	[ mui_defs.K_C ] = "C",
	[ mui_defs.K_D ] = "D",
	[ mui_defs.K_E ] = "E",
	[ mui_defs.K_F ] = "F",
	[ mui_defs.K_G ] = "G",
	[ mui_defs.K_H ] = "H",
	[ mui_defs.K_I ] = "I",
	[ mui_defs.K_J ] = "J",
	[ mui_defs.K_K ] = "K",
	[ mui_defs.K_L ] = "L",
	[ mui_defs.K_M ] = "M",
	[ mui_defs.K_N ] = "N",
	[ mui_defs.K_O ] = "O",
	[ mui_defs.K_P ] = "P",
	[ mui_defs.K_Q ] = "Q",
	[ mui_defs.K_R ] = "R",
	[ mui_defs.K_S ] = "S",
	[ mui_defs.K_T ] = "T",
	[ mui_defs.K_U ] = "U",
	[ mui_defs.K_V ] = "V",
	[ mui_defs.K_W ] = "W",
	[ mui_defs.K_X ] = "X",
	[ mui_defs.K_Y ] = "Y",
	[ mui_defs.K_Z ] = "Z",

	[ mui_defs.K_1 ] = "1",
	[ mui_defs.K_2 ] = "2",
	[ mui_defs.K_3 ] = "3",
	[ mui_defs.K_4 ] = "4",
	[ mui_defs.K_5 ] = "5",
	[ mui_defs.K_6 ] = "6",
	[ mui_defs.K_7 ] = "7",
	[ mui_defs.K_8 ] = "8",
	[ mui_defs.K_9 ] = "9",
	[ mui_defs.K_0 ] = "0",

	[ mui_defs.K_F1 ] = "F1",
	[ mui_defs.K_F2 ] = "F2",
	[ mui_defs.K_F3 ] = "F3",
	[ mui_defs.K_F4 ] = "F4",
	[ mui_defs.K_F5 ] = "F5",
	[ mui_defs.K_F6 ] = "F6",
	[ mui_defs.K_F7 ] = "F7",
	[ mui_defs.K_F8 ] = "F8",
	[ mui_defs.K_F9 ] = "F9",

	[ mui_defs.K_BACKSPACE ] = "BACKSPACE",
	[ mui_defs.K_TAB ] = "TAB",
	[ mui_defs.K_ENTER ] = "ENTER",

	[ mui_defs.K_LEFTARROW ] = "LEFT",
	[ mui_defs.K_UPARROW ] = "UP",
	[ mui_defs.K_RIGHTARROW ] = "RIGHT",
	[ mui_defs.K_DOWNARROW ] = "DOWN",

	[ mui_defs.K_ESCAPE ] = "ESC",
	[ mui_defs.K_SPACE ] = "SPACE",
	[ mui_defs.K_SNAPSHOT ] = "PRINTSCREEN",
	[ mui_defs.K_DELETE ] = "DEL",
	[ mui_defs.K_PLUS ] = "PLUS",
	[ mui_defs.K_COMMA ] = "COMMA",
	[ mui_defs.K_MINUS ] = "MINUS",
	[ mui_defs.K_PERIOD ] = "PERIOD",
	[ mui_defs.K_SLASH ] = "SLASH",
	[ mui_defs.K_TILDE ] = "TILDE",

	[ mui_defs.K_SHIFT ] = "SHIFT",
	[ mui_defs.K_CONTROL ] = "CTRL",
	[ mui_defs.K_ALT ] = "ALT",
}

local function getKeyName( keyCode )
	return KEY_NAMES[ keyCode ] or ""
end

return
{
	TOP_PRIORITY = 1000000,
	isMouseEvent = isMouseEvent,
	getKeyName = getKeyName,
	setVisible = setVisible,
}

