----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

local HELP_LINES =
{
    "help",
    "cls",
    "credits",
    "quit",
    "version"
}

local util = include("modules/util")
local mui = include( "mui/mui" )
local mui_defs = include( "mui/mui_defs" )

----------------------------------------------------------------

local PROMPT_STR = "> "
local MAX_LINES = 29

local creditsScreen = {}

local function onClickDone()
	statemgr.deactivate( creditsScreen )
end

local function clearLines( self )
    util.tclear( self.lines )
    self.screen.binder.creditNames:setText( "" )
end

local function addLine( self, line )
    table.insert( self.lines, line )
    while #self.lines > MAX_LINES do
        table.remove( self.lines, 1 )
    end

    self.screen.binder.creditNames:setText( table.concat( self.lines, "\n" ))
    self.screen.binder.creditNames:spoolText()
end

local function addLines( self, lines )
    for i, line in ipairs( lines ) do
        table.insert( self.lines, line )
    end
    while #self.lines > MAX_LINES do
        table.remove( self.lines, 1 )
    end
    self.screen.binder.creditNames:setText( table.concat( self.lines, "\n" ))
    self.screen.binder.creditNames:spoolText()
end

local function showCredits( self )
    clearLines( self )

	local fl = io.open( "data/misc/credits.txt", "r" )
	if fl then
		local key, lines = nil, {}
		for line in fl:lines() do
            table.insert( self.lines, line )
		end
	else
		log:write( "WARNING: Failed to read credits.\n%s", debug.traceback() )
	end

	util.shuffle( self.lines, function( n ) return math.random( 1, n ) end )
    table.insert( self.lines, 1, "Klei Entertainment is:" )

    self.screen.binder.creditNames:spoolText( table.concat( self.lines, "\n" ))
end


local function onEditCommand( self, txt )
    addLine( self, "" )
    addLine( self, txt )

    txt = txt:match( "^" .. PROMPT_STR .. "%s*([^ ]+)%s*$" )
    print( "CMD:", txt )

    if txt == "?" or txt == "help" then
        addLines( self, HELP_LINES )
    elseif txt == "quit" then
    	statemgr.deactivate( self )
    elseif txt == "credits" then
        showCredits( self )
    elseif txt == "cls" then
        clearLines( self )
    elseif txt == "version" then
        addLine( self, util.formatGameInfo() )
    else
        addLine( self, "Unknown command." )
    end

    self.screen.binder.editTxt:setText( PROMPT_STR )
	self.screen.binder.editTxt:startEditing( mui_defs.EDIT_CMDPROMPT )
end


creditsScreen.onLoad = function ( self )
	self.screen = mui.createScreen( "credits.lua" )
	mui.activateScreen( self.screen )

    self.lines = {}

    self.screen.binder.editTxt:setText( PROMPT_STR )
	self.screen.binder.creditNames:spoolText("")
	self.screen.binder.backBtn.binder.btn:setText( STRINGS.UI.BACK )
	self.screen.binder.backBtn.binder.btn:setHotkey( mui_defs.K_ESC )
	self.screen.binder.backBtn.binder.btn.onClick = onClickDone
    self.screen.binder.editTxt.onEditComplete = util.makeDelegate( nil, onEditCommand, self )

    showCredits( self )
end

----------------------------------------------------------------
creditsScreen.onUnload = function ( self )
	mui.deactivateScreen( self.screen )
end

return creditsScreen
