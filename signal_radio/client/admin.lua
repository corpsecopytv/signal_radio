-- The radio admin panel. The server decides who can open it and who can see Test tools.

local testSpots = {
	-- Spots a and b are 150 metres apart, beyond every proximity range.
	-- Spot c is 3 metres from a, for testing normal proximity voice.
	a = { -1336.0, -3044.0, 20.0 },
	b = { -1186.0, -3044.0, 20.0 },
	c = { -1333.0, -3044.0, 20.0 },
}

local panelOpen = false
local devTools = false
local transmitting = false
local watching = nil

--- Chat keeps the message visible after the panel closes, as solo tests need.
local function say(message)
	TriggerEvent('chat:addMessage', { args = { 'Radio admin', message } })
	if panelOpen then SendToHandset('adminNote', { message = message }) end
end

local function setPanelOpen(open)
	panelOpen = open
	SetNuiFocus(open, open)
	SetNuiFocusKeepInput(false)
	SendToHandset('adminOpen', { open = open })
end

local function moveAndFreeze(x, y, z)
	local ped = PlayerPedId()
	SetEntityCoordsNoOffset(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false)
	FreezeEntityPosition(ped, true)
end

local function standBesideTower(tower)
	CreateThread(function()
		local ped = PlayerPedId()
		local x, y = tower.x + 1.5, tower.y
		FreezeEntityPosition(ped, true)
		SetEntityCoordsNoOffset(ped, x, y, tower.z + 50.0, false, false, false)
		local found, ground = false, tower.z
		for _ = 1, 100 do
			RequestCollisionAtCoord(x, y, tower.z)
			found, ground = GetGroundZFor_3dCoord(x, y, 1000.0, false)
			if found then break end
			Wait(50)
		end
		SetEntityCoordsNoOffset(ped, x, y, (found and ground or tower.z) + 1.0, false, false, false)
		FreezeEntityPosition(ped, false)
		say(('Moved beside tower %s.'):format(tower.id))
	end)
end

local function watchTalker(talker)
	watching = talker
	say(('Watching talker %d. The talker must be in your OneSync scope.'):format(talker))
	CreateThread(function()
		local last = nil
		while watching == talker do
			local player = GetPlayerFromServerId(talker)
			local state = 'out of scope'
			if player ~= -1 then
				local value = MumbleIsPlayerTalking(player)
				state = (value == true or value == 1) and 'voice arriving' or 'silent'
			end
			if state ~= last then
				say(('Talker %d: %s.'):format(talker, state))
				last = state
			end
			Wait(100)
		end
	end)
end

local devActions = {}

-- Solo testing runs two clients on one PC. Only the focused window gets key presses,
-- so this holds the radio key on a timer while you switch to the other window.
function devActions.transmit(data)
	if transmitting then return say('A timed transmission is already running.') end
	local seconds = math.max(1, math.min(60, tonumber(data.seconds) or 10))
	local delay = math.max(0, math.min(30, tonumber(data.delay) or 5))
	transmitting = true
	say(('Transmitting for %d seconds, starting in %d seconds.'):format(seconds, delay))
	CreateThread(function()
		Wait(delay * 1000)
		ExecuteCommand('+radiotalk')
		say('Radio key down.')
		Wait(seconds * 1000)
		ExecuteCommand('-radiotalk')
		say('Radio key up.')
		transmitting = false
	end)
end

function devActions.goTo(data)
	local x, y = tonumber(data.x), tonumber(data.y)
	if not x or not y then return say('Give an X and a Y position.') end
	moveAndFreeze(x, y, tonumber(data.z) or 60.0)
	say(('Moved to %g, %g and frozen.'):format(x, y))
end

function devActions.goToSpot(data)
	local spot = testSpots[data.spot]
	if not spot then return end
	moveAndFreeze(spot[1], spot[2], spot[3])
	say(('Moved to test spot %s and frozen.'):format(data.spot))
end

function devActions.release()
	FreezeEntityPosition(PlayerPedId(), false)
	say('Released.')
end

function devActions.goToTower(data)
	for _, tower in ipairs(Radio.towers) do
		if tower.id == data.id then return standBesideTower(tower) end
	end
end

function devActions.watch(data)
	local talker = tonumber(data.talker)
	if not talker then
		watching = nil
		return say('Watch stopped.')
	end
	watchTalker(talker)
end

RegisterCommand('radioadmin', function()
	TriggerServerEvent('signal_radio:adminOpen')
end, false)
RegisterKeyMapping('radioadmin', 'Open radio admin panel', 'keyboard', '')

RegisterNetEvent('signal_radio:adminSnapshot', function(snapshot, open)
	devTools = snapshot.devTools == true
	if open then
		CloseHandset()
		setPanelOpen(true)
	end
	if panelOpen then SendToHandset('adminSnapshot', { snapshot = snapshot }) end
end)

RegisterNetEvent('signal_radio:adminRefused', function()
	say('You need the radio.admin permission. The server console shows the line to add.')
end)

RegisterNetEvent('signal_radio:adminResult', function(ok, message)
	if panelOpen then SendToHandset('adminNote', { message = message, failed = not ok }) end
end)

RegisterNUICallback('admin', function(data, cb)
	cb('ok')
	local name = data.action
	if name == 'close' then
		setPanelOpen(false)
	elseif name == 'refresh' then
		TriggerServerEvent('signal_radio:adminRefresh', data.shiftTarget)
	elseif name == 'towerRadii' then
		SendToHandset('adminRadii', { on = ToggleTowerRadii() })
	elseif devActions[name] then
		if devTools then devActions[name](data) end
	else
		TriggerServerEvent('signal_radio:adminAction', name, data)
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and panelOpen then
		SetNuiFocus(false, false)
	end
end)
