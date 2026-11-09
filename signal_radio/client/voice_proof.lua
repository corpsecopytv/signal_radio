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
