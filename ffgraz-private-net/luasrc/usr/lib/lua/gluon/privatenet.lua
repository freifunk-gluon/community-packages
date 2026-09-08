-- The private network of a node.
--
-- Its IPv6 range is either made up locally, in which case it stays behind the
-- node and is translated on the way out, or it is a range that was actually
-- assigned - and then the mesh has to be told the node is where it lives.

local ip = require 'luci.ip' -- luci-lib-ip
local site = require 'gluon.site'
local uci = require('simple-uci').cursor()

local M = {}

M.NETWORK = 'private'

-- everything the internet routes; the rest is link-local, unique-local or
-- something the node made up for itself
local GLOBAL6 = ip.new('2000::/3')

-- what a /24 gets, and what the pool falls back from on anything smaller
local DEFAULT_START, DEFAULT_LIMIT = 100, 150

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
	of what the mesh itself carries. Anything else - the default included - is
	translated on the way out.
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

-- What the private network is addressed with, whether or not it is routed
function M.address6()
	return uci:get('network', M.NETWORK, 'ip6addr')
end

function M.address4()
	return uci:get('network', M.NETWORK, 'ipaddr')
end

return M
