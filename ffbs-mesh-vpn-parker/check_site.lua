-- dnsmasq parses the addresses of an option with inet_pton() and does not
-- start if one of them is invalid. inet_pton() rejects numbers above 255
-- and numbers with a leading zero.
local function is_ipv4(addr)
	if type(addr) ~= 'string' then
		return false
	end
	local octets = { addr:match('^(%d+)%.(%d+)%.(%d+)%.(%d+)$') }
	if #octets ~= 4 then
		return false
	end
	for _, octet in ipairs(octets) do
		if (#octet > 1 and octet:sub(1, 1) == '0') or tonumber(octet) > 255 then
			return false
		end
	end
	return true
end

need_string({ "parker", "config_server" })
need_string({ "parker", "config_pubkey" })
need_array({ "parker", "client_ntp_servers4" }, function(addr)
	need(addr, is_ipv4, true,
		'be an IPv4 address (four numbers from 0 to 255 without leading zeros, separated by dots)')
end, false)
need_boolean({ "parker", "disable_client_snooping" }, false)
need_boolean({ "parker", "dhcp_authoritative" }, false)
need_string_array({'ntp_servers'})
need_number({ "mesh_vpn", "parker", "mtu" })

-- Every routing node is the DNS server of its clients (DHCPv4 and RDNSS
-- point to the node itself), so its dnsmasq needs a fixed upstream. Without
-- dns.servers it has none, and Gluon leaves peerdns on: a mesh-only node then
-- takes the client gateway address from its neighbour's lease as its own
-- resolver, and that address is local on its wg interfaces.
need({ 'dns', 'servers' }, function(servers)
	return type(servers) == 'table' and #servers > 0
end, true, 'be set, because parker nodes answer the DNS queries of their clients '
	.. 'and forward them to these servers')
