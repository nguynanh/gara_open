server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/parking_server.lua' -- Thêm dòng này
}

client_scripts {
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/EntityZone.lua',
    '@PolyZone/CircleZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/main.lua',
    'client/parking_client.lua' -- Thêm dòng này
}