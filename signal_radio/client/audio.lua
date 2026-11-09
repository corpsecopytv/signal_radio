local pma = exports['pma-voice']

-- Signal-quality submixes join this in step 7. Scanned channels play quieter.
local function resolveRadioAudio(_, listenerChannel)
	return { volume = listenerChannel and Config.ScanVolume or 1.0 }
end

CreateThread(function()
	pma:setRadioAudioResolver(resolveRadioAudio)
end)
