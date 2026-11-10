local CANCEL_CONTROL = 73
local INTERACT_CONTROL = 51
local START_REPLY_WAIT_MS = 3000
local SABOTAGE_SCENARIO = 'WORLD_HUMAN_WELDING'
local MAX_SABOTAGE_DRIFT = 1.5
local NEAR_TOWER_DISTANCE = 30.0

local REFUSAL_TEXT = {
	too_far = 'Move closer to the tower.',
	already_sabotaged = 'This tower is already sabotaged.',
	cooldown = 'This tower cannot be sabotaged again yet.',
	in_use = 'Someone is already sabotaging this tower.',
	interrupted = 'Sabotage stopped.',
}

local canSabotageTower = false
local sabotaging = false
local awaitingStartUntil = 0
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

RegisterNetEvent('signal_radio:towers', function(towers, allowedToSabotage)
	Radio.towers = towers
	canSabotageTower = allowedToSabotage == true
	drawDebugBlips()
	UpdateRadioSignal()
end)

RegisterNetEvent('signal_radio:towerStatus', function(label, online)
	SendToHandset('towerStatus', { label = label, online = online })
	notify(('%s tower %s'):format(label, online and 'back online' or 'offline'))
end)

RegisterNetEvent('signal_radio:sabotageRefused', function(reason)
	awaitingStartUntil = 0
	-- 'in_use' can only refer to someone else, or a press that overlapped this player's own attempt.
	if reason ~= 'in_use' then sabotaging = false end
	notify(REFUSAL_TEXT[reason] or 'Sabotage stopped.')
end)

RegisterNetEvent('signal_radio:sabotageStarted', function(towerId, seconds)
	awaitingStartUntil = 0
	sabotaging = true
	local ped = PlayerPedId()
	local start = GetEntityCoords(ped)
	local finishAt = GetGameTimer() + seconds * 1000
	TaskStartScenarioInPlace(ped, SABOTAGE_SCENARIO, 0, true)

	CreateThread(function()
		local cancelled = false
		while sabotaging and GetGameTimer() < finishAt do
			local remaining = math.ceil((finishAt - GetGameTimer()) / 1000)
			showHelp(('Sabotaging tower: %d seconds left. Press ~INPUT_VEH_DUCK~ to cancel.'):format(remaining))
			if IsControlJustPressed(0, CANCEL_CONTROL) or IsEntityDead(ped) or #(GetEntityCoords(ped) - start) > MAX_SABOTAGE_DRIFT then
				cancelled = true
				break
			end
			Wait(0)
		end

		ClearPedTasks(ped)
		if cancelled then
			sabotaging = false
			TriggerServerEvent('signal_radio:sabotageCancel')
			notify('Sabotage stopped.')
		elseif sabotaging then
			sabotaging = false
			TriggerServerEvent('signal_radio:sabotageFinish', towerId)
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
		if canSabotageTower and not sabotaging then
			local coords = GetEntityCoords(PlayerPedId())
			local tower, distance = nearestOnlineTower(coords)
			if tower then
				wait = 0
				local found, groundZ = GetGroundZFor_3dCoord(tower.x, tower.y, coords.z + 5.0, false)
				DrawMarker(1, tower.x, tower.y, (found and groundZ or coords.z - 1.0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.6, 228, 96, 26, 140, false, false, 2, false, nil, nil, false)
				if distance <= Config.Sabotage.interactDistance then
					showHelp(('Press ~INPUT_CONTEXT~ to sabotage %s.'):format(tower.label))
					if IsControlJustPressed(0, INTERACT_CONTROL) and GetGameTimer() >= awaitingStartUntil then
						awaitingStartUntil = GetGameTimer() + START_REPLY_WAIT_MS
						TriggerServerEvent('signal_radio:sabotageStart', tower.id)
					end
				end
			end
		end
		Wait(wait)
	end
end)

--- Shows or hides each tower's radius on the map. Returns whether they now show.
function ToggleTowerRadii()
	debugEnabled = not debugEnabled
	drawDebugBlips()
	return debugEnabled
end

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		clearDebugBlips()
		if sabotaging then ClearPedTasks(PlayerPedId()) end
	end
end)
