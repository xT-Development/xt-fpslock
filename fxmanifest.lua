fx_version 'cerulean'
game 'gta5'
use_experimental_fxv2_oal 'yes'
lua54 'yes'

author 'xT Development'
description 'FPS Limiter'

shared_scripts { '@ox_lib/init.lua' }

client_scripts {
    'configs/client.lua',
    'client/*.lua'
}

server_scripts {
    'configs/server.lua',
    'server/*.lua'
}