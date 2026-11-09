-- Talkers[talkgroupId][source] = true for everyone granted the air.
Talkers = {}

function ForEachTalkgroupTarget(talkgroupId, callback)
	for source in pairs(TalkgroupMembers[talkgroupId] or {}) do
		callback(source)
	end
	for source in pairs(TalkgroupScanners[talkgroupId] or {}) do
		callback(source)
	end
end

local function broadcastTalk(talkgroupId, talker, callsign, talking)
	ForEachTalkgroupTarget(talkgroupId, function(target)
		TriggerClientEvent('signal_radio:talk', target, talkgroupId, talker, callsign, talking)
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
		broadcastTalk(talkgroupId, session.source, session.callsign, false)
	end
end

--- Tells a player who joined late about transmissions already in progress.
function SendActiveTalkers(target, talkgroupId)
	for source in pairs(Talkers[talkgroupId] or {}) do
		TriggerClientEvent('signal_radio:talk', target, talkgroupId, source, Sessions[source].callsign, true)
	end
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
		if talkers and not HasPriority(session) then
			return TriggerClientEvent('signal_radio:txDenied', source)
		end
		Talkers[talkgroupId] = talkers or {}
		Talkers[talkgroupId][source] = true
		broadcastTalk(talkgroupId, source, session.callsign, true)
	elseif talkers and talkers[source] then
		removeTalker(talkgroupId, source)
		broadcastTalk(talkgroupId, source, session.callsign, false)
	end
end)
