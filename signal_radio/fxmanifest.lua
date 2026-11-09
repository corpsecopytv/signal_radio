fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'signal_radio'
description 'Radio system for the Apex Network FiveM server'
version '0.3.0'

dependency 'pma-voice'

shared_scripts {
	'config/talkgroups.lua',
	'config/codeplugs.lua',
	'config/towers.lua',
}

server_scripts {
	'server/bridge.lua',
	'server/registry.lua',
	'server/permissions.lua',
	'server/radio.lua',
	'server/transmit.lua',
	'server/towers.lua',
	'server/bleed.lua',
	'server/voice_proof.lua',
}

client_scripts {
	'client/radio.lua',
	'client/ptt.lua',
	'client/audio.lua',
	'client/signal.lua',
	'client/towers.lua',
	'client/voice_proof.lua',
}

ui_page 'web/handset/index.html'

files {
	'web/handset/index.html',
	'web/handset/style.css',
	'web/handset/app.js',
	'web/handset/mock.js',
	'web/handset/skin.js',
	'web/handset/skins/*',
}
