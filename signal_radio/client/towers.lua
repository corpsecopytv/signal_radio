local CANCEL_CONTROL = 73
local INTERACT_CONTROL = 38
local INSTALL_SCENARIO = 'WORLD_HUMAN_WELDING'
local MAX_INSTALL_DRIFT = 1.5
local NEAR_TOWER_DISTANCE = 30.0

local REFUSAL_TEXT = {
	too_far = 'Move closer to the tower.',
	already_jammed = 'This tower is already jammed.',
	cooldown = 'This tower cannot be jammed again yet.',
	in_use = 'Someone is already installing a jammer.',
	interrupted = 'Jammer install stopped.',
}

local canJam = false
local installing = false
local debugBlips = {}
local debugEnabled = false

local function notify(message)
	BeginTextCommandThefeedPost('STRING')
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandThefeedPostTicker(false, false)
end

local function showHelp(message)
	BeginTextCommandDisplayHelp('STRING')
	AddTextComponentSubstringPlayerName(message)
	EndTextCommandDisplayHelp(0, false, false, -1)
end

local function clearDebugBlips()
	for _, blip in ipairs(debugBlips) do
		RemoveBlip(blip)
	end
	debugBlips = {}
end

local function drawDebugBlips()
	clearDebugBlips()
	if not debugEnabled then return end
	for _, tower in ipairs(Radio.towers) do
		local blip = AddBlipForRadius(tower.x, tower.y, tower.z, tower.radius)
		SetBlipColour(blip, tower.online and 2 or 1)
		SetBlipAlpha(blip, 70)
		debugBlips[#debugBlips + 1] = blip
	end
end

RegisterNetEvent('signal_radio:towers', function(towers, allowedToJam)
	Radio.towers = towers
	canJam = allowedToJam == true
	drawDebugBlips()
	UpdateRadioSignal()
end)

RegisterNetEvent('signal_radio:towerStatus', function(label, online)
	SendToHandset('towerStatus', { label = label, online = online })
end)

RegisterNetEvent('signal_radio:jamRefused', function(reason)
	installing = false
	notify(REFUSAL_TEXT[reason] or 'Jammer install stopped.')
end)

RegisterNetEvent('signal_radio:jamStarted', function(towerId, seconds)
	installing = true
	local ped = PlayerPedId()
	local start = GetEntityCoords(ped)
	local finishAt = GetGameTimer() + seconds * 1000
	TaskStartScenarioInPlace(ped, INSTALL_SCENARIO, 0, true)

	CreateThread(function()
		local cancelled = false
		while installing and GetGameTimer() < finishAt do
			local remaining = math.ceil((finishAt - GetGameTimer()) / 1000)
			showHelp(('Installing jammer: %d seconds left. Press ~INPUT_VEH_DUCK~ to cancel.'):format(remaining))
			if IsControlJustPressed(0, CANCEL_CONTROL) or IsEntityDead(ped) or #(GetEntityCoords(ped) - start) > MAX_INSTALL_DRIFT then
				cancelled = true
				break
			end
			Wait(0)
		end

		ClearPedTasks(ped)
		if cancelled then
			installing = false
			TriggerServerEvent('signal_radio:jamCancel')
			notify('Jammer install stopped.')
		elseif installing then
			installing = false
			TriggerServerEvent('signal_radio:jamFinish', towerId)
		end
	end)
end)

local function nearestOnlineTower(coords)
	local nearest, nearestDistance = nil, NEAR_TOWER_DISTANCE
	for _, tower in ipairs(Radio.towers) do
		local dx, dy = coords.x - tower.x, coords.y - tower.y
		local distance = math.sqrt(dx * dx + dy * dy)
		if tower.online and distance < nearestDistance then
			nearest, nearestDistance = tower, distance
		end
	end
	return nearest, nearestDistance
end

CreateThread(function()
	while true do
		local wait = 1000
		if canJam and not installing then
			local coords = GetEntityCoords(PlayerPedId())
			local tower, distance = nearestOnlineTower(coords)
			if tower then
				wait = 0
				local found, groundZ = GetGroundZFor_3dCoord(tower.x, tower.y, coords.z + 5.0, false)
				DrawMarker(1, tower.x, tower.y, (found and groundZ or coords.z - 1.0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.6, 228, 96, 26, 140, false, false, 2, false, nil, nil, false)
				if distance <= Config.Jammer.interactDistance then
					showHelp(('Press ~INPUT_CONTEXT~ to install a jammer on %s.'):format(tower.label))
					if IsControlJustPressed(0, INTERACT_CONTROL) then
						TriggerServerEvent('signal_radio:jamStart', tower.id)
					end
				end
			end
		end
		Wait(wait)
	end
end)

RegisterCommand('radio_tower_debug', function()
	debugEnabled = not debugEnabled
	drawDebugBlips()
	notify(debugEnabled and 'Tower radius shown on the map.' or 'Tower radius hidden.')
end, false)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		clearDebugBlips()
		if installing then ClearPedTasks(PlayerPedId()) end
	end
end)
