local config = require 'configs.server'

local playerStrikes = {}

-- print strikes to server console
local function printStrikes(src, strikes)
    if not config.printStrikes then return end
    local message = strikes < config.strikesBeforeDrop and '^5%s^0 has ^5%s / %s^0 strikes for exceedig the FPS limit' or '^5%s^0 has been kicked with ^5%s / %s^0 strikes for exceedig the FPS limit'

    lib.print.info((message):format(GetPlayerName(src), strikes, config.strikesBeforeDrop))
end

-- strike player for exceeding the fps limit
RegisterNetEvent('xt-fpslock:server:strikePlayer', function()
    local src = source
    playerStrikes[src] = playerStrikes[src] ~= nil and playerStrikes[src] + 1 or 1

    printStrikes(src, playerStrikes[src])

    if playerStrikes[src] >= config.strikesBeforeDrop then
        DropPlayer(src, config.kickMessage)

        playerStrikes[src] = nil
    end
end)