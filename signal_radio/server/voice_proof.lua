-- Build step 1 test commands. Dev server only.
-- Enable with: setr signal_radio_voice_proof 1
if GetConvarInt('signal_radio_voice_proof', 0) ~= 1 then return end

local pma = exports['pma-voice']

local function reply(src, message)
	if src == 0 then
		print(('[voice_proof] %s'):format(message))
	else
		TriggerClientEvent('chat:addMessage', src, { args = { 'voice_proof', message } })
	end
end

local function register(name, handler)
	RegisterCommand(name, function(src, args)
		if src ~= 0 and not IsPlayerAceAllowed(src, 'radio.admin') then
			return reply(src, 'You need the radio.admin ACE.')
		end
		handler(src, args)
	end, false)
end

local function channelArg(src, args)
	local channel = tonumber(args[1])
	if not channel or channel <= 0 then
		reply(src, 'Give a channel number above 0.')
		return nil
	end
	return channel
end

register('vp_join', function(src, args)
	local channel = channelArg(src, args)
	if not channel then return end
	pma:setPlayerRadio(src, channel)
	reply(src, ('Joined channel %d.'):format(channel))
end)

register('vp_leave', function(src)
	pma:setPlayerRadio(src, 0)
	reply(src, 'Left the radio.')
end)

-- /vp_listen <channel> <1 = with audio, 0 = talk events only>
register('vp_listen', function(src, args)
	local channel = channelArg(src, args)
	if not channel then return end
	local withAudio = args[2] ~= '0'
	local added = pma:addRadioListener(src, channel, withAudio)
	reply(src, ('Listener on channel %d, withAudio=%s, added=%s.'):format(channel, tostring(withAudio), tostring(added)))
end)

register('vp_unlisten', function(src, args)
	local channel = channelArg(src, args)
	if not channel then return end
	local removed = pma:removeRadioListener(src, channel)
	reply(src, ('Removed from channel %d: %s.'):format(channel, tostring(removed)))
end)

register('vp_state', function(src, args)
	local channel = channelArg(src, args)
	if not channel then return end
	local ids, talkingById = {}, {}
	for id, talking in pairs(pma:getPlayersInRadioChannel(channel)) do
		ids[#ids + 1] = id
		talkingById[id] = talking
	end
	table.sort(ids)

	local members = {}
	for i = 1, #ids do
		local id = ids[i]
		members[i] = ('%d%s (%s)'):format(id, id == src and ' [you]' or '', talkingById[id] and 'talking' or 'idle')
	end
	reply(src, ('Channel %d members: %s'):format(channel, #members > 0 and table.concat(members, ', ') or 'none'))
end)
