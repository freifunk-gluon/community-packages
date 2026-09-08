-- The networks a node carries besides the mesh's own.
--
-- Either is a bridge over the interfaces gluon gave the matching role, and
-- what may be addressed on it is what tells the two apart.

local ip = require 'luci.ip' -- luci-lib-ip
local site = require 'gluon.site'
local util = require 'gluon.util'
local uci = require('simple-uci').cursor()

local M = {}

-- everything the internet routes; the rest is link-local, unique-local or
-- something the node made up for itself
local GLOBAL6 = ip.new('2000::/3')

-- what a /24 gets, and what the pool falls back from on anything smaller
local DEFAULT_START, DEFAULT_LIMIT = 100, 150

--[[
	private is a network behind the node: a range the mesh routes is announced,
	and anything else - the default included - is translated on the way out, so
	whatever is plugged in reaches the internet either way.

	exposed is a piece of the mesh itself. There is no address of the node's to
	translate onto and no way to it other than the announcement, so a range the
	mesh does not route would leave it unreachable rather than merely private,
	and is refused instead of quietly turned into a NATed network.
]]
M.NETWORKS = {
	{ name = 'private', role = 'private', default4 = '192.168.66.1/24', routed_only = false },
	{ name = 'exposed', role = 'exposed', routed_only = true },
}

--[[
	A link network is the transit to a device bridging this node to another
	one - a 60 GHz radio, typically. The node takes the first address of a /30
	and the device the second, the device is given a static route back, and the
	/30 is announced so the mesh can reach the device to manage it.

	This is not the node carrying another address of its own the way it used to
	before ffgraz-static-ip stopped putting addresses on interfaces: the second
	address of the pair belongs to something else.
]]
M.LINK_ROLE = 'link'

-- a /30 and nothing else: the pair of usable addresses is the whole point
function M.linknet(cidr)
	if type(cidr) ~= 'string' then
		return nil
	end

	local parsed = ip.new(cidr)

	if not (parsed and parsed:is4() and parsed:prefix() == 30) then
		return nil
	end

	return parsed:network():string() .. '/30'
end

-- what goes on the node, and what the device on the other end is given
function M.link_hosts(cidr)
	local parsed = M.linknet(cidr) and ip.new(cidr)

	if not parsed then
		return nil
	end

	return parsed:minhost():string(), parsed:maxhost():string(), parsed:mask():string()
end

--[[
	The interfaces gluon gave the link role, in the order they are configured,
	each with the netifd interface built for it.

	Entries without an address are kept: the config mode page lists them so the
	operator has somewhere to put one, and the upgrade script skips them.
]]
function M.links()
	local ret = {}

	uci:foreach('gluon', 'interface', function(section)
		local roles = section.role or {}

		if type(roles) == 'string' then
			roles = { roles }
		end

		if util.contains(roles, M.LINK_ROLE) and section.name then
			local cidr = section.linknet
			-- short, because the bridge built from it is br-<name> and the
			-- kernel takes 15 characters for a device name
			local interface = 'lnk' .. (#ret + 1)

			table.insert(ret, {
				section = section['.name'],
				device = section.name,
				cidr = cidr,
				prefix = M.linknet(cidr),
				interface = interface,
			})
		end
	end)

	return ret
end

function M.get(name)
	for _, network in ipairs(M.NETWORKS) do
		if network.name == name then
			return network
		end
	end
end

-- the bridge netifd builds for it
function M.device(name)
	return 'br-' .. name
end

--[[
	The prefix to announce for an address, or nil.

	Only for an address out of the globally routed range: a unique-local one
	means nothing outside this node, and announcing it would put a prefix
	everyone else also made up for themselves into the mesh.
]]
function M.public6(address)
	if type(address) ~= 'string' or not address:match('/%d') then
		return nil
	end

	local parsed = ip.new(address)

	if not (parsed and parsed:is6() and GLOBAL6:contains(parsed)) then
		return nil
	end

	return parsed:network():string() .. '/' .. parsed:prefix()
end

--[[
	The same for IPv4, against the mesh's own range rather than the globally
	routed one: there is no IPv4 equivalent of "assigned to me and routed from
	anywhere", so what makes an address real to the other nodes is being part
	of what the mesh itself carries.
]]
function M.routed4(address)
	if type(address) ~= 'string' or not address:match('/%d') then
		return nil
	end

	local prefix4 = site.prefix4()
	local mesh = prefix4 and ip.new(prefix4)
	local parsed = ip.new(address)

	if not (mesh and parsed and parsed:is4() and mesh:contains(parsed)) then
		return nil
	end

	return parsed:network():string() .. '/' .. parsed:prefix()
end

-- What a network is addressed with, whether or not it is routed
function M.address4(name)
	return uci:get('network', name, 'ipaddr')
end

function M.address6(name)
	return uci:get('network', name, 'ip6addr')
end

--[[
	Where the DHCP pool starts and how many addresses it holds, as the offsets
	from the network address that dnsmasq wants - or nil when the range is too
	small to hand anything out.

	The defaults are a /24's, and on anything smaller they point outside the
	subnet entirely: on a /29 a pool of 150 addresses starting at .100 leaves
	dnsmasq with nothing it can give a client. The node itself sits on the
	first address, so the pool starts on the second.
]]
function M.pool4(address)
	local parsed = type(address) == 'string' and ip.new(address)

	if not (parsed and parsed:is4()) then
		return nil
	end

	-- everything but the network and broadcast addresses
	local usable = 2 ^ (32 - parsed:prefix()) - 2

	if usable < 2 then
		return nil
	end

	if DEFAULT_START + DEFAULT_LIMIT - 1 <= usable then
		return DEFAULT_START, DEFAULT_LIMIT
	end

	-- offset 2 is the address after the node's own
	return 2, usable - 1
end

return M
