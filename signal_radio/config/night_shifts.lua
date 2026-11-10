Config = Config or {}

-- Connects the radio to Night Shifts MDT.
-- Run radio_ns_dump in the server console to see your department IDs.
Config.NightShifts = {
	-- How often the radio checks each player's shift.
	checkMs = 5000,

	-- Maps each Night Shifts department ID to a codeplug in config/codeplugs.lua.
	-- A player on a department that is not listed gets a civilian radio.
	departments = {
		-- [1] = 'qps',
		-- [2] = 'qas',
		-- [3] = 'qfd',
		-- [4] = 'rfsq',
	},

	-- TODO: confirm in Night Shifts docs: the status code that the panic binding sets.
	panicStatusCodes = { panic = true },

	manDown = {
		delayMs = 30000,
		cooldownMs = 60000,
		callType = 'Panic',
		-- TODO: confirm in Night Shifts docs: whether 1 is the highest priority.
		priority = 1,
		requiresPolice = 1,
		requiresAmbulance = 1,
		requiresFire = 0,
		requiresTow = 0,
		requiresCouncil = 0,
	},
}
