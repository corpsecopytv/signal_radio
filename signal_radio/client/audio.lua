local pma = exports['pma-voice']

-- Starting values. Tune these by ear with real voices.
local SUBMIX_PARAMS = {
	sr_full = { freq_low = 389.0, freq_hi = 3248.0, fudge = 0.0, rm_mod_freq = 0.0, rm_mix = 0.16, o_freq_lo = 348.0, o_freq_hi = 4900.0 },
	sr_worn = { freq_low = 500.0, freq_hi = 2600.0, fudge = 4.0, rm_mod_freq = 30.0, rm_mix = 0.30, o_freq_lo = 450.0, o_freq_hi = 3600.0 },
	sr_bad = { freq_low = 700.0, freq_hi = 1900.0, fudge = 12.0, rm_mod_freq = 90.0, rm_mix = 0.55, o_freq_lo = 650.0, o_freq_hi = 2500.0 },
}
local SUBMIX_FOR_TIER = { full = 'sr_full', worn = 'sr_worn', bad = 'sr_bad' }
local TIER_RANK = { full = 3, worn = 2, bad = 1, none = 0 }

local function registerSubmixes()
	for name, params in pairs(SUBMIX_PARAMS) do
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

local function isTalkerInSimplexRange(talker, talkgroup)
	local player = GetPlayerFromServerId(talker)
	if player == -1 then return false end
	local there = GetEntityCoords(GetPlayerPed(player))
	local here = GetEntityCoords(PlayerPedId())
	return #(here - there) <= talkgroup.range
end

--- Decides how each radio talker sounds. Returning nil mutes the talker.
local function resolveRadioAudio(talker, listenerChannel)
	local talkgroup = GetRadioTalkgroup(listenerChannel)
	local volume = listenerChannel and Config.ScanVolume or 1.0
	if talkgroup and talkgroup.simplex then
		if not isTalkerInSimplexRange(talker, talkgroup) then return nil end
		return { submix = 'sr_full', volume = volume }
	end

	local talkerTier = Radio.talkerSignal[talker] or 'full'
	local tier = TIER_RANK[talkerTier] < TIER_RANK[Radio.signal] and talkerTier or Radio.signal
	if tier == 'none' then return nil end
	return { submix = SUBMIX_FOR_TIER[tier], volume = volume }
end

AddEventHandler('pma-voice:registerCustomSubmixes', registerSubmixes)

CreateThread(function()
	registerSubmixes()
	pma:setRadioAudioResolver(resolveRadioAudio)
end)
