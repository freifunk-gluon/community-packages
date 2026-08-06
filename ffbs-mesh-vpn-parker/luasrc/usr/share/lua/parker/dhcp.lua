-- Helpers for the DHCPv4 options our node hands to its clients.
--
-- They all live in one uci list, so everyone who writes to it may only
-- ever touch their own entries.

local dhcp = {}

-- The dnsmasq section serving our clients, see noderoute.lua.
local CLIENT_SECTION = 'client'

-- A dhcp_option list in which one option carries the given values, and
-- everybody else's entries are where they were. Without values the
-- option is dropped, cleaning up after whoever has stopped configuring
-- it. Returns nil when the list already says exactly that, so a caller
-- can skip its commit and the dnsmasq reload that follows it.
function dhcp.merge_option(options, name, values)
	if type(options) == 'string' then
		-- An option that is not stored as a list yet.
		options = { options }
	end

	local entry
	if values ~= nil and #values > 0 then
		entry = name .. ',' .. table.concat(values, ',')
	end

	local result = {}
	local kept, dropped = false, false
	for _, option in ipairs(options or {}) do
		-- Ours are the bare name and the name with its values; every
		-- other entry stays where it is.
		if option ~= name and option:sub(1, #name + 1) ~= name .. ',' then
			table.insert(result, option)
		elseif option == entry and not kept then
			table.insert(result, option)
			kept = true
		else
			dropped = true
		end
	end

	if entry ~= nil and not kept then
		table.insert(result, entry)
	elseif not dropped then
		return nil
	end
	return result
end

-- Announces one option with the given values to our clients. Returns
-- whether uci was touched.
function dhcp.set_client_option(uci, name, values)
	local options = dhcp.merge_option(uci:get_list('dhcp', CLIENT_SECTION, 'dhcp_option'), name, values)
	if options == nil then
		return false
	end

	if #options > 0 and uci:get('dhcp', CLIENT_SECTION) == nil then
		-- noderoute creates the section when it configures the client
		-- network, but the option needs a place to live until then.
		uci:section('dhcp', 'dhcp', CLIENT_SECTION)
	end

	uci:set('dhcp', CLIENT_SECTION, 'dhcp_option', options)
	uci:commit('dhcp')
	return true
end

return dhcp
