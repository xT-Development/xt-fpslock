local config = lib.load('configs.client')

-- fps monitor
local FPSMonitor = {
    frameBuffer = {},
    bufferSize = math.min(300, math.max(60, math.ceil(config.evaluateInterval * config.FPSCap * 1.2))), -- adds 0.2% for safety
    currentIndex = 1,
    bufferFull = false,
    frameSum = 0.0,

    evalTimer = 0.0,
    overSustain = 0.0,
    showWarning = false,
    lastGameState = false,
}

-- init buffer
function FPSMonitor:init()
    for i = 1, self.bufferSize do
        self.frameBuffer[i] = 0.0
    end
end

-- add frame time
function FPSMonitor:addFrameTime(frameTime)
    self.frameSum = self.frameSum - self.frameBuffer[self.currentIndex] -- remove old

    -- add new
    self.frameBuffer[self.currentIndex] = frameTime
    self.frameSum = self.frameSum + frameTime

    -- update index and move position
    self.currentIndex = self.currentIndex + 1
    if self.currentIndex > self.bufferSize then
        self.currentIndex = 1
        self.bufferFull = true
    end
end

-- calculate average fps
function FPSMonitor:getAverageFPS()
    local count = self.bufferFull and self.bufferSize or (self.currentIndex - 1)
    if count == 0 then
        return 0
    end

    local averageFrameTime = self.frameSum / count -- calculate average
    return averageFrameTime > 0 and (1.0 / averageFrameTime) or 0
end

-- check if monitoring is allowed
function FPSMonitor:canMonitor()
    return NetworkIsSessionStarted() and not IsPauseMenuActive() and not IsPlayerSwitchInProgress() and not self.showWarning and config.canMonitor()
end

-- exceeded fps limit violation
function FPSMonitor:handleFPSViolation(avgFPS)
    self.showWarning = true

    SetTimeout(0, function() -- show warning, do not wait
        local warning = lib.alertDialog({
            header = 'FPS LIMIT',
            content = (config.warnMessage):format(config.FPSCap, math.floor(avgFPS)),
            centered = true,
        })

        FPSMonitor.showWarning = false
        FPSMonitor.overSustain = 0.0
    end)

    TriggerServerEvent('xt-fpslock:server:strikePlayer') -- strike player
end

-- main monitoring
function FPSMonitor:update(deltaTime)
    self:addFrameTime(deltaTime)

    local canMonitor = self:canMonitor()

    -- reset timers
    if canMonitor and not self.lastGameState then
        self.evalTimer = 0.0
        self.overSustain = 0.0
    end

    -- update state
    self.lastGameState = canMonitor

    if not canMonitor then return end -- nothing to do, return

    self.evalTimer = self.evalTimer + deltaTime -- update timer

    if self.evalTimer >= config.evaluateInterval then -- evaluate fps
        local avgFPS = self:getAverageFPS()
        local overLimit = avgFPS > (config.FPSCap + config.tolerance)

        if overLimit then -- over limit, add time
            self.overSustain = self.overSustain + self.evalTimer
        else
            self.overSustain = math.max(0.0, self.overSustain - (2.0 * self.evalTimer))
        end

        if self.overSustain >= config.sustainedSeconds then -- over sustained time, show warning
            self:handleFPSViolation(avgFPS)
        end

        self.evalTimer = 0.0 -- reset evaluation timer
    else
        local avgFPS = self:getAverageFPS()
        local overLimit = avgFPS > (config.FPSCap + config.tolerance)

        if overLimit then -- over limit, add time
            self.overSustain = self.overSustain + deltaTime
        else
            self.overSustain = math.max(0.0, self.overSustain - (2.0 * deltaTime))
        end
    end
end

-- init monitor
FPSMonitor:init()

CreateThread(function()
    local nextWait = 0

    while true do
        local frameTime = GetFrameTime()
        FPSMonitor:update(frameTime)

        if FPSMonitor:canMonitor() then
            nextWait = 0
        else
            nextWait = 100
        end

        Wait(nextWait)
    end
end)

-- exports
exports('getAverageFPS', function()
    return FPSMonitor:getAverageFPS()
end)

exports('getOverSustainTime', function()
    return FPSMonitor.overSustain
end)

-- help command
RegisterCommand('fpshelp', function()
    local cap = config.FPSCap
    local msg = ('**How to cap your FPS to %d:**  \n'
        ..'• **NVIDIA: Control Panel** → Manage 3D Settings → Program Settings (FiveM) → Max Frame Rate.  \n'
        ..'• **AMD: Radeon Settings** → Gaming → FiveM → Frame Rate Target Control.  \n'
        ..'• **RTSS (RivaTuner):** Add FiveM.exe → set Framerate limit = %d.  \n'
        ..'• **In-game:** Try enabling VSync if you want ~monitor refresh.'):format(cap, cap)

    local alert = lib.alertDialog({
        header = 'FPS LIMIT HELP',
        content = msg,
        centered = true,
    })
end, false)

-- fps command
RegisterCommand('whatsmyfps', function()
    lib.notify({
        title = 'FPS',
        description = ('Your FPS: %s | Server Limit: %s'):format(math.floor(FPSMonitor:getAverageFPS()), config.FPSCap),
    })
end, false)