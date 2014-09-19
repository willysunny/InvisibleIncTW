----------------------------------------------------------------
-- Copyright (c) 2012 Klei Entertainment Inc.
-- All Rights Reserved.
-- SPY SOCIETY.
----------------------------------------------------------------

--
-- Client-side helper functions related to gameplay visualization and rendering.

local util = include( "modules/util" )

----------------------------------------------------------------
-- Local functions

local function wait( frames )
	while frames > 0 do
		frames = frames - 1
		coroutine.yield()
	end
end

local function waitForAnim( prop, anim )
	prop:forceUpdate() -- Ensures visible flag is updated; otherwise we will enter the if block but subsequently fail to render (hence infinite loop)
	if prop:shouldDraw() then
		prop:setPlayMode( KLEIAnim.ONCE )
		prop:setCurrentAnim( anim )

		if prop:getFrame() + 1 < prop:getFrameCount() then
			local animDone = false
			prop:setListener( KLEIAnim.EVENT_ANIM_END,
				function( anim, animname )
					animDone = true
				end )

			-- Wait for the end event to be triggered.
			while not animDone do
				coroutine.yield()
			end

			prop:setListener( KLEIAnim.EVENT_ANIM_END, nil )
		end
	end
end

----------------------------------------------------------------
-- Export table

return
{
	wait = wait,
	waitForAnim = waitForAnim,
}
