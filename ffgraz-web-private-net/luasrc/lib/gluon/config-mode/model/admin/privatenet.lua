local uci = require("simple-uci").cursor()
local ip = require 'luci.ip'
local privatenet = require 'gluon.privatenet'

local NETWORK = privatenet.NETWORK

local f = Form(translate('Private network'))

--[[
	Whether what the node is configured with right now is a range the rest of
	the mesh routes here, or one that means nothing outside this node and is
	translated on the way out. Which of the two it is follows from the address
	itself, so it is worth saying rather than leaving to be worked out.
]]
local function shared(prefix)
	if prefix then
		return translatef('Shared with the mesh as %s.', prefix)
	end

	return translate('Kept behind this node, reached through its own address.')
end

local s = f:section(Section, nil, translate(
	'A network of your own behind the node, with its own addresses. Whatever '
	.. 'you plug into the ports set aside for it lands here, and reaches the '
	.. 'internet through the mesh.'
))

local subnet4 = s:option(Value, 'subnet4', translate('IPv4 range'),
	translate('The node takes the first address, for example 192.168.66.1/24. '
		.. 'A range out of the mesh\'s own is announced and reachable from the '
		.. 'other nodes; any other stays behind this one.')
	.. ' ' .. shared(privatenet.routed4(privatenet.address4())))
subnet4.default = privatenet.address4()

function subnet4:validate()
	return self.data ~= nil and ip.new(self.data) ~= nil
		and ip.new(self.data):is4() and self.data:match('/%d') ~= nil
end

local subnet6 = s:option(Value, 'subnet6', translate('IPv6 range'),
	translate('Paste the range you were assigned, with the node\'s address in '
		.. 'it, for example 2001:db8:1234::1/64. The mesh is told to route it '
		.. 'here. Leave empty for one made up locally, which stays behind the '
		.. 'node.')
	.. ' ' .. shared(privatenet.public6(privatenet.address6())))
subnet6.optional = true
subnet6.default = privatenet.address6() or uci:get('network', 'globals', 'ula_prefix')

function subnet6:validate()
	if self.data == nil or self.data == 'auto' then
		return true
	end

	-- either an assigned range, which is announced, or a made up one, which
	-- is not; anything else is neither
	local address = ip.new(self.data)

	return privatenet.public6(self.data) ~= nil
		or (address ~= nil and address:is6() and self.data:match('/%d') ~= nil)
end

function f:write()
	uci:set('network', NETWORK, 'ipaddr', subnet4.data)

	--[[
		An assigned range goes on the bridge and gets announced; a made up one
		is a prefix to carve from. Whichever is not in use is removed, or the
		node would keep addressing itself out of both.
	]]
	if privatenet.public6(subnet6.data) then
		uci:set('network', NETWORK, 'ip6addr', subnet6.data)
		uci:delete('network', 'globals', 'ula_prefix')
	else
		uci:delete('network', NETWORK, 'ip6addr')
		uci:set('network', 'globals', 'ula_prefix', subnet6.data)
	end

	uci:save('network')

	-- the bridge, the DHCP server and the firewall around them are all set up
	-- when the configuration is generated
	uci:set('gluon', 'core', 'reconfigure', true)
	uci:save('gluon')
	uci:commit('gluon')
	uci:commit('network')
end

return f
