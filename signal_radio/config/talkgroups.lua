Config = Config or {}

-- Each talkgroup maps to one pma-voice channel. Keep channel numbers stable.
-- frequency is in kHz (450025 is 450.025 MHz). A civilian who dials it hears only encrypted noise.
Config.Talkgroups = {
	{ id = 'qps_ops1', label = 'OPS 1', channel = 1001, frequency = 450025 },
	{ id = 'qps_ops2', label = 'OPS 2', channel = 1002, frequency = 450050 },
	{ id = 'qps_cmd', label = 'Command', channel = 1003, frequency = 450075, seniorOnly = true },

	{ id = 'qas_ops', label = 'OPS', channel = 1011, frequency = 450125 },
	{ id = 'qas_cmd', label = 'Command', channel = 1012, frequency = 450150, seniorOnly = true },

	{ id = 'qfd_ops', label = 'OPS', channel = 1021, frequency = 450225 },
	{ id = 'qfd_cmd', label = 'Command', channel = 1022, frequency = 450250, seniorOnly = true },

	{ id = 'rfsq_ops', label = 'OPS', channel = 1031, frequency = 450325 },
	{ id = 'rfsq_cmd', label = 'Command', channel = 1032, frequency = 450350, seniorOnly = true },
	-- Simplex works with no tower. Only players within range (metres) hear each other.
	{ id = 'rfsq_fire', label = 'Fireground', channel = 1033, frequency = 450375, simplex = true, range = 500.0 },

	{ id = 'interop', label = 'Interop', channel = 1091, frequency = 450500 },
}

Config.Zones = {
	{ id = 'qps', label = 'QPS', talkgroups = { 'qps_ops1', 'qps_ops2', 'qps_cmd' } },
	{ id = 'qas', label = 'QAS', talkgroups = { 'qas_ops', 'qas_cmd' } },
	{ id = 'qfd', label = 'QFD', talkgroups = { 'qfd_ops', 'qfd_cmd' } },
	{ id = 'rfsq', label = 'RFSQ', talkgroups = { 'rfsq_ops', 'rfsq_fire', 'rfsq_cmd' } },
	{ id = 'interop', label = 'Interop', talkgroups = { 'interop' } },
}

Config.PanicCooldownMs = 30000
Config.PanicPriorityMs = 60000
Config.ScanVolume = 0.6
