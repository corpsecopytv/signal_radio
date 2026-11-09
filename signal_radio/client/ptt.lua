local pma = exports['pma-voice']

-- pma-voice ignores talk events while a disable bit is set, so this bit is only pulsed.
-- A held bit could lose another talker's stop event and leave them stuck on radio audio.
local DENY_BIT = 1 << 4
local DENY_PULSE_MS = 150
local denying = false
local denied = false

--- @param reason string busy or no_signal
function DenyTransmit(reason)
	if denying then return end
	denying, denied = true, true
	pma:addRadioDisableBit(DENY_BIT)
	SendToHandset('denied', { reason = reason })
	SetTimeout(DENY_PULSE_MS, function()
		pma:removeRadioDisableBit(DENY_BIT)
		pma:refreshRadioAudio()
		denying = false
	end)
end

local function hasPriority()
	return Radio.state.priority or GetGameTimer() < Radio.priorityUntil
end

AddEventHandler('pma-voice:radioActive', function(active)
	Radio.transmitting = active
	if active then
		if HasNoSignal() then
			return DenyTransmit('no_signal')
		end
		if next(Radio.busy) and not hasPriority() then
			return DenyTransmit('busy')
		end
		SendToHandset('tx', { active = true })
	else
		if not denied then
			SendToHandset('tx', { active = false })
		end
		denied = false
	end
end)

RegisterNetEvent('signal_radio:txDenied', function(reason)
	SendToHandset('tx', { active = false })
	DenyTransmit(reason or 'busy')
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() and denying then
		pma:removeRadioDisableBit(DENY_BIT)
	end
end)
