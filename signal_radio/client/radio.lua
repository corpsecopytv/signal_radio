local pma = exports['pma-voice']

-- Shared with client/ptt.lua
Radio = {
	state = { available = false },
	busy = {},
	towers = {},
	signal = 'full',
	talkerSignal = {},
	talkerDistance = {},
	bleed = {},
	transmitting = false,
	priorityUntil = 0,
	pressingUiPtt = false,
}

local handsetOpen = false

function SendToHandset(messageType, payload)
	payload = payload or {}
	payload.type = messageType
	SendNUIMessage(payload)
end

-- The radio keeps game input on, so key bindings such as push-to-talk still work while it is open.
-- This loop stops those keys from also moving, aiming or shooting.
local PUSH_TO_TALK_CONTROL = 249
local PAUSE_CONTROLS = { 199, 200 }
local PAUSE_GUARD_MS = 300
local controlLockId = 0

local function lockGameControlsWhileOpen()
	controlLockId = controlLockId + 1
	local lockId = controlLockId
	CreateThread(function()
		while handsetOpen and lockId == controlLockId do
			for group = 0, 2 do
				DisableAllControlActions(group)
				EnableControlAction(group, PUSH_TO_TALK_CONTROL, true)
			end
			Wait(0)
		end

		-- Esc closes the radio. Keep blocking it briefly so it does not also open the pause menu.
		local guardEnds = GetGameTimer() + PAUSE_GUARD_MS
		while GetGameTimer() < guardEnds and lockId == controlLockId do
			for _, control in ipairs(PAUSE_CONTROLS) do
				DisableControlAction(0, control, true)
			end
			Wait(0)
		end
	end)
end

local function setHandsetOpen(open)
	handsetOpen = open
	SetNuiFocus(open, open)
	SetNuiFocusKeepInput(open)
	lockGameControlsWhileOpen()
	SendToHandset('open', { open = open })
	if not open and Radio.pressingUiPtt then
		Radio.pressingUiPtt = false
		ExecuteCommand('-radiotalk')
	end
end

RegisterCommand('radio', function()
	setHandsetOpen(not handsetOpen)
end, false)
RegisterKeyMapping('radio', 'Open radio handset', 'keyboard', 'F6')

RegisterNetEvent('signal_radio:state', function(state)
	if state.talkgroup ~= Radio.state.talkgroup or not state.power then
		Radio.busy = {}
		if Radio.transmitting then ReleaseTransmit() end
	end
	Radio.state = state
	SendToHandset('state', { state = state, self = GetPlayerServerId(PlayerId()) })
end)

RegisterNetEvent('signal_radio:members', function(talkgroup, members)
	SendToHandset('members', { talkgroup = talkgroup, members = members })
end)

RegisterNetEvent('signal_radio:talk', function(talkgroup, talker, callsign, talking, signal)
	if talkgroup == Radio.state.talkgroup and talker ~= GetPlayerServerId(PlayerId()) then
		Radio.busy[talker] = talking or nil
	end
	Radio.talkerSignal[talker] = talking and signal or nil
	if not talking then Radio.talkerDistance[talker] = nil end
	if talking then pma:refreshRadioAudio() end
	SendToHandset('talk', { talkgroup = talkgroup, talker = talker, callsign = callsign, talking = talking })
end)

RegisterNetEvent('signal_radio:talkerDistance', function(talker, distance)
	local firstValue = Radio.talkerDistance[talker] == nil
	Radio.talkerDistance[talker] = distance
	if firstValue then pma:refreshRadioAudio() end
end)

RegisterNetEvent('signal_radio:bleed', function(channel, volume)
	Radio.bleed[channel] = volume
	pma:refreshRadioAudio()
end)

RegisterNetEvent('signal_radio:panic', function(talkgroup, label, callsign, sender)
	if sender == GetPlayerServerId(PlayerId()) then
		Radio.priorityUntil = GetGameTimer() + Config.PanicPriorityMs
	end
	SendToHandset('panic', { talkgroup = talkgroup, label = label, callsign = callsign })
end)

RegisterNetEvent('pma-voice:radioListenerActivity', function(_, active)
	SendToHandset('encrypted', { active = active })
end)

RegisterNetEvent('signal_radio:panicRefused', function(reason)
	SendToHandset('panicRefused', { reason = reason })
end)

local actions = {
	ready = function()
		local position = GetResourceKvpString('handsetPosition')
		SendToHandset('prefs', { position = position and json.decode(position) or nil, volume = pma:getRadioVolume() })
		TriggerServerEvent('signal_radio:hello')
	end,
	close = function()
		setHandsetOpen(false)
	end,
	power = function(data)
		TriggerServerEvent('signal_radio:setPower', data.on == true)
	end,
	selectTalkgroup = function(data)
		TriggerServerEvent('signal_radio:selectTalkgroup', data.talkgroup)
	end,
	tune = function(data)
		TriggerServerEvent('signal_radio:tune', tonumber(data.frequency))
	end,
	useFrequencyMode = function()
		TriggerServerEvent('signal_radio:useFrequencyMode')
	end,
	setScanTalkgroup = function(data)
		TriggerServerEvent('signal_radio:setScanTalkgroup', data.talkgroup, data.enabled == true)
	end,
	scan = function(data)
		TriggerServerEvent('signal_radio:setScan', data.enabled == true)
	end,
	panic = function()
		TriggerServerEvent('signal_radio:panic')
	end,
	ptt = function(data)
		if data.down == true and not Radio.pressingUiPtt then
			Radio.pressingUiPtt = true
			ExecuteCommand('+radiotalk')
		elseif data.down ~= true and Radio.pressingUiPtt then
			Radio.pressingUiPtt = false
			ExecuteCommand('-radiotalk')
		end
	end,
	volume = function(data)
		local volume = tonumber(data.value)
		if not volume then return end
		volume = math.max(0, math.min(100, math.floor(volume)))
		pma:setRadioVolume(volume)
		SetResourceKvp('radioVolumeLevel', tostring(volume))
		SendToHandset('prefs', { volume = volume })
	end,
	savePosition = function(data)
		if type(data.x) == 'number' and type(data.y) == 'number' then
			SetResourceKvp('handsetPosition', json.encode({ x = data.x, y = data.y }))
		end
	end,
}

RegisterNUICallback('action', function(data, cb)
	local action = actions[data.action]
	if action then action(data) end
	cb('ok')
end)

CreateThread(function()
	local savedVolume = tonumber(GetResourceKvpString('radioVolumeLevel'))
	if savedVolume then
		pma:setRadioVolume(savedVolume)
	end
end)

-- Sends one man-down alert each time the player stays dead past the delay.
CreateThread(function()
	local deadSince = nil
	local alerted = false
	while true do
		Wait(1000)
		if IsEntityDead(PlayerPedId()) then
			deadSince = deadSince or GetGameTimer()
			local waited = GetGameTimer() - deadSince >= Config.NightShifts.manDown.delayMs
			if waited and not alerted and Radio.state.power and not Radio.state.civilian then
				alerted = true
				TriggerServerEvent('signal_radio:manDown')
			end
		else
			deadSince = nil
			alerted = false
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		SetNuiFocus(false, false)
		SetNuiFocusKeepInput(false)
	end
end)
