-----------------------------------------------------
-- MOAI UI
-- Copyright (c) 2012-2012 Klei Entertainment Inc.
-- All Rights Reserved.

return
{
	-- Mouse Buttons
	MB_None = 0,
	MB_Left = 1,
	MB_Middle = 2,
	MB_Right = 3,

	-- Keys.  These are set to match Win32 Virtual Keys VK_*
	K_A = string.byte("A"),
	K_B = string.byte("B"),
	K_C = string.byte("C"),
	K_D = string.byte("D"),
	K_E = string.byte("E"),
	K_F = string.byte("F"),
	K_G = string.byte("G"),
	K_H = string.byte("H"),
	K_I = string.byte("I"),
	K_J = string.byte("J"),
	K_K = string.byte("K"),
	K_L = string.byte("L"),
	K_M = string.byte("M"),
	K_N = string.byte("N"),
	K_O = string.byte("O"),
	K_P = string.byte("P"),
	K_Q = string.byte("Q"),
	K_R = string.byte("R"),
	K_S = string.byte("S"),
	K_T = string.byte("T"),
	K_U = string.byte("U"),
	K_V = string.byte("V"),
	K_W = string.byte("W"),
	K_X = string.byte("X"),
	K_Y = string.byte("Y"),
	K_Z = string.byte("Z"),

	K_1 = 0x31,
	K_2 = 0x32,
	K_3 = 0x33,
	K_4 = 0x34,
	K_5 = 0x35,
	K_6 = 0x36,
	K_7 = 0x37,
	K_8 = 0x38,
	K_9 = 0x39,
	K_0 = 0x40,

	K_F1 = 0x70,
	K_F2 = 0x71,
	K_F3 = 0x72,
	K_F4 = 0x73,
	K_F5 = 0x74,
	K_F6 = 0x75,
	K_F7 = 0x76,
	K_F8 = 0x77,
	K_F9 = 0x78,

	K_BACKSPACE = 0x08,
	K_TAB = 0x09,
	K_PAUSE = 0x13,
	K_ENTER = 0x0D,

	K_LEFTARROW = 0x25,
	K_UPARROW = 0x26,
	K_RIGHTARROW = 0x27,
	K_DOWNARROW = 0x28,

	K_ESCAPE = 0x1B,
	K_SPACE = 0x20,
	K_SNAPSHOT = 0x2C,
	K_DELETE = 0x2E,
	K_PLUS = 0xBB,
	K_COMMA = 0xBC,
	K_MINUS = 0xBD,
	K_PERIOD = 0xBE,
	K_SLASH = 0xBF,
	K_TILDE = 0xC0,
	K_ADD = 0x6B,
	K_SUBTRACT = 0x6D,

	K_PAGEUP = 0x21,
	K_PAGEDOWN = 0x22,
	K_HOME = 0x24,
	K_END = 0x23,

	K_SHIFT = 256,
	K_CONTROL = 257,
	K_ALT = 258,

	-- Edit Modes
	EDIT_DEFAULT = 0,
	EDIT_CMDPROMPT = 1,

	-- Event Types
	EVENT_ALL = 0, -- denotes ALL event types (for handlers)
	
	EVENT_MouseDown = 100,
	EVENT_MouseUp = 101,
	EVENT_MouseMove = 102,
	EVENT_MouseWheel = 103,
	
	EVENT_KeyUp = 110,
	EVENT_KeyDown = 111,
	
	EVENT_FocusChanged = 500,
	EVENT_OnLostLock = 998,
	EVENT_OnResize = 999,
	
	-- Button Events
	EVENT_ButtonClick = 1100,
	EVENT_ButtonEnter = 1101,
	EVENT_ButtonLeave = 1102,
	EVENT_TrackStart = 1103,
	EVENT_TrackEnd = 1104,
	EVENT_Scroll = 1105,

	EVENT_DragStart = 1110,
	EVENT_DragEnter = 1111,
	EVENT_DragLeave = 1112,
	EVENT_DragDrop = 1113,

	EVENT_EditComplete = 1150,
}
