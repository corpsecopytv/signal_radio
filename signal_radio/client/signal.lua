local pma = Pma

local BARS_FOR_TIER = { full = 4, worn = 2, bad = 1, none = 0 }
local talkgroupsById, talkgroupsByChannel = {}, {}
for _, talkgroup in ipairs(Config.Talkgroups) do
	talkgroupsById[talkgroup.id] = talkgroup
	talkgroupsByChannel[talkgroup.channel] = talkgroup
end

local lastBars = nil

--- @param listenerChannel number|nil the scanned channel, or nil for the selected talkgroup
function GetRadioTalkgroup(listenerChannel)
	if listenerChannel then return talkgroupsByChannel[listenerChannel] end
	return talkgroupsById[Radio.state.talkgroup]
end

function IsOnSimplex()
	local talkgroup = GetRadioTalkgroup(nil)
	return talkgroup ~= nil and talkgroup.simplex == true
end

--- @return string tier full, worn, bad or none
function ComputeSignalTier(coords, inVehicle)
	if #Radio.towers == 0 then return 'full' end
	local best = 0.0
	local bonus = inVehicle and Config.Signal.vehicleRangeBonus or 1.0
	for _, tower in ipairs(Radio.towers) do
		if tower.online then
			local dx, dy = coords.x - tower.x, coords.y - tower.y
			local quality = 1.0 - math.sqrt(dx * dx + dy * dy) / (tower.radius * bonus)
			if quality > best then best = quality end
		end
	end
	if best >= Config.Signal.fullQuality then return 'full' end
	if best >= Config.Signal.wornQuality then return 'worn' end
	if best > 0.0 then return 'bad' end
	return 'none'
end

local function updateBars()
	local bars = IsOnSimplex() and 4 or BARS_FOR_TIER[Radio.signal]
	if bars ~= lastBars then
		lastBars = bars
		SendToHandset('signal', { bars = bars })
	end
end

function UpdateRadioSignal()
	local ped = PlayerPedId()
	local tier = ComputeSignalTier(GetEntityCoords(ped), IsPedInAnyVehicle(ped, false))
	if tier ~= Radio.signal then
		Radio.signal = tier
		TriggerServerEvent('signal_radio:signal', tier)
		pma:refreshRadioAudio()
	end
	updateBars()

	-- Direct radio and simplex range depend on where people stand, so recheck them during traffic.
	if next(Radio.talkerSignal) then
		pma:refreshRadioAudio()
	end
end

CreateThread(function()
	while true do
		Wait(Config.Signal.updateMs)
		UpdateRadioSignal()
	end
end)
