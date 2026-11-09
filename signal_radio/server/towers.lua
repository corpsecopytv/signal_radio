local TOWER_LIST_KEY = 'towers:list'

local towers = {}
local jams = {}
-- installs[towerId] = { source = player, started = os.time() }
local installs = {}

local function jamKey(id)
	return ('tower:%s:jam'):format(id)
end

local function loadJam(id)
	local saved = GetResourceKvpString(jamKey(id))
	local jammedUntil, cooldownUntil = (saved or ''):match('^(%d+),(%d+)$')
	jams[id] = { jammedUntil = tonumber(jammedUntil) or 0, cooldownUntil = tonumber(cooldownUntil) or 0 }
end

local function saveJam(id)
	SetResourceKvp(jamKey(id), ('%d,%d'):format(jams[id].jammedUntil, jams[id].cooldownUntil))
end

local function saveTowers()
	SetResourceKvp(TOWER_LIST_KEY, json.encode(towers))
end

local function findTower(id)
	for index, tower in ipairs(towers) do
		if tower.id == id then return tower, index end
	end
	return nil
end

local function isJammed(id)
	return jams[id].jammedUntil > os.time()
end

local function towerPayload(source)
	local list = {}
	for _, tower in ipairs(towers) do
		list[#list + 1] = {
			id = tower.id,
			label = tower.label,
			x = tower.x,
			y = tower.y,
			z = tower.z,
			radius = tower.radius,
			online = not isJammed(tower.id),
		}
	end
	return list, canUseJammer(source)
end

local function sendTowers(source)
	TriggerClientEvent('signal_radio:towers', source, towerPayload(source))
end

local function broadcastTowers()
	for _, player in ipairs(GetPlayers()) do
		sendTowers(tonumber(player))
	end
end

local function announceTower(tower, online)
	for source, session in pairs(Sessions) do
		if session.power then
			TriggerClientEvent('signal_radio:towerStatus', source, tower.label, online)
		end
	end
end

local function alertStaff(message)
	print(('[signal_radio] %s'):format(message))
	for _, player in ipairs(GetPlayers()) do
		if IsPlayerAceAllowed(player, 'radio.admin') then
			TriggerClientEvent('chat:addMessage', tonumber(player), { args = { 'Radio staff', message } })
		end
	end
end

local function playerAtTower(source, tower)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then return false end
	local coords = GetEntityCoords(ped)
	-- Height is ignored, so placeholder tower heights still work.
	local dx, dy = coords.x - tower.x, coords.y - tower.y
	return math.sqrt(dx * dx + dy * dy) <= Config.Jammer.interactDistance + 1.0
end

local function cancelInstall(towerId, reason)
	local install = installs[towerId]
	if not install then return end
	installs[towerId] = nil
	if reason then
		TriggerClientEvent('signal_radio:jamRefused', install.source, reason)
	end
end

local function installOf(source)
	for towerId, install in pairs(installs) do
		if install.source == source then return towerId end
	end
	return nil
end

RegisterNetEvent('signal_radio:hello', function()
	sendTowers(source)
end)

RegisterNetEvent('signal_radio:jamStart', function(towerId)
	local source = source
	local tower = type(towerId) == 'string' and findTower(towerId) or nil
	if not tower then return end
	if not canUseJammer(source) then
		return TriggerClientEvent('signal_radio:jamRefused', source, 'no_jammer')
	end
	if not playerAtTower(source, tower) then
		return TriggerClientEvent('signal_radio:jamRefused', source, 'too_far')
	end
	if isJammed(towerId) then
		return TriggerClientEvent('signal_radio:jamRefused', source, 'already_jammed')
	end
	if jams[towerId].cooldownUntil > os.time() then
		return TriggerClientEvent('signal_radio:jamRefused', source, 'cooldown')
	end
	if installs[towerId] or installOf(source) then
		return TriggerClientEvent('signal_radio:jamRefused', source, 'in_use')
	end
	installs[towerId] = { source = source, started = os.time() }
	TriggerClientEvent('signal_radio:jamStarted', source, towerId, Config.Jammer.installSeconds)
end)

RegisterNetEvent('signal_radio:jamCancel', function()
	local towerId = installOf(source)
	if towerId then cancelInstall(towerId) end
end)

RegisterNetEvent('signal_radio:jamFinish', function(towerId)
	local source = source
	local install = type(towerId) == 'string' and installs[towerId] or nil
	if not install or install.source ~= source then return end
	local tower = findTower(towerId)
	local elapsed = os.time() - install.started
	local ped = GetPlayerPed(source)
	if elapsed < Config.Jammer.installSeconds or not playerAtTower(source, tower) or GetEntityHealth(ped) <= 0 then
		return cancelInstall(towerId, 'interrupted')
	end
	installs[towerId] = nil

	local now = os.time()
	jams[towerId].jammedUntil = now + Config.Jammer.offlineSeconds
	jams[towerId].cooldownUntil = now + Config.Jammer.cooldownSeconds
	saveJam(towerId)
	alertStaff(('%s (id %d) jammed tower %s (%s).'):format(GetPlayerName(source), source, tower.label, tower.id))
	broadcastTowers()
	announceTower(tower, false)
end)

--- Ends finished jams and cancels installs whose player left the tower.
function TickTowers()
	local now = os.time()
	for _, tower in ipairs(towers) do
		local jam = jams[tower.id]
		if jam.jammedUntil > 0 and jam.jammedUntil <= now then
			jam.jammedUntil = 0
			saveJam(tower.id)
			broadcastTowers()
			announceTower(tower, true)
		end
		local install = installs[tower.id]
		if install and not playerAtTower(install.source, tower) then
			cancelInstall(tower.id, 'interrupted')
		end
	end
end

AddEventHandler('playerDropped', function()
	local towerId = installOf(source)
	if towerId then cancelInstall(towerId) end
end)

local commands = {}

-- /radio_tower add <id> [radius]: places a tower where you stand.
function commands.add(source, args)
	local id, radius = args[2], tonumber(args[3]) or 2500.0
	if not id or findTower(id) or not id:match('^[%w_]+$') then
		return 'Give a new tower id using letters, numbers or underscores.'
	end
	local coords = GetEntityCoords(GetPlayerPed(source))
	towers[#towers + 1] = { id = id, label = id, x = coords.x, y = coords.y, z = coords.z, radius = radius + 0.0 }
	loadJam(id)
	saveTowers()
	broadcastTowers()
	return ('Added tower %s with radius %d.'):format(id, radius)
end

function commands.remove(_, args)
	local _, index = findTower(args[2])
	if not index then return 'That tower does not exist.' end
	local id = args[2]
	table.remove(towers, index)
	jams[id] = nil
	installs[id] = nil
	saveTowers()
	broadcastTowers()
	return ('Removed tower %s.'):format(id)
end

function commands.radius(_, args)
	local tower = findTower(args[2])
	local radius = tonumber(args[3])
	if not tower or not radius or radius <= 0 then return 'Use /radio_tower radius <id> <metres>.' end
	tower.radius = radius + 0.0
	saveTowers()
	broadcastTowers()
	return ('Tower %s radius is now %d.'):format(tower.id, radius)
end

function commands.clear(_, args)
	local tower = findTower(args[2])
	if not tower then return 'That tower does not exist.' end
	jams[tower.id] = { jammedUntil = 0, cooldownUntil = 0 }
	saveJam(tower.id)
	broadcastTowers()
	announceTower(tower, true)
	return ('Cleared the jam and cooldown on %s.'):format(tower.id)
end

function commands.list()
	local parts = {}
	local now = os.time()
	for _, tower in ipairs(towers) do
		local jam = jams[tower.id]
		local status = jam.jammedUntil > now and ('jammed %ds'):format(jam.jammedUntil - now) or 'online'
		if jam.cooldownUntil > now then
			status = ('%s, cooldown %ds'):format(status, jam.cooldownUntil - now)
		end
		parts[#parts + 1] = ('%s (%s)'):format(tower.id, status)
	end
	return table.concat(parts, ', ')
end

RegisterCommand('radio_tower', function(source, args)
	if source ~= 0 and not IsPlayerAceAllowed(source, 'radio.admin') then return end
	local command = commands[args[1]]
	local message = command and command(source, args) or 'Use add, remove, radius, clear or list.'
	if source == 0 then
		print(('[signal_radio] %s'):format(message))
	else
		TriggerClientEvent('chat:addMessage', source, { args = { 'Radio', message } })
	end
end, false)

do
	local saved = GetResourceKvpString(TOWER_LIST_KEY)
	towers = saved and json.decode(saved) or Config.Towers
	for _, tower in ipairs(towers) do
		loadJam(tower.id)
	end
end

CreateThread(function()
	while true do
		Wait(1000)
		TickTowers()
	end
end)
