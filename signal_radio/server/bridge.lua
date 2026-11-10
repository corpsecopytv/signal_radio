-- Connects the radio to Night Shifts MDT.
-- A test profile, set in the admin panel on a dev server, takes priority over a shift.

local MDT = 'night_shifts_mdt'
local settings = Config.NightShifts
local devToolsEnabled = GetConvarInt('signal_radio_dev_tools', 0) == 1
local devProfiles = {}
local reportedDepartments = {}
local wasPanic = {}

local function isMdtStarted()
	return GetResourceState(MDT) == 'started'
end

--- @return table|nil shift nil means Night Shifts could not be read.
local function readShift(source)
	if not isMdtStarted() then return nil end
	local ok, shift = pcall(function()
		return exports[MDT]:GetUserShiftData(source)
	end)
	if not ok or type(shift) ~= 'table' then return nil end
	return shift
end

local function cleanCallsign(value)
	if type(value) ~= 'string' then return nil end
	local callsign = value:gsub('[^%w%- ]', ''):sub(1, 12)
	-- Night Shifts uses UNASSIGNED for a shift with no callsign.
	if callsign == '' or callsign:upper() == 'UNASSIGNED' then return nil end
	return callsign
end

local function isPanicStatus(shift)
	-- TODO: confirm in Night Shifts docs: the statusCode field. The shipped guide does not list it.
	local statusCode = shift.statusCode
	return type(statusCode) == 'string' and settings.panicStatusCodes[statusCode:lower()] == true
end

--- @return table|nil profile { department = codeplug key, senior = boolean, callsign = string|nil, panic = boolean }
--- @return boolean known false when Night Shifts could not be read
function GetRadioProfile(source)
	if devProfiles[source] then
		return devProfiles[source], true
	end

	local shift = readShift(source)
	if not shift then return nil, false end
	if not shift.isOnShift then return nil, true end

	local departmentId = tonumber(shift.departmentId)
	local department = departmentId and settings.departments[departmentId]
	if not department or not Config.Codeplugs[department] then
		if departmentId and not reportedDepartments[departmentId] then
			reportedDepartments[departmentId] = true
			print(('[signal_radio] Night Shifts department %d has no codeplug in config/night_shifts.lua.'):format(departmentId))
		end
		return nil, true
	end

	return {
		department = department,
		-- Senior ranks are not decided yet, so a shift does not give the command channel.
		senior = false,
		callsign = cleanCallsign(shift.callsign),
		panic = isPanicStatus(shift),
	}, true
end

-- Every player can use a radio. A player with no profile gets the civilian radio.
function canUseRadio(_)
	return true
end

--- Sabotage needs no item. Any player can walk up to a tower and start it.
function canSabotage(_)
	return true
end

--- Sets the player's MDT status to panic.
function SendMdtPanic(source)
	local shift = readShift(source)
	if not shift or not shift.isOnShift then return end
	local ok, err = pcall(function()
		exports[MDT]:UpdateShiftStatusByBindingByServerId(source, 'panic', function(success, result)
			if not success then
				print(('[signal_radio] Night Shifts refused the panic for player %d: %s'):format(source, tostring(result)))
			end
		end)
	end)
	if not ok then
		print(('[signal_radio] Could not send the panic to Night Shifts: %s'):format(tostring(err)))
	end
end

--- Creates a man-down call on the MDT.
--- @return boolean sent
function SendMdtManDown(source, callsign)
	local shift = readShift(source)
	if not shift or not shift.isOnShift then return false end

	local manDown = settings.manDown
	local coords = GetEntityCoords(GetPlayerPed(source))
	local ok, err = pcall(function()
		exports[MDT]:ForwardCallToMDT({
			callType = manDown.callType,
			description = ('Man-down alert from the radio of %s.'):format(callsign),
			x = coords.x,
			y = coords.y,
			z = coords.z,
			postal = shift.postal,
			street = shift.street,
			zone = shift.zone,
			callerName = callsign,
			contactDetails = 'Radio',
			requiresPolice = manDown.requiresPolice,
			requiresAmbulance = manDown.requiresAmbulance,
			requiresFire = manDown.requiresFire,
			requiresTow = manDown.requiresTow,
			requiresCouncil = manDown.requiresCouncil,
			priority = manDown.priority,
		}, function(success)
			if not success then
				print(('[signal_radio] Night Shifts refused the man-down call for player %d.'):format(source))
			end
		end)
	end)
	if not ok then
		print(('[signal_radio] Could not send the man-down call to Night Shifts: %s'):format(tostring(err)))
	end
	return ok
end

--- Night Shifts has no shift events, so the radio checks each player on a timer.
function CheckNightShifts()
	if not isMdtStarted() then return end
	for _, id in ipairs(GetPlayers()) do
		local source = tonumber(id)
		local profile, known = GetRadioProfile(source)
		if known then
			ApplyRadioProfile(source, profile)
			local panic = profile ~= nil and profile.panic == true
			-- Only a change to panic counts. The first read only records the status.
			if panic and wasPanic[source] == false then
				SendRadioPanicFromMdt(source)
			end
			wasPanic[source] = panic
		end
	end
end

CreateThread(function()
	Wait(settings.checkMs)
	if not isMdtStarted() then
		print('[signal_radio] Night Shifts is not running, so players with no test profile get a civilian radio.')
	elseif next(settings.departments) == nil then
		print('[signal_radio] No departments are set in config/night_shifts.lua. The Night Shifts tab in /radioadmin shows their IDs.')
	end
	while true do
		CheckNightShifts()
		Wait(settings.checkMs)
	end
end)

--- The Night Shifts details for the admin panel.
function GetNightShiftsInfo(target)
	local info = { running = isMdtStarted(), departments = {} }
	if not info.running then return info end

	local ok, departments = pcall(function()
		return exports[MDT]:GetDepartments()
	end)
	for _, department in ipairs(ok and type(departments) == 'table' and departments or {}) do
		local id = tonumber(department.id)
		info.departments[#info.departments + 1] = {
			id = id,
			name = department.departmentName,
			codeplug = id and settings.departments[id] or nil,
		}
	end
	table.sort(info.departments, function(a, b) return (a.id or 0) < (b.id or 0) end)
	info.shift = readShift(target)
	return info
end

function AreDevToolsEnabled()
	return devToolsEnabled
end

function GetDevProfile(source)
	return devProfiles[source]
end

--- Sets a test profile. The department 'off' removes it.
--- @return boolean set
function SetDevProfile(source, department, senior)
	if department == 'off' then
		devProfiles[source] = nil
	elseif Config.Codeplugs[department] then
		devProfiles[source] = { department = department, senior = senior == true }
	else
		return false
	end
	RefreshSession(source)
	return true
end

AddEventHandler('playerDropped', function()
	devProfiles[source] = nil
	wasPanic[source] = nil
end)
