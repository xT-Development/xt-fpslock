local config = lib.load('configs.client')

local GetFrameTime = GetFrameTime
local IsPauseMenuActive = IsPauseMenuActive
local NetworkIsSessionStarted = NetworkIsSessionStarted
local IsPlayerSwitchInProgress = IsPlayerSwitchInProgress

-- fps monitor
local FPSMonitor = {
    buffer = {},
    bufferSize = math.min(120, math.max(30, math.ceil(config.evaluateInterval * config.FPSCap))),
    sum = 0.0,
    overSustain = 0.0,
    showWarning = false,

    -- performance variables
    adaptiveInterval = 0,
    consecutiveGoodFrames = 0,
    lastMonitorCheck = 0,
    monitorCheckInterval = 1000, -- check monitoring conditions every 1000ms when disabled
}

-- init buffer
for i = 1, FPSMonitor.bufferSize do
    FPSMonitor.buffer[i] = 0.0
end

-- add frame time
function FPSMonitor:addFrameTime(frameTime)
    self.buffer[#self.buffer + 1] = frameTime
    self.sum = self.sum + frameTime

    if #self.buffer > self.bufferSize then
        self.sum = self.sum - self.buffer[1]
        table.remove(self.buffer, 1)
    end
end

-- calculate average fps
function FPSMonitor:getAverageFPS()
    local avgFrameTime = self.sum / #self.buffer
    return avgFrameTime > 0 and (1.0 / avgFrameTime) or 0
end

-- check if monitoring is allowed
function FPSMonitor:canMonitor()
    return NetworkIsSessionStarted() and not IsPauseMenuActive() and not IsPlayerSwitchInProgress() and not self.showWarning and config.canMonitor()
end

-- adaptive sleep calculation based on current FPS performance
function FPSMonitor:calculateAdaptiveSleep(avgFPS, overLimit)
    if overLimit then -- frequent monitoring when over limit
        self.consecutiveGoodFrames = 0
        return 0
    else
        self.consecutiveGoodFrames = self.consecutiveGoodFrames + 1

        local fpsMargin = config.FPSCap - avgFPS -- adaptive sleep based FPS

        if fpsMargin > 20 then
            return math.min(50, 10 + self.consecutiveGoodFrames)                -- FPS is way under limit, can afford longer sleep
        elseif fpsMargin > 10 then
            return math.min(25, 5 + math.floor(self.consecutiveGoodFrames / 2)) -- FPS is comfortably under limit
        elseif fpsMargin > 5 then
            return math.min(10, 2 + math.floor(self.consecutiveGoodFrames / 4)) -- FPS is getting close to limit, moderate monitoring
        else
            return math.min(5, 1 + math.floor(self.consecutiveGoodFrames / 10)) -- FPS is close to limit, frequent monitoring
        end
    end
end

-- exceeded fps limit violation
function FPSMonitor:handleFPSViolation(avgFPS)
    self.showWarning = true
    self.consecutiveGoodFrames = 0 -- reset counter on violation

    SetTimeout(0, function() -- show warning, do not wait
        local warning = lib.alertDialog({
            header = 'FPS LIMIT',
            content = (config.warnMessage):format(config.FPSCap, math.floor(avgFPS)),
            centered = true,
        })

        FPSMonitor.showWarning = false
    end)

    TriggerServerEvent('xt-fpslock:server:strikePlayer') -- strike player
end

CreateThread(function()
    local evalTimer = 0.0
    local sleep = 0
    local lastTime = GetGameTimer()

    while true do
        local currentTime = GetGameTimer()
        local frameTime = GetFrameTime()
        FPSMonitor:addFrameTime(frameTime)

        -- check if we can monitor FPS
        local canMonitor = false
        if currentTime - FPSMonitor.lastMonitorCheck >= FPSMonitor.monitorCheckInterval then
            canMonitor = FPSMonitor:canMonitor()
            FPSMonitor.lastMonitorCheck = currentTime
        else
            canMonitor = sleep < 100 -- use previous monitoring state if checked recently
        end

        if canMonitor then
            evalTimer = evalTimer + frameTime

            local avgFPS = FPSMonitor:getAverageFPS()
            local overLimit = avgFPS > (config.FPSCap + config.tolerance)

            if overLimit then -- sustained over limit
                FPSMonitor.overSustain = FPSMonitor.overSustain + frameTime
            else
                FPSMonitor.overSustain = math.max(0.0, FPSMonitor.overSustain - (2.0 * frameTime))
            end

            if evalTimer >= config.evaluateInterval then -- evaluate timer
                evalTimer = 0.0

                if FPSMonitor.overSustain >= config.sustainedSeconds then -- check if over limit
                    FPSMonitor:handleFPSViolation(avgFPS) -- handle violation
                    FPSMonitor.overSustain = 0.0
                end
            end

            sleep = FPSMonitor:calculateAdaptiveSleep(avgFPS, overLimit) -- calculate adaptive sleep based on current performance
        else -- not monitoring, longer sleep
            sleep = 100
            FPSMonitor.consecutiveGoodFrames = 0
        end

        Wait(sleep)
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