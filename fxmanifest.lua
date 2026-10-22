fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'JGR_Dealership'
author 'JGR Studio'
description 'JGR_Dealership - Concesionario con catálogo, prueba de manejo y panel de staff (QBCore · Qbox · ESX · Standalone)'
version '1.1.0'
jgr_version_key 'JGR_Dealership'
repository 'https://github.com/jgr-ry/JGR_Dealership'

shared_scripts {
    'config.lua',
    'bridge/shared.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/init.lua',
    'server/version_check.lua',
    'bridge/server.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*',
}

-- Solo oxmysql es obligatorio. El framework (qb-core, qbx_core, es_extended, ox_core)
-- se detecta en tiempo de ejecución; no se declara como dependencia a propósito.
dependencies {
    'oxmysql',
}

escrow_ignore {
    'config.lua',
}
