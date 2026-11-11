-- The radio admin panel. Every request checks the radio.admin ACE here on the server.

local refusalLogged = {}

local function isAdmin(source)
	return IsPlayerAceAllowed(source, 'radio.admin')
end

AddEventHandler('playerDropped', function()
	refusalLogged[source] = nil
end)

local function playerRows()
	local rows = {}
	for _, id in ipairs(GetPlayers()) do
		local source = tonumber(id)
		local session = Sessions[source]
		local row = { id = source, name = GetPlayerName(source), hasRadio = session ~= nil }
		if session then
			row.callsign = session.callsign
			row.radio = session.codeplug.civilian and 'Civilian' or (session.department or ''):upper()
			row.power = session.power
			row.channel = session.power and session.talkgroup or nil
			row.channelNumber = Player(source).state.radioChannel or 0
			row.signal = session.signal
		end
		rows[#rows + 1] = row
	end
	table.sort(rows, function(a, b) return a.id < b.id end)
	return rows
end

local function buildSnapshot(source, shiftTarget)
	local target = tonumber(shiftTarget)
	if not target or not GetPlayerName(target) then target = source end
	return {
		self = source,
		devTools = AreDevToolsEnabled(),
		devProfile = GetDevProfile(source),
		bleedTest = BleedTestRadio ~= nil,
		towers = GetAdminTowers(),
		players = playerRows(),
		nightShifts = GetNightShiftsInfo(target),
		shiftTarget = target,
	}
end

-- Only a server with signal_radio_dev_tools set allows these.
local devActions = {}

function devActions.setProfile(source, data)
	if type(data.department) ~= 'string' or not SetDevProfile(source, data.department, data.senior == true) then
		return false, 'Choose a department.'
	end
	if data.department == 'off' then return true, 'Test profile removed.' end
	return true, ('Test profile is now %s.'):format(data.department:upper())
end

function devActions.bleedTest(source, data)
	if data.on ~= true then
		BleedTestRadio = nil
		return true, 'Removed the test radio.'
	end
	local coords = GetEntityCoords(GetPlayerPed(source))
	BleedTestRadio = { x = coords.x, y = coords.y, z = coords.z }
	return true, 'Placed a test radio at your position.'
end

RegisterNetEvent('signal_radio:adminOpen', function()
	local source = source
	if not isAdmin(source) then
		TriggerClientEvent('signal_radio:adminRefused', source)
		-- One console line per player is enough to find the identifier, and stops a player filling the console.
		if not refusalLogged[source] then
			refusalLogged[source] = true
			local license = GetPlayerIdentifierByType(source, 'license') or 'license:unknown'
			print(('[signal_radio] %s (player %d) tried /radioadmin without radio.admin. To allow them, add this line to server.cfg: add_ace identifier.%s radio.admin allow')
				:format(GetPlayerName(source) or '?', source, license))
		end
		return
	end
	TriggerClientEvent('signal_radio:adminSnapshot', source, buildSnapshot(source), true)
end)

RegisterNetEvent('signal_radio:adminRefresh', function(shiftTarget)
	local source = source
	if not isAdmin(source) then return end
	TriggerClientEvent('signal_radio:adminSnapshot', source, buildSnapshot(source, shiftTarget), false)
end)

RegisterNetEvent('signal_radio:adminAction', function(name, data)
	local source = source
	if not isAdmin(source) then
		return print(('[signal_radio] Player %d tried an admin action without radio.admin.'):format(source))
	end
	if type(name) ~= 'string' or type(data) ~= 'table' then return end

	local action = AdminTowerActions[name] or (AreDevToolsEnabled() and devActions[name]) or nil
	if not action then return end
	local ok, message = action(source, data)
	TriggerClientEvent('signal_radio:adminResult', source, ok, message)
	TriggerClientEvent('signal_radio:adminSnapshot', source, buildSnapshot(source, data.shiftTarget), false)
end)
