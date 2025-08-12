return {
    FPSCap = 60,                        -- FPS limit

    tolerance = 6,                      -- allow this many FPS over the limit for spikes

    sustainedSeconds = 60,              -- how long the player must be over the limit before receiving a warning/strike

    evaluateInterval = 1.0,             -- how often to evaluate in seconds

    rollingWindowSeconds = 10,          -- capture this many seconds of frames, then get the average

    warnMessage = '**Your FPS appears to exceed the server limit (%d)** ' .. '  \n**Your Average FPS:** %d ' .. '  \n\nPlease enable a limiter (RTSS/NVIDIA/AMD or VSync) or you may be kicked.  \n\nUse /fpshelp for help',

    canMonitor = function()             -- add custom checks for monitoring fps. if they have menus open, dont check fps, etc. Pause menu, and lib menus are already in this check (pause menu is hardcoded)
        return not lib.getOpenContextMenu() and not lib.getOpenMenu()
    end
}