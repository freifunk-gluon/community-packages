-- The private network of a node.
--
-- Its IPv6 range is either made up locally, in which case it stays behind the
-- node and is translated on the way out, or it is a range that was actually
-- assigned - and then the mesh has to be told the node is where it lives.

local ip = require 'luci.ip' -- luci-lib-ip
local uci = require('simple-uci').cursor()

local M = {}

M.NETWORK = 'private'

-- everything the internet routes; the rest is link-local, unique-local or
-- something the node made up for itself
local GLOBAL6 = ip.new('2000::/3')

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

-- What the private network is addressed with, whether or not it is routed
function M.address6()
	return uci:get('network', M.NETWORK, 'ip6addr')
end

return M
