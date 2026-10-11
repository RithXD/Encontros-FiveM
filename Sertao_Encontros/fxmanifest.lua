fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ORichard'
description 'Sistema de encontros para QBCore'
version '3.0.0'

ui_page 'nui/ui.html'

files {
    'nui/ui.html',
    'nui/style.css',
    'nui/app.js',
    'nui/Fueltecson.png',
    'nui/Fueltecson_Nome.png',
}

shared_scripts {
    'shared/reward_policy.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/attendance.lua',
    'server/schema.lua',
    'server/main.lua',
}

dependencies {
    'qb-core',
    'qb-inventory',
    'qb-target',
    'oxmysql',
}
