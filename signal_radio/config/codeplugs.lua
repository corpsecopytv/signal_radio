Config = Config or {}

-- Civilian radios tune one frequency at a time. Frequencies are in kHz.
-- The bands match a dual-band handheld: 136 to 174 MHz and 400 to 520 MHz.
-- Each band is { lowest, highest, frequency to tune when the band is chosen }.
Config.Civilian = {
	skin = 'uv5r',
	defaultFrequency = 476425,
	stepKHz = 25,
	bands = { { 136000, 174000, 146000 }, { 400000, 520000, 476425 } },
}

-- A codeplug is the set of zones a radio can use, and what it can scan.
-- Every emergency radio has every zone, with its own department first.
-- scan is the starting scan list. Players change their own list on the radio.
-- Talkgroups marked seniorOnly appear only for senior ranks.
Config.Codeplugs = {
	qps = {
		skin = 'apx2000',
		zones = { 'qps', 'qas', 'qfd', 'rfsq', 'interop' },
		scan = { 'qps_ops1', 'qps_ops2', 'interop' },
	},
	qas = {
		skin = 'apx2000',
		zones = { 'qas', 'qps', 'qfd', 'rfsq', 'interop' },
		scan = { 'qas_ops', 'interop' },
	},
	qfd = {
		skin = 'apx8000xe_fire',
		zones = { 'qfd', 'qps', 'qas', 'rfsq', 'interop' },
		scan = { 'qfd_ops', 'interop' },
	},
	rfsq = {
		skin = 'apx8000xe_fire',
		zones = { 'rfsq', 'qps', 'qas', 'qfd', 'interop' },
		scan = { 'rfsq_ops', 'interop' },
	},
}
