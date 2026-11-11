local pma = exports['pma-voice']

Sessions = {}
TalkgroupMembers = {}
TalkgroupScanners = {}

local function identifierFor(source)
	return GetPlayerIdentifierByType(source, 'license')
end

local function callsignFor(source, profile)
	if profile and profile.callsign then return profile.callsign end
	local license = identifierFor(source)
	local saved = license and GetResourceKvpString(('callsign:%s'):format(license))
	return saved or ('Unit %d'):format(source)
end

local function profileKeyFor(profile)
	return profile and ('%s:%s'):format(profile.department, profile.senior == true) or 'none'
end

local function scanListToArray(scanList)
	local ids = {}
	for id in pairs(scanList) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

--- Uses the player's saved scan choices, or the codeplug's starting list if none are saved.
local function loadScanList(codeplug, key)
	local saved = key and GetResourceKvpString(key)
	local scanList = {}
	if saved then
		for id in saved:gmatch('[^,]+') do
			if codeplug.talkgroups[id] then
				scanList[id] = true
			end
		end
	else
		for id in pairs(codeplug.scan) do
			scanList[id] = true
		end
	end
	return scanList
end

function SendState(source)
	local session = Sessions[source]
	if not session then
		return TriggerClientEvent('signal_radio:state', source, { available = false, needsPatch = not PmaPatched })
	end
	TriggerClientEvent('signal_radio:state', source, {
		available = true,
		power = session.power,
		civilian = session.codeplug.civilian == true,
		tuning = session.mode == 'frequency',
		frequency = session.frequency,
		bands = Config.Civilian.bands,
		stepKHz = Config.Civilian.stepKHz,
		skin = session.codeplug.skin,
		zones = session.codeplug.zones,
		talkgroup = session.talkgroup,
		scanning = session.scanning,
		canScan = not session.codeplug.civilian,
		scanList = scanListToArray(session.scanList),
		callsign = session.callsign,
		priority = session.priority,
	})
end

local function broadcastMembers(talkgroupId)
	if not talkgroupId then return end
	local members = {}
	for source in pairs(TalkgroupMembers[talkgroupId] or {}) do
		members[#members + 1] = { id = source, callsign = Sessions[source].callsign }
	end
	table.sort(members, function(a, b) return a.callsign < b.callsign end)
	for source in pairs(TalkgroupMembers[talkgroupId] or {}) do
		TriggerClientEvent('signal_radio:members', source, talkgroupId, members)
	end
end

local function setSetMember(sets, talkgroupId, source, present)
	sets[talkgroupId] = sets[talkgroupId] or {}
	sets[talkgroupId][source] = present or nil
	if next(sets[talkgroupId]) == nil then
		sets[talkgroupId] = nil
	end
end

local function syncScan(session)
	local source = session.source
	local wanted = {}
	if session.power and session.scanning and session.mode == 'zone' then
		for talkgroupId in pairs(session.scanList) do
			if talkgroupId ~= session.talkgroup then
				wanted[talkgroupId] = true
			end
		end
	end
	for talkgroupId in pairs(session.listening) do
		if not wanted[talkgroupId] then
			pma:removeRadioListener(source, TalkgroupsById[talkgroupId].channel)
			session.listening[talkgroupId] = nil
			setSetMember(TalkgroupScanners, talkgroupId, source, false)
			ForgetBleedListener(talkgroupId, source)
			SendTalkersStopped(source, talkgroupId)
		end
	end
	for talkgroupId in pairs(wanted) do
		if not session.listening[talkgroupId] and pma:addRadioListener(source, TalkgroupsById[talkgroupId].channel, true) then
			session.listening[talkgroupId] = true
			setSetMember(TalkgroupScanners, talkgroupId, source, true)
			SendActiveTalkers(source, talkgroupId)
		end
	end
end

local function leaveTalkgroup(session)
	local current = session.talkgroup
	if not current or not (TalkgroupMembers[current] or {})[session.source] then return end
	ClearTalker(session)
	SendTalkersStopped(session.source, current)
	setSetMember(TalkgroupMembers, current, session.source, false)
	broadcastMembers(current)
end

local function joinTalkgroup(session, talkgroupId)
	local source = session.source
	local talkgroup = TalkgroupsById[talkgroupId]
	if not talkgroup or not CanUseTalkgroup(source, talkgroupId) then return false end

	leaveTalkgroup(session)
	session.talkgroup = talkgroupId
	pma:setPlayerRadio(source, talkgroup.channel)
	if Player(source).state.radioChannel ~= talkgroup.channel then return false end

	setSetMember(TalkgroupMembers, talkgroupId, source, true)
	syncScan(session)
	broadcastMembers(talkgroupId)
	-- The radio must know its new channel before it hears who is already talking.
	SendState(source)
	SendActiveTalkers(source, talkgroupId)
	return true
end

local function stopEncryptedListen(session)
	if session.encryptedChannel then
		pma:removeRadioListener(session.source, session.encryptedChannel)
		session.encryptedChannel = nil
	end
end

--- Tunes a radio in frequency mode. A clear frequency joins other players on it.
--- An emergency frequency joins the talkgroup if the radio can use it.
--- Otherwise it gives talk activity only, so the radio plays noise and receives no voice.
local function tuneFrequency(session, frequency)
	local source = session.source
	leaveTalkgroup(session)
	stopEncryptedListen(session)
	session.frequency = frequency
	session.talkgroup = nil
	syncScan(session)
	if not session.power then return end

	local emergency = TalkgroupsByFrequency[frequency]
	if emergency and CanUseTalkgroup(source, emergency.id) then
		joinTalkgroup(session, emergency.id)
		return
	end
	if emergency then
		pma:setPlayerRadio(source, 0)
		SendState(source)
		if pma:addRadioListener(source, emergency.channel, false) then
			session.encryptedChannel = emergency.channel
		end
		return
	end

	pma:setPlayerRadio(source, frequency)
	if Player(source).state.radioChannel ~= frequency then return end
	local id = ('freq:%d'):format(frequency)
	session.talkgroup = id
	setSetMember(TalkgroupMembers, id, source, true)
	broadcastMembers(id)
	SendState(source)
	SendActiveTalkers(source, id)
end

local function powerOff(session, dropped)
	if not session.power then return end
	leaveTalkgroup(session)
	stopEncryptedListen(session)
	session.power = false
	syncScan(session)
	if not dropped then
		pma:setPlayerRadio(session.source, 0)
	end
end

local function firstTalkgroup(codeplug)
	for _, zone in ipairs(codeplug.zones) do
		if zone.talkgroups[1] then return zone.talkgroups[1].id end
	end
	return nil
end

--- Rebuilds a player's radio from their current profile.
function RefreshSession(source)
	local existing = Sessions[source]
	-- Clients only report signal changes, so a rebuilt session must keep the last value.
	local previousSignal = existing and existing.signal or 'full'
	if existing then
		powerOff(existing)
		Sessions[source] = nil
	end

	local profile = GetRadioProfile(source)
	local codeplug = profile and BuildCodeplug(profile) or nil
	if not codeplug or not firstTalkgroup(codeplug) then
		codeplug = BuildCivilianCodeplug()
	end
	local license = identifierFor(source)
	local scanKey = not codeplug.civilian and license and ('scan:%s:%s'):format(license, profile.department) or nil
	if PmaPatched and canUseRadio(source) then
		Sessions[source] = {
			source = source,
			codeplug = codeplug,
			power = false,
			talkgroup = firstTalkgroup(codeplug),
			mode = codeplug.civilian and 'frequency' or 'zone',
			frequency = Config.Civilian.defaultFrequency,
			scanning = false,
			signal = previousSignal,
			scanKey = scanKey,
			scanList = loadScanList(codeplug, scanKey),
			listening = {},
			callsign = callsignFor(source, profile),
			mdtCallsign = profile ~= nil and profile.callsign ~= nil,
			profileKey = profileKeyFor(profile),
			department = profile and profile.department or nil,
			priority = IsPlayerAceAllowed(source, 'radio.priority'),
			lastPanic = nil,
			panicUntil = 0,
			lastManDown = nil,
		}
	end
	SendState(source)
end

--- Applies the latest Night Shifts read to a player's radio.
--- A new department or the end of a shift rebuilds the radio. A new callsign does not.
function ApplyRadioProfile(source, profile)
	local session = Sessions[source]
	if not session then return end
	if session.profileKey ~= profileKeyFor(profile) then
		return RefreshSession(source)
	end
	session.mdtCallsign = profile ~= nil and profile.callsign ~= nil
	if session.mdtCallsign and session.callsign ~= profile.callsign then
		session.callsign = profile.callsign
		broadcastMembers(session.talkgroup)
		SendState(source)
	end
end

RegisterNetEvent('signal_radio:hello', function()
	local source = source
	if Sessions[source] then
		SendState(source)
	else
		RefreshSession(source)
	end
end)

RegisterNetEvent('signal_radio:setPower', function(on)
	local source = source
	local session = Sessions[source]
	if not session then return end
	if on == true and not session.power then
		session.power = true
		if session.mode == 'frequency' then
			tuneFrequency(session, session.frequency)
		elseif not joinTalkgroup(session, session.talkgroup) then
			session.power = false
		end
	elseif on ~= true then
		powerOff(session)
	end
	SendState(source)
end)

RegisterNetEvent('signal_radio:selectTalkgroup', function(talkgroupId)
	local source = source
	local session = Sessions[source]
	if not session or type(talkgroupId) ~= 'string' or not CanUseTalkgroup(source, talkgroupId) then return end
	-- Choosing a talkgroup takes an emergency radio out of frequency mode.
	if session.mode == 'frequency' then
		stopEncryptedListen(session)
		session.mode = 'zone'
	end
	if session.power then
		joinTalkgroup(session, talkgroupId)
	else
		session.talkgroup = talkgroupId
	end
	SendState(source)
end)

RegisterNetEvent('signal_radio:tune', function(frequency)
	local source = source
	local session = Sessions[source]
	if not session or session.mode ~= 'frequency' or not IsFrequencyAllowed(frequency) then return end
	tuneFrequency(session, frequency)
	SendState(source)
end)

RegisterNetEvent('signal_radio:useFrequencyMode', function()
	local source = source
	local session = Sessions[source]
	if not session or session.mode == 'frequency' then return end
	session.mode = 'frequency'
	tuneFrequency(session, session.frequency)
	SendState(source)
end)

RegisterNetEvent('signal_radio:setScan', function(enabled)
	local source = source
	local session = Sessions[source]
	if not session or session.codeplug.civilian then return end
	session.scanning = enabled == true
	syncScan(session)
	SendState(source)
end)

RegisterNetEvent('signal_radio:setScanTalkgroup', function(talkgroupId, enabled)
	local source = source
	local session = Sessions[source]
	if not session or type(talkgroupId) ~= 'string' or not CanUseTalkgroup(source, talkgroupId) then return end
	session.scanList[talkgroupId] = enabled == true or nil
	if session.scanKey then
		-- A lone comma saves an empty choice, so it is not mistaken for no saved choice.
		local saved = table.concat(scanListToArray(session.scanList), ',')
		SetResourceKvp(session.scanKey, saved ~= '' and saved or ',')
	end
	syncScan(session)
	SendState(source)
end)

--- Sends a panic to everyone on the radio's channel.
--- @return boolean sent false during the panic cooldown
local function sendRadioPanic(session)
	local now = GetGameTimer()
	if session.lastPanic and now - session.lastPanic < Config.PanicCooldownMs then
		return false
	end
	session.lastPanic = now
	session.panicUntil = now + Config.PanicPriorityMs

	local talkgroupId = session.talkgroup
	local talkgroup = TalkgroupsById[talkgroupId]
	local label = talkgroup and talkgroup.label or ('%.3f'):format(session.frequency / 1000)
	ForEachTalkgroupTarget(talkgroupId, function(target)
		TriggerClientEvent('signal_radio:panic', target, talkgroupId, label, session.callsign, session.source)
	end)
	return true
end

RegisterNetEvent('signal_radio:panic', function()
	local source = source
	local session = Sessions[source]
	if not session or not session.power or session.codeplug.civilian then return end
	if not session.talkgroup then
		return TriggerClientEvent('signal_radio:panicRefused', source, 'no_channel')
	end
	if not sendRadioPanic(session) then
		return TriggerClientEvent('signal_radio:panicRefused', source)
	end
	SendMdtPanic(source)
end)

--- Plays a panic that started on the MDT. A radio that is off or on no channel stays silent.
function SendRadioPanicFromMdt(source)
	local session = Sessions[source]
	if session and session.power and session.talkgroup and not session.codeplug.civilian then
		sendRadioPanic(session)
	end
end

RegisterNetEvent('signal_radio:manDown', function()
	local source = source
	local session = Sessions[source]
	if not session or not session.power or session.codeplug.civilian then return end
	if GetEntityHealth(GetPlayerPed(source)) > 100 then return end

	local now = GetGameTimer()
	if session.lastManDown and now - session.lastManDown < Config.NightShifts.manDown.cooldownMs then return end
	if SendMdtManDown(source, session.callsign) then
		session.lastManDown = now
	end
end)

RegisterCommand('callsign', function(source, args)
	local session = Sessions[source]
	local license = source ~= 0 and identifierFor(source)
	if not license then return end
	if session and session.mdtCallsign then
		return TriggerClientEvent('chat:addMessage', source, { args = { 'Radio', 'Your callsign comes from the MDT while you are on shift.' } })
	end
	local callsign = table.concat(args, ' '):gsub('[^%w%- ]', ''):sub(1, 12)
	if callsign == '' then return end

	SetResourceKvp(('callsign:%s'):format(license), callsign)
	if session then
		session.callsign = callsign
		broadcastMembers(session.talkgroup)
		SendState(source)
	end
end, false)

AddEventHandler('playerDropped', function()
	local source = source
	local session = Sessions[source]
	if session then
		powerOff(session, true)
		Sessions[source] = nil
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then return end
	for source in pairs(Sessions) do
		pma:setPlayerRadio(source, 0)
	end
end)
