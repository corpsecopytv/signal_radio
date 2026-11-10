local TOWER_LIST_KEY = 'towers:list'

local towers = {}
local sabotages = {}
-- attempts[towerId] = { source = player, started = os.time() }
local attempts = {}

local function sabotageKey(id)
	return ('tower:%s:sabotage'):format(id)
end

local function loadSabotage(id)
	local saved = GetResourceKvpString(sabotageKey(id))
	local sabotagedUntil, cooldownUntil = (saved or ''):match('^(%d+),(%d+)$')
	sabotages[id] = { sabotagedUntil = tonumber(sabotagedUntil) or 0, cooldownUntil = tonumber(cooldownUntil) or 0 }
end

local function saveSabotage(id)
	SetResourceKvp(sabotageKey(id), ('%d,%d'):format(sabotages[id].sabotagedUntil, sabotages[id].cooldownUntil))
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

local function isSabotaged(id)
	return sabotages[id].sabotagedUntil > os.time()
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
			online = not isSabotaged(tower.id),
		}
	end
	return list, canSabotage(source)
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
	return math.sqrt(dx * dx + dy * dy) <= Config.Sabotage.interactDistance + 1.0
end

local function cancelAttempt(towerId, reason)
	local attempt = attempts[towerId]
	if not attempt then return end
	attempts[towerId] = nil
	if reason then
		TriggerClientEvent('signal_radio:sabotageRefused', attempt.source, reason)
	end
end

local function attemptOf(source)
	for towerId, attempt in pairs(attempts) do
		if attempt.source == source then return towerId end
	end
	return nil
end

RegisterNetEvent('signal_radio:hello', function()
	sendTowers(source)
end)

RegisterNetEvent('signal_radio:sabotageStart', function(towerId)
	local source = source
	local tower = type(towerId) == 'string' and findTower(towerId) or nil
	if not tower then return end
	if not canSabotage(source) then
		return TriggerClientEvent('signal_radio:sabotageRefused', source, 'not_allowed')
	end
	if not playerAtTower(source, tower) then
		return TriggerClientEvent('signal_radio:sabotageRefused', source, 'too_far')
	end
	if isSabotaged(towerId) then
		return TriggerClientEvent('signal_radio:sabotageRefused', source, 'already_sabotaged')
	end
	if sabotages[towerId].cooldownUntil > os.time() then
		return TriggerClientEvent('signal_radio:sabotageRefused', source, 'cooldown')
	end
	-- A repeat press from the player already sabotaging this tower needs no reply.
	if attempts[towerId] and attempts[towerId].source == source then return end
	if attempts[towerId] or attemptOf(source) then
		return TriggerClientEvent('signal_radio:sabotageRefused', source, 'in_use')
	end
	attempts[towerId] = { source = source, started = os.time() }
	TriggerClientEvent('signal_radio:sabotageStarted', source, towerId, Config.Sabotage.sabotageSeconds)
end)

RegisterNetEvent('signal_radio:sabotageCancel', function()
	local towerId = attemptOf(source)
	if towerId then cancelAttempt(towerId) end
end)

RegisterNetEvent('signal_radio:sabotageFinish', function(towerId)
	local source = source
	local attempt = type(towerId) == 'string' and attempts[towerId] or nil
	if not attempt or attempt.source ~= source then return end
	local tower = findTower(towerId)
	local elapsed = os.time() - attempt.started
	local ped = GetPlayerPed(source)
	if elapsed < Config.Sabotage.sabotageSeconds or not playerAtTower(source, tower) or GetEntityHealth(ped) <= 0 then
		return cancelAttempt(towerId, 'interrupted')
	end
	attempts[towerId] = nil

	local now = os.time()
	sabotages[towerId].sabotagedUntil = now + Config.Sabotage.offlineSeconds
	sabotages[towerId].cooldownUntil = now + Config.Sabotage.cooldownSeconds
	saveSabotage(towerId)
	alertStaff(('%s: %s (id %d) sabotaged tower %s (%s).'):format(os.date('%Y-%m-%d %H:%M:%S'), GetPlayerName(source), source, tower.label, tower.id))
	broadcastTowers()
	announceTower(tower, false)
end)

--- Ends finished sabotage and cancels attempts whose player left the tower.
function TickTowers()
	local now = os.time()
	for _, tower in ipairs(towers) do
		local sabotage = sabotages[tower.id]
		if sabotage.sabotagedUntil > 0 and sabotage.sabotagedUntil <= now then
			sabotage.sabotagedUntil = 0
			saveSabotage(tower.id)
			broadcastTowers()
			announceTower(tower, true)
		end
		local attempt = attempts[tower.id]
		if attempt and not playerAtTower(attempt.source, tower) then
			cancelAttempt(tower.id, 'interrupted')
		end
	end
end

AddEventHandler('playerDropped', function()
	local towerId = attemptOf(source)
	if towerId then cancelAttempt(towerId) end
end)

--- Tower details for the admin panel.
function GetAdminTowers()
	local list = {}
	local now = os.time()
	for _, tower in ipairs(towers) do
		local sabotage = sabotages[tower.id]
		list[#list + 1] = {
			id = tower.id,
			label = tower.label,
			radius = tower.radius,
			online = not isSabotaged(tower.id),
			sabotagedSeconds = math.max(0, sabotage.sabotagedUntil - now),
			cooldownSeconds = math.max(0, sabotage.cooldownUntil - now),
		}
	end
	return list
end

-- Admin panel actions. Each returns success and a message for the panel.
AdminTowerActions = {}

--- Places a tower where the admin stands.
function AdminTowerActions.towerAdd(source, data)
	local id, radius = data.id, tonumber(data.radius) or 2500.0
	if type(id) ~= 'string' or #id > 32 or findTower(id) or not id:match('^[%w_]+$') then
		return false, 'Give a new tower ID using letters, numbers or underscores.'
	end
	if radius <= 0 then return false, 'Give a radius above 0.' end
	local coords = GetEntityCoords(GetPlayerPed(source))
	towers[#towers + 1] = { id = id, label = id, x = coords.x, y = coords.y, z = coords.z, radius = radius + 0.0 }
	loadSabotage(id)
	saveTowers()
	broadcastTowers()
	return true, ('Added tower %s with radius %g.'):format(id, radius)
end

function AdminTowerActions.towerRemove(_, data)
	local _, index = findTower(data.id)
	if not index then return false, 'That tower does not exist.' end
	local id = data.id
	cancelAttempt(id, 'interrupted')
	table.remove(towers, index)
	sabotages[id] = nil
	-- A tower added later with this id must start fresh.
	SetResourceKvp(sabotageKey(id), '0,0')
	saveTowers()
	broadcastTowers()
	return true, ('Removed tower %s.'):format(id)
end

function AdminTowerActions.towerRadius(_, data)
	local tower = findTower(data.id)
	local radius = tonumber(data.radius)
	if not tower or not radius or radius <= 0 then return false, 'Give a radius above 0.' end
	tower.radius = radius + 0.0
	saveTowers()
	broadcastTowers()
	return true, ('Tower %s radius is now %g.'):format(tower.id, radius)
end

function AdminTowerActions.towerClear(_, data)
	local tower = findTower(data.id)
	if not tower then return false, 'That tower does not exist.' end
	sabotages[tower.id] = { sabotagedUntil = 0, cooldownUntil = 0 }
	saveSabotage(tower.id)
	broadcastTowers()
	announceTower(tower, true)
	return true, ('Cleared the sabotage and cooldown on %s.'):format(tower.id)
end

do
	local saved = GetResourceKvpString(TOWER_LIST_KEY)
	towers = saved and json.decode(saved) or Config.Towers
	for _, tower in ipairs(towers) do
		loadSabotage(tower.id)
	end
end

CreateThread(function()
	while true do
		Wait(1000)
		TickTowers()
	end
end)
