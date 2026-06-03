fx_version 'cerulean'
game 'gta5'

author 'abhinandtrade-oss'
description 'Premium Telecom Authority - Custom Mobile Numbers for QB-Core'
version '1.0.0'

dependencies {
    'oxmysql'
}

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}


ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
