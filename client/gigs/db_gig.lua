local util = include( "modules/util" )

local STATE_MENU = 1
local STATE_RECORDS = 2
local STATE_QUIT = 3

local db_gig = class()

function db_gig:init( sim )
	self._sim = sim
	self._state = STATE_MENU
end

function db_gig:processInput( txt )
	if self._state == STATE_MENU then
		if txt == "1" then
			local npc = self._sim:getNPC()
			local i = 1
			for agentID, deployData in pairs( self._sim:getPC():getDeployed() ) do
				local unit = npc:getLastKnownUnit( self._sim, deployData.id )
				if unit and unit:isGhost() then
					self:output( string.format( "\n%d)\nAGENT #%d %s\nAVOCATION:%s\nLAST SEEN: (%d, %d)\n---------------------------\n",
						i, agentID, util.toupper( unit:getName() ), util.toupper( unit:getUnitData().class ), unit:getLocation() ))
					i = i + 1
				end
			end
			if i == 1 then
				self:output( "No agents on record" )
			end

		elseif txt == "2" then
			self:output( "Goodbye! (CTRL-C to close console)" )
			self._state = STATE_QUIT

		else
			self:output( "That is not a valid option." )
			self:showMenu()
		end

	elseif self._state == STATE_RECORDS then
	end
end

function db_gig:output( txt )
	self._panel:displayLine( txt )
end

function db_gig:showMenu()
	self:output( "Welcome to the EMDBS!\n-----------------\nChoose your option:\n [1] View records\n [2] Quit\n" )
end

function db_gig:setPanel( panel )
	self._panel = panel

	self:showMenu()
end

return db_gig