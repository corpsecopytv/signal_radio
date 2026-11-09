TalkgroupsById = {}
ZonesById = {}
TalkgroupsByFrequency = {}

for _, talkgroup in ipairs(Config.Talkgroups) do
	assert(not TalkgroupsById[talkgroup.id], ('Duplicate talkgroup id: %s'):format(talkgroup.id))
	assert(not TalkgroupsByFrequency[talkgroup.frequency], ('Duplicate frequency: %s'):format(talkgroup.frequency))
	TalkgroupsById[talkgroup.id] = talkgroup
	TalkgroupsByFrequency[talkgroup.frequency] = talkgroup
end

for _, zone in ipairs(Config.Zones) do
	ZonesById[zone.id] = zone
	for _, talkgroupId in ipairs(zone.talkgroups) do
		assert(TalkgroupsById[talkgroupId], ('Zone %s has unknown talkgroup %s'):format(zone.id, talkgroupId))
	end
end

-- pma-voice only checks access when a player joins, so every mapped channel needs a check.
CreateThread(function()
	for id, talkgroup in pairs(TalkgroupsById) do
		exports['pma-voice']:addChannelCheck(talkgroup.channel, function(source)
			return CanUseTalkgroup(source, id)
		end)
	end
end)
