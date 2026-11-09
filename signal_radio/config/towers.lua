Config = Config or {}

-- Placeholder sites with overlapping coverage. Replace them in-game with /radio_tower.
-- Once an admin changes the list, the saved list replaces this one.
Config.Towers = {
	{ id = 'legion', label = 'Legion Square', x = 195.0, y = -934.0, z = 30.0, radius = 2500.0 },
	{ id = 'vespucci', label = 'Vespucci', x = -1200.0, y = -1200.0, z = 5.0, radius = 2500.0 },
	{ id = 'mirror', label = 'Mirror Park', x = 1100.0, y = -500.0, z = 65.0, radius = 2500.0 },
	{ id = 'chumash', label = 'Chumash', x = -3100.0, y = 1100.0, z = 20.0, radius = 2500.0 },
	{ id = 'harmony', label = 'Harmony', x = 600.0, y = 2700.0, z = 42.0, radius = 2500.0 },
	{ id = 'tataviam', label = 'Tataviam', x = 2550.0, y = 380.0, z = 108.0, radius = 2500.0 },
	{ id = 'sandy', label = 'Sandy Shores', x = 1850.0, y = 3700.0, z = 33.0, radius = 2500.0 },
	{ id = 'grapeseed', label = 'Grapeseed', x = 1700.0, y = 4800.0, z = 42.0, radius = 2500.0 },
	{ id = 'paleto', label = 'Paleto Bay', x = -150.0, y = 6300.0, z = 31.0, radius = 2500.0 },
}

-- Signal quality runs from 1.0 at a tower to 0.0 at the edge of its radius.
Config.Signal = {
	updateMs = 1500,
	fullQuality = 0.35,
	wornQuality = 0.15,
	vehicleRangeBonus = 1.15,
	-- Every radio also works like a small tower for other radios. Distances are in metres.
	-- Direct quality uses the same rules as a tower, across directRange.
	-- Inside nearClearRange the talker sounds clearest.
	directRange = 500.0,
	nearClearRange = 100.0,
}

-- People near a receiving radio hear its speaker.
Config.Bleed = {
	range = 10.0,
	maxVolume = 0.7,
	minVolume = 0.05,
	updateMs = 500,
}

Config.Sabotage = {
	sabotageSeconds = 120,
	offlineSeconds = 300,
	cooldownSeconds = 1800,
	interactDistance = 3.0,
}
