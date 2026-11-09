local pma = exports['pma-voice']

-- pma-voice ignores talk events while a disable bit is set, so this bit is only pulsed.
-- A held bit could lose another talker's stop event and leave them stuck on radio audio.
local DENY_BIT = 1 << 4
local DENY_PULSE_MS = 150
local denying = false
local denied = false

function DenyTransmit()
	if denying then return end
	denying, denied = true, true
	pma:addRadioDisableBit(DENY_BIT)
	SendToHandset('denied')
	SetTimeout(DENY_PULSE_MS, function()
		pma:removeRadioDisableBit(DENY_BIT)
		pma:refreshRadioAudio()
		denying = false
	end)
end

local function hasPriority()
	return Radio.state.priority or GetGameTimer() < Radio.priorityUntil
end

--- A talker this radio cannot reach does not make the channel busy.
local function isChannelBusy()
	for talker in pairs(Radio.busy) do
		if IsTalkerAudible(talker) then return true end
	end
	return false
end

AddEventHandler('pma-voice:radioActive', function(active)
	if active then
		if isChannelBusy() and not hasPriority() then
			return DenyTransmit()
		end
		SendToHandset('tx', { active = true })
	else
		if not denied then
			SendToHandset('tx', { active = false })
		end
		denied = false
	end
end)

RegisterNetEvent('signal_radio:txDenied', function()
	SendToHandset('tx', { active = false })
	DenyTransmit()
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and denying then
		pma:removeRadioDisableBit(DENY_BIT)
	end
end)
