-- Connects the radio to Night Shifts MDT.
-- TODO: confirm in Night Shifts docs: the exports for shift status, department and rank.
-- Until then, only dev profiles work. Enable them with: setr signal_radio_dev_profiles 1

local devProfilesEnabled = GetConvarInt('signal_radio_dev_profiles', 0) == 1
local devProfiles = {}

--- @return table|nil profile { department = codeplug key, senior = boolean }
function GetRadioProfile(source)
	if devProfilesEnabled then
		return devProfiles[source]
	end
	-- TODO: confirm in Night Shifts docs: read the active shift, department and rank here.
	return nil
end

-- Every player can use a radio. A player with no profile gets the civilian radio.
function canUseRadio(_)
	return true
end

--- The jammer needs no item. Any player can walk up to a tower and start the install.
function canUseJammer(_)
	return true
end

if devProfilesEnabled then
	-- /radio_dev <qps|qas|qfd|rfsq|off> [senior]
	RegisterCommand('radio_dev', function(src, args)
		if src == 0 or not IsPlayerAceAllowed(src, 'radio.admin') then return end
		local department = args[1]
		if department == 'off' then
			devProfiles[src] = nil
		elseif Config.Codeplugs[department] then
			devProfiles[src] = { department = department, senior = args[2] == 'senior' }
		else
			return
		end
		RefreshSession(src)
	end, false)

	AddEventHandler('playerDropped', function()
		devProfiles[source] = nil
	end)
else
	CreateThread(function()
		print('[signal_radio] Night Shifts is not connected yet, so every player gets a civilian radio.')
	end)
end
