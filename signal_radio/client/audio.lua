local pma = Pma

-- Starting values. Tune these by ear with real voices.
local SUBMIX_PARAMS = {
	sr_near = { freq_low = 250.0, freq_hi = 5000.0, fudge = 0.0, rm_mod_freq = 0.0, rm_mix = 0.05, o_freq_lo = 200.0, o_freq_hi = 7000.0 },
	sr_full = { freq_low = 389.0, freq_hi = 3248.0, fudge = 0.0, rm_mod_freq = 0.0, rm_mix = 0.16, o_freq_lo = 348.0, o_freq_hi = 4900.0 },
	sr_worn = { freq_low = 500.0, freq_hi = 2600.0, fudge = 4.0, rm_mod_freq = 30.0, rm_mix = 0.30, o_freq_lo = 450.0, o_freq_hi = 3600.0 },
	sr_bad = { freq_low = 700.0, freq_hi = 1900.0, fudge = 12.0, rm_mod_freq = 90.0, rm_mix = 0.55, o_freq_lo = 650.0, o_freq_hi = 2500.0 },
	sr_bleed = { freq_low = 500.0, freq_hi = 2200.0, fudge = 2.0, rm_mod_freq = 0.0, rm_mix = 0.20, o_freq_lo = 400.0, o_freq_hi = 2600.0 },
}
local SUBMIX_FOR_TIER = { near = 'sr_near', full = 'sr_full', worn = 'sr_worn', bad = 'sr_bad' }
local TIER_RANK = { near = 4, full = 3, worn = 2, bad = 1, none = 0 }

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

--- The game only streams nearby players, so the server supplies the distance for players further away.
--- @return number|nil distance nil when the distance is unknown
local function distanceToTalker(talker)
	local player = GetPlayerFromServerId(talker)
	if player == -1 then return Radio.talkerDistance[talker] end
	return #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(GetPlayerPed(player)))
end

--- Direct radio uses the same quality rules as a tower, across directRange.
local function directTier(distance)
	if not distance then return 'none' end
	if distance <= Config.Signal.nearClearRange then return 'near' end
	local quality = 1.0 - distance / Config.Signal.directRange
	if quality >= Config.Signal.fullQuality then return 'full' end
	if quality >= Config.Signal.wornQuality then return 'worn' end
	if quality > 0.0 then return 'bad' end
	return 'none'
end

local function better(first, second)
	return TIER_RANK[first] >= TIER_RANK[second] and first or second
end

--- @return string tier the best working link to this talker
local function linkTier(talker, talkgroup)
	local distance = distanceToTalker(talker)
	if talkgroup and talkgroup.simplex then
		if not distance or distance > talkgroup.range then return 'none' end
		return distance <= Config.Signal.nearClearRange and 'near' or 'full'
	end
	local talkerTier = Radio.talkerSignal[talker] or 'full'
	local towerTier = TIER_RANK[talkerTier] < TIER_RANK[Radio.signal] and talkerTier or Radio.signal
	return better(towerTier, directTier(distance))
end

--- Decides how each radio talker sounds. Returning nil mutes the talker.
local function resolveRadioAudio(talker, listenerChannel)
	local bleedVolume = listenerChannel and Radio.bleed[listenerChannel]
	if bleedVolume then
		local distance = distanceToTalker(talker)
		if distance and distance <= Config.Bleed.naturalVoiceRange then
			return { proximity = true }
		end
		return { submix = 'sr_bleed', volume = bleedVolume }
	end

	local tier = linkTier(talker, GetRadioTalkgroup(listenerChannel))
	if tier == 'none' then return nil end
	return { submix = SUBMIX_FOR_TIER[tier], volume = listenerChannel and Config.ScanVolume or 1.0 }
end

function IsTalkerAudible(talker)
	return linkTier(talker, GetRadioTalkgroup(nil)) ~= 'none'
end

AddEventHandler('pma-voice:registerCustomSubmixes', registerSubmixes)

CreateThread(function()
	registerSubmixes()
	pma:setRadioAudioResolver(resolveRadioAudio)
end)
