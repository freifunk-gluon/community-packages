-- Helpers for the DHCPv4 options our node hands to its clients.
--
-- All options share one uci list, so each writer replaces only its own
-- entry.

local dhcp = {}

-- The dnsmasq section serving our clients: the one gluon-client-bridge
-- creates, which noderoute.lua switches on while the node routes.
local CLIENT_SECTION = 'local_client'

function dhcp.is_ipv4(addr)
	local octets = { addr:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$') }
	if #octets ~= 4 then
		return false
	end
	for _, octet in ipairs(octets) do
		if tonumber(octet) > 255 then
			return false
		end
	end
	return true
end

-- The addresses of a site key dnsmasq will accept, in the given order.
-- dnsmasq refuses to start on an option it cannot parse, so handing it
-- anything else would take down DHCP and DNS for our clients.
function dhcp.ipv4_addresses(addrs)
	local result = {}
	for _, addr in ipairs(addrs) do
		if dhcp.is_ipv4(addr) then
			table.insert(result, addr)
		end
	end
	return result
end

-- Returns options with the entry of option name set to the given values,
-- or removed when there are none. Other entries keep their place.
-- Returns nil when the list does not change, so that a caller can skip
-- its commit.
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
		-- Our entries are "name" and "name,values".
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
		-- gluon-client-bridge creates the section before we run, but a
		-- Gluon that does not has to get it from us: make it what
		-- Gluon would have made.
		uci:section('dhcp', 'dhcp', CLIENT_SECTION, { interface = 'client', ignore = true })
	end

	-- simple-uci deletes the option when options is empty.
	uci:set('dhcp', CLIENT_SECTION, 'dhcp_option', options)
	uci:commit('dhcp')
	return true
end

return dhcp
