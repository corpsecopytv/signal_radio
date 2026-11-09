--- Resolves a profile into the zones and talkgroups that radio can use.
--- @return table|nil codeplug
function BuildCodeplug(profile)
	local definition = Config.Codeplugs[profile.department]
	if not definition then return nil end

	local codeplug = { skin = definition.skin, zones = {}, talkgroups = {}, scan = {} }
	for _, zoneId in ipairs(definition.zones) do
		local zone = ZonesById[zoneId]
		local entries = {}
		for _, talkgroupId in ipairs(zone.talkgroups) do
			local talkgroup = TalkgroupsById[talkgroupId]
			if profile.senior or not talkgroup.seniorOnly then
				entries[#entries + 1] = { id = talkgroup.id, label = talkgroup.label }
				codeplug.talkgroups[talkgroup.id] = true
			end
		end
		codeplug.zones[#codeplug.zones + 1] = { id = zone.id, label = zone.label, talkgroups = entries }
	end
	for _, talkgroupId in ipairs(definition.scan) do
		if codeplug.talkgroups[talkgroupId] then
			codeplug.scan[talkgroupId] = true
		end
	end
	return codeplug
end

function BuildCivilianCodeplug()
	return { skin = Config.Civilian.skin, civilian = true, zones = {}, talkgroups = {}, scan = {} }
end

function IsFrequencyAllowed(frequency)
	if type(frequency) ~= 'number' or frequency % 1 ~= 0 then return false end
	for _, band in ipairs(Config.Civilian.bands) do
		if frequency >= band[1] and frequency <= band[2] then return true end
	end
	return false
end

function CanUseTalkgroup(source, talkgroupId)
	local session = Sessions[source]
	return session ~= nil and session.codeplug.talkgroups[talkgroupId] == true
end

function HasPriority(session)
	return session.priority or GetGameTimer() < session.panicUntil
end
