----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

package.path = "./client/?.lua;./?.lua" -- .. package.path

function mountDirectory( mount, dir )
	-- Mounted directories on the client are always archives.
	return MOAIFileSystem.mountVirtualDirectory( mount, dir .. ".zip" )
end

function include( filename )
	return require(filename)
end

function reinclude( filename )
	if package.loaded[ filename ] and config.DEV then
		log:write( "Reloading: '%s'", filename )
		package.loaded[ filename ] = nil
		local oldpath = package.path
		package.path = "../../code_src/game/?.lua;../../code_src/game/client/?.lua;" .. package.path
		local result = require( filename )
		package.path = oldpath
		return result
	else
		return require( filename )
	end
end

function simlog( ... )
	log:write( ... )
end
