local pma = exports['pma-voice']

-- bleeding[talkgroupId][source] = the volume last sent to that bystander.
local bleeding = {}

-- The game streams players up to about 424 metres away. Past this, clients need the server's distance.
local SEND_DISTANCE_BEYOND = 300.0
local VOLUME_CHANGE_TO_SEND = 0.05

local function distanceBetween(a, b)
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function channelOf(talkgroupId)
	local talkgroup = TalkgroupsById[talkgroupId]
	if talkgroup then return talkgroup.channel end
	return tonumber(talkgroupId:match('^freq:(%d+)$'))
end

function CanRadioReceive(talker, receiver, talkgroup, distance)
	if talkgroup and talkgroup.simplex then return distance <= talkgroup.range end
	if distance < Config.Signal.directRange then return true end
	return talker.signal ~= 'none' and receiver.signal ~= 'none'
end

--- @return number distance between two players, or math.huge when either has no ped
function RadioDistance(first, second)
	local firstPed, secondPed = GetPlayerPed(first), GetPlayerPed(second)
	if not firstPed or firstPed == 0 or not secondPed or secondPed == 0 then return math.huge end
	return distanceBetween(GetEntityCoords(firstPed), GetEntityCoords(secondPed))
end

local function hasOwnRadioAudio(talkgroupId, source)
	return (TalkgroupMembers[talkgroupId] or {})[source] or (TalkgroupScanners[talkgroupId] or {})[source]
end

--- @return table positions of every radio that can receive this talkgroup's current talkers
local function findReceivingRadios(talkgroupId, positions)
	local radios = {}
	local talkgroup = TalkgroupsById[talkgroupId]
	ForEachTalkgroupTarget(talkgroupId, function(target)
		local receiver = Sessions[target]
		local here = positions[target]
		if not receiver or not here or Talkers[talkgroupId][target] then return end
		local receives = false
		for talkerId in pairs(Talkers[talkgroupId]) do
			local there = positions[talkerId]
			if there then
				local distance = distanceBetween(here, there)
				if distance > SEND_DISTANCE_BEYOND then
					TriggerClientEvent('signal_radio:talkerDistance', target, talkerId, distance)
				end
				receives = receives or CanRadioReceive(Sessions[talkerId], receiver, talkgroup, distance)
			end
		end
		if receives then
			radios[#radios + 1] = { position = here, bucket = GetPlayerRoutingBucket(target) }
		end
	end)
	-- Set only by the dev command /vp_bleedtest, because one person cannot be three players.
	if BleedTestRadio then
		radios[#radios + 1] = { position = BleedTestRadio }
	end
	return radios
end

local function bleedVolume(distance)
	local volume = Config.Bleed.maxVolume * (1.0 - distance / Config.Bleed.range)
	return math.max(Config.Bleed.minVolume, math.floor(volume * 100 + 0.5) / 100)
end

--- @return table bystanders by source, each with the volume of the nearest receiving radio
local function findBystanders(talkgroupId, channel, radios, positions)
	local wanted = {}
	for source, here in pairs(positions) do
		local session = Sessions[source]
		local onThisEncryptedChannel = session and session.encryptedChannel == channel
		if not hasOwnRadioAudio(talkgroupId, source) and not onThisEncryptedChannel then
			local nearest = nil
			local bucket = GetPlayerRoutingBucket(source)
			for _, radio in ipairs(radios) do
				if radio.bucket == nil or radio.bucket == bucket then
					local distance = distanceBetween(here, radio.position)
					if not nearest or distance < nearest then nearest = distance end
				end
			end
			if nearest and nearest <= Config.Bleed.range then
				wanted[source] = bleedVolume(nearest)
			end
		end
	end
	return wanted
end

local function releaseBystander(talkgroupId, channel, source)
	-- A player who now hears this on their own radio, or plays its encrypted noise, keeps that listener.
	local session = Sessions[source]
	local keepsNoiseListener = session and session.encryptedChannel == channel
	if not hasOwnRadioAudio(talkgroupId, source) and not keepsNoiseListener then
		pma:removeRadioListener(source, channel)
	end
	TriggerClientEvent('signal_radio:bleed', source, channel, nil)
	bleeding[talkgroupId][source] = nil
end

--- Call when another feature removes this player's listener, so bleed can add it again.
function ForgetBleedListener(talkgroupId, source)
	if bleeding[talkgroupId] then
		bleeding[talkgroupId][source] = nil
	end
end

local function stopBleed(talkgroupId)
	local channel = channelOf(talkgroupId)
	for source in pairs(bleeding[talkgroupId]) do
		releaseBystander(talkgroupId, channel, source)
	end
	bleeding[talkgroupId] = nil
end

local function updateTalkgroup(talkgroupId, positions)
	local channel = channelOf(talkgroupId)
	local radios = findReceivingRadios(talkgroupId, positions)
	local wanted = findBystanders(talkgroupId, channel, radios, positions)
	bleeding[talkgroupId] = bleeding[talkgroupId] or {}
	local current = bleeding[talkgroupId]

	for source in pairs(current) do
		if not wanted[source] then
			releaseBystander(talkgroupId, channel, source)
		end
	end
	for source, volume in pairs(wanted) do
		if not current[source] then
			TriggerClientEvent('signal_radio:bleed', source, channel, volume)
			if pma:addRadioListener(source, channel, true) then
				current[source] = volume
			else
				TriggerClientEvent('signal_radio:bleed', source, channel, nil)
			end
		elseif math.abs(current[source] - volume) >= VOLUME_CHANGE_TO_SEND then
			TriggerClientEvent('signal_radio:bleed', source, channel, volume)
			current[source] = volume
		end
	end
	if next(current) == nil then
		bleeding[talkgroupId] = nil
	end
end

--- Runs only while there is radio traffic or a bystander to clean up.
function TickBleed()
	if next(Talkers) == nil and next(bleeding) == nil then return end
	local positions = {}
	for _, player in ipairs(GetPlayers()) do
		local source = tonumber(player)
		local ped = GetPlayerPed(source)
		if ped and ped ~= 0 then
			positions[source] = GetEntityCoords(ped)
		end
	end
	for talkgroupId in pairs(Talkers) do
		updateTalkgroup(talkgroupId, positions)
	end
	for talkgroupId in pairs(bleeding) do
		if not Talkers[talkgroupId] then
			stopBleed(talkgroupId)
		end
	end
end

CreateThread(function()
	while true do
		Wait(Config.Bleed.updateMs)
		TickBleed()
	end
end)
