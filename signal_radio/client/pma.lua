-- Calls pma-voice exports for the other client files.
-- A pma-voice without the signal_radio patch has no export for some calls.
-- Such a call prints one warning and does nothing, instead of raising a script error.
local warned = {}

local function lookup(name)
	local ok, export = pcall(function()
		return exports['pma-voice'][name]
	end)
	if ok then return export end
	return nil
end

Pma = setmetatable({}, {
	__index = function(_, name)
		return function(_, ...)
			local export = lookup(name)
			if export == nil then
				if not warned[name] then
					warned[name] = true
					print(('^3[signal_radio] pma-voice has no %s export. Apply patches/signal_radio.patch to pma-voice.^7'):format(name))
				end
				return nil
			end
			return export(exports['pma-voice'], ...)
		end
	end,
})
