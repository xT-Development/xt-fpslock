local config = lib.load('configs.client')

local GetFrameTime = GetFrameTime
local IsPauseMenuActive = IsPauseMenuActive
local NetworkIsSessionStarted = NetworkIsSessionStarted
local IsPlayerSwitchInProgress = IsPlayerSwitchInProgress

-- fps monitor
local FPSMonitor = {
    buffer = {},
    bufferSize = math.min(120, math.max(30, math.ceil(config.evaluateInterval * config.FPSCap))),
    index = 1,
    count = 0,
    sum = 0.0,
    showWarning = false
}

-- init buffer
for i = 1, FPSMonitor.bufferSize do
    FPSMonitor.buffer[i] = 0.0
end

-- add frame time
function FPSMonitor:addFrameTime(frameTime)
    if self.count == self.bufferSize then
        self.sum = self.sum - self.buffer[self.index]
    else
        self.count = self.count + 1
    end

    -- add new
    self.buffer[self.index] = frameTime
    self.sum = self.sum + frameTime

    -- update index
    self.index = self.index + 1
    if self.index > self.bufferSize then
        self.index = 1
    end
end

-- calculate average fps
function FPSMonitor:getAverageFPS()
    if self.count == 0 then return 0 end
    local avgFrameTime = self.sum / self.count
    return avgFrameTime > 0 and (1.0 / avgFrameTime) or 0
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
    end)

    TriggerServerEvent('xt-fpslock:server:strikePlayer') -- strike player
end

CreateThread(function()
    local evalTimer = 0.0
    local overSustain = 0.0
    local sleep = 0

    while true do
        local frameTime = GetFrameTime()
        FPSMonitor:addFrameTime(frameTime)

        if FPSMonitor:canMonitor() then -- check if allowed to monitor
            sleep = 0
            evalTimer = evalTimer + frameTime

            local avgFPS = FPSMonitor:getAverageFPS()
            local overLimit = avgFPS > (config.FPSCap + config.tolerance)

            if overLimit then -- sustained over limit
                overSustain = overSustain + frameTime
            else
                overSustain = math.max(0.0, overSustain - (2.0 * frameTime))
            end

            -- evaluate timer
            if evalTimer >= config.evaluateInterval then
                evalTimer = 0.0

                -- check if over limit
                if overSustain >= config.sustainedSeconds then
                    FPSMonitor:handleFPSViolation(avgFPS) -- handle violation
                    overSustain = 0.0
                end
            end
        else
            sleep = 100
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