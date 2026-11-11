-- Checks that pma-voice has the signal_radio patch.
-- Encrypted talkgroups need the patched listener exports, so radios stay off without them.
PmaPatched = false

local function hasListenerExports()
	-- No player has the source -1, so this call changes nothing.
	local ok = pcall(function()
		return exports['pma-voice']:removeRadioListener(-1, -1)
	end)
	return ok
end

local function hasUpgradePatch()
	local file = LoadResourceFile('pma-voice', 'client/module/radio.lua')
	return file ~= nil and file:find('setRadioTalkerVoice', 1, true) ~= nil
end

--- @return boolean changed true when the result differs from the last check
function CheckPmaPatch()
	local before = PmaPatched
	PmaPatched = hasListenerExports()
	if not PmaPatched then
		print('^1[signal_radio] pma-voice is missing patches/signal_radio.patch. Radios stay off until you apply it and restart pma-voice.^7')
	elseif not hasUpgradePatch() then
		print('^3[signal_radio] pma-voice is missing patches/signal_radio_upgrade_1.patch. Apply it to fix stuck radio audio.^7')
	end
	return PmaPatched ~= before
end

CheckPmaPatch()

AddEventHandler('onResourceStart', function(resource)
	if resource ~= 'pma-voice' or not CheckPmaPatch() then return end
	for _, id in ipairs(GetPlayers()) do
		-- One player's error must not stop the others from getting a radio.
		pcall(RefreshSession, tonumber(id))
	end
end)
