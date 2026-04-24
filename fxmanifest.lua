fx_version 'cerulean'
game 'gta5'

author 'JGR Studio'
description 'JGR_Dealership'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/init.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*',
    'sql/jgr_dealership.sql',
}

escrow_ignore {
    'config.lua',
}

lua54 'yes'
