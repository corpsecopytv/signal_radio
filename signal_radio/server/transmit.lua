-- Talkers[talkgroupId][source] = true for everyone granted the air.
Talkers = {}

local VALID_SIGNAL = { full = true, worn = true, bad = true, none = true }

function ForEachTalkgroupTarget(talkgroupId, callback)
	for source in pairs(TalkgroupMembers[talkgroupId] or {}) do
		callback(source)
	end
	for source in pairs(TalkgroupScanners[talkgroupId] or {}) do
		callback(source)
	end
end

local function broadcastTalk(talkgroupId, session, talking)
	ForEachTalkgroupTarget(talkgroupId, function(target)
		TriggerClientEvent('signal_radio:talk', target, talkgroupId, session.source, session.callsign, talking, session.signal)
	end)
end

local function removeTalker(talkgroupId, source)
	Talkers[talkgroupId][source] = nil
	if next(Talkers[talkgroupId]) == nil then
		Talkers[talkgroupId] = nil
	end
end

function ClearTalker(session)
	local talkgroupId = session.talkgroup
	if talkgroupId and Talkers[talkgroupId] and Talkers[talkgroupId][session.source] then
		removeTalker(talkgroupId, session.source)
		broadcastTalk(talkgroupId, session, false)
	end
end

--- Tells a player who joined late about transmissions already in progress.
function SendActiveTalkers(target, talkgroupId)
	for source in pairs(Talkers[talkgroupId] or {}) do
		local session = Sessions[source]
		TriggerClientEvent('signal_radio:talk', target, talkgroupId, source, session.callsign, true, session.signal)
	end
end

local function isSimplex(talkgroupId)
	local talkgroup = TalkgroupsById[talkgroupId]
	return talkgroup ~= nil and talkgroup.simplex == true
end

RegisterNetEvent('pma-voice:setTalkingOnRadio')
AddEventHandler('pma-voice:setTalkingOnRadio', function(talking)
	local source = source
	local session = Sessions[source]
	if not session or not session.power or not session.talkgroup then return end
	local talkgroupId = session.talkgroup
	local talkers = Talkers[talkgroupId]

	if talking == true then
		if talkers and talkers[source] then return end
		if session.signal == 'none' and not isSimplex(talkgroupId) then
			return TriggerClientEvent('signal_radio:txDenied', source, 'no_signal')
		end
		if talkers and not HasPriority(session) then
			return TriggerClientEvent('signal_radio:txDenied', source, 'busy')
		end
		Talkers[talkgroupId] = talkers or {}
		Talkers[talkgroupId][source] = true
		broadcastTalk(talkgroupId, session, true)
	elseif talkers and talkers[source] then
		removeTalker(talkgroupId, source)
		broadcastTalk(talkgroupId, session, false)
	end
end)

-- Clients report their signal tier when it changes, so receivers can match the audio.
RegisterNetEvent('signal_radio:signal', function(tier)
	local source = source
	local session = Sessions[source]
	if not session or not VALID_SIGNAL[tier] then return end
	session.signal = tier
	local talkgroupId = session.talkgroup
	if talkgroupId and Talkers[talkgroupId] and Talkers[talkgroupId][source] then
		broadcastTalk(talkgroupId, session, true)
	end
end)
