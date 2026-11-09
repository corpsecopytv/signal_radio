-- Build step 1 test commands. Dev server only.
-- Enable with: setr signal_radio_voice_proof 1
if GetConvarInt('signal_radio_voice_proof', 0) ~= 1 then return end

local pma = exports['pma-voice']

-- Starting values. Tune these by ear with real voices.
local submixes = {
	sr_full = { freq_low = 389.0, freq_hi = 3248.0, fudge = 0.0, rm_mod_freq = 0.0, rm_mix = 0.16, o_freq_lo = 348.0, o_freq_hi = 4900.0 },
	sr_worn = { freq_low = 500.0, freq_hi = 2600.0, fudge = 4.0, rm_mod_freq = 30.0, rm_mix = 0.30, o_freq_lo = 450.0, o_freq_hi = 3600.0 },
	sr_bad = { freq_low = 700.0, freq_hi = 1900.0, fudge = 12.0, rm_mod_freq = 90.0, rm_mix = 0.55, o_freq_lo = 650.0, o_freq_hi = 2500.0 },
}

local modes = { full = 'sr_full', worn = 'sr_worn', bad = 'sr_bad', mute = 'mute', near = 'near' }
local scanVolume = 0.6
local defaultRule = 'sr_full'
local talkerRules = {}
local resolverInstalled = false

local function say(message)
	print(('[voice_proof] %s'):format(message))
	TriggerEvent('chat:addMessage', { args = { 'voice_proof', message } })
end

local function registerSubmixes()
	for name, params in pairs(submixes) do
		local id = CreateAudioSubmix(name)
		SetAudioSubmixEffectRadioFx(id, 0)
		SetAudioSubmixEffectParamInt(id, 0, GetHashKey('default'), 1)
		for param, value in pairs(params) do
			SetAudioSubmixEffectParamFloat(id, 0, GetHashKey(param), value)
		end
		SetAudioSubmixOutputVolumes(id, 0, 1.0, 0.25, 0.0, 0.0, 1.0, 1.0)
		AddAudioSubmixOutput(id, 0)
		pma:registerCustomSubmix(function()
			return { name, id }
		end)
	end
end

CreateThread(registerSubmixes)
AddEventHandler('pma-voice:registerCustomSubmixes', registerSubmixes)

local function resolver(talker, listenerChannel)
	local rule = talkerRules[talker] or defaultRule
	if rule == 'mute' then return nil end
	if rule == 'near' then return { proximity = true } end
	return { submix = rule, volume = listenerChannel and scanVolume or 1.0 }
end

-- /vp_fx <full|worn|bad|mute|near|off> [talker server id]
RegisterCommand('vp_fx', function(_, args)
	local mode, talker = args[1], tonumber(args[2])
	if mode == 'off' then
		pma:setRadioAudioResolver(nil)
		resolverInstalled = false
		talkerRules = {}
		pma:refreshRadioAudio()
		return say('Resolver removed. pma-voice default audio is back.')
	end

	local rule = modes[mode]
	if not rule then return say('Use full, worn, bad, mute, near or off.') end
	if talker then talkerRules[talker] = rule else defaultRule, talkerRules = rule, {} end
	if not resolverInstalled then
		pma:setRadioAudioResolver(resolver)
		resolverInstalled = true
	end
	pma:refreshRadioAudio()
	say(('Rule %s applied to %s.'):format(rule, talker or 'all talkers'))
end, false)

RegisterNetEvent('pma-voice:radioListenerTalking', function(channel, talker, talking)
	say(('Channel %d: talker %d %s.'):format(channel, talker, talking and 'started' or 'stopped'))
end)

RegisterNetEvent('pma-voice:radioListenerActivity', function(channel, active)
	say(('Channel %d: ENC traffic %s, no talker identity sent.'):format(channel, active and 'started' or 'stopped'))
end)

-- Solo testing runs two clients on one PC. Only the focused window gets key presses,
-- so /vp_tx holds the radio key on a timer while you switch to the other window.
-- /vp_tx [seconds, default 10] [delay before keying, default 5]
local transmitting = false
RegisterCommand('vp_tx', function(_, args)
	if transmitting then return say('A timed transmission is already running.') end
	local seconds = math.max(1, math.min(60, tonumber(args[1]) or 10))
	local delay = math.max(0, math.min(30, tonumber(args[2]) or 5))
	transmitting = true
	say(('Transmitting for %d seconds, starting in %d seconds.'):format(seconds, delay))
	CreateThread(function()
		Wait(delay * 1000)
		ExecuteCommand('+radiotalk')
		say('Radio key down.')
		Wait(seconds * 1000)
		ExecuteCommand('-radiotalk')
		say('Radio key up.')
		transmitting = false
	end)
end, false)

-- Spots a and b are 150 metres apart, beyond every proximity range.
-- Spot c is 3 metres from a, for testing normal proximity voice.
local spots = {
	a = { -1336.0, -3044.0, 20.0 },
	b = { -1186.0, -3044.0, 20.0 },
	c = { -1333.0, -3044.0, 20.0 },
}

-- /vp_spot <a|b|c|off>
RegisterCommand('vp_spot', function(_, args)
	local ped = PlayerPedId()
	if args[1] == 'off' then
		FreezeEntityPosition(ped, false)
		return say('Released from the test spot.')
	end
	local spot = spots[args[1]]
	if not spot then return say('Use a, b, c or off.') end
	SetEntityCoordsNoOffset(ped, spot[1], spot[2], spot[3], false, false, false)
	FreezeEntityPosition(ped, true)
	say(('Moved to test spot %s and frozen in place.'):format(args[1]))
end, false)

-- /vp_goto <x> <y> [z]: moves you there and freezes you in place, for signal range tests.
RegisterCommand('vp_goto', function(_, args)
	local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3]) or 60.0
	if not x or not y then return say('Use /vp_goto <x> <y> [z].') end
	local ped = PlayerPedId()
	SetEntityCoordsNoOffset(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false)
	FreezeEntityPosition(ped, true)
	say(('Moved to %d, %d and frozen. /vp_spot off releases you.'):format(x, y))
end, false)

-- /vp_tower <id>: stands you on the ground beside a tower, for jammer tests.
RegisterCommand('vp_tower', function(_, args)
	local tower
	for _, candidate in ipairs(Radio.towers) do
		if candidate.id == args[1] then tower = candidate end
	end
	if not tower then return say('Unknown tower. /radio_tower list shows the ids.') end
	CreateThread(function()
		local ped = PlayerPedId()
		local x, y = tower.x + 1.5, tower.y
		FreezeEntityPosition(ped, true)
		SetEntityCoordsNoOffset(ped, x, y, tower.z + 50.0, false, false, false)
		local found, ground = false, tower.z
		for _ = 1, 100 do
			RequestCollisionAtCoord(x, y, tower.z)
			found, ground = GetGroundZFor_3dCoord(x, y, 1000.0, false)
			if found then break end
			Wait(50)
		end
		SetEntityCoordsNoOffset(ped, x, y, (found and ground or tower.z) + 1.0, false, false, false)
		FreezeEntityPosition(ped, false)
		say(('Moved beside tower %s.'):format(tower.id))
	end)
end, false)

-- /vp_call <call number, or 0 to leave>
RegisterCommand('vp_call', function(_, args)
	local call = tonumber(args[1])
	if not call then return say('Give a call number, or 0 to leave.') end
	pma:setCallChannel(call)
	say(('Call set to %d.'):format(call))
end, false)

-- /vp_watch <talker server id> reports when Mumble marks that talker as talking.
local watching = nil
RegisterCommand('vp_watch', function(_, args)
	local talker = tonumber(args[1])
	if not talker then
		watching = nil
		return say('Watch stopped.')
	end

	watching = talker
	say(('Watching talker %d. The talker must be in your OneSync scope.'):format(talker))
	CreateThread(function()
		local last = nil
		while watching == talker do
			local player = GetPlayerFromServerId(talker)
			local state = 'out of scope'
			if player ~= -1 then
				local value = MumbleIsPlayerTalking(player)
				state = (value == true or value == 1) and 'VOICE ARRIVING' or 'silent'
			end
			if state ~= last then
				say(('Talker %d: %s.'):format(talker, state))
				last = state
			end
			Wait(100)
		end
	end)
end, false)
