local uci = require("simple-uci").cursor()
local ip = require 'luci.ip'
local privatenet = require 'gluon.privatenet'

local NETWORK = privatenet.NETWORK

local f = Form(translate('Private network'))

local s = f:section(Section, nil, translate(
	'A network of your own behind the node, with its own addresses. Whatever '
	.. 'you plug into the ports set aside for it lands here, and reaches the '
	.. 'internet through the mesh.'
))

local subnet4 = s:option(Value, 'subnet4', translate('IPv4 range'),
	translate('The node takes the first address, for example 192.168.178.1/24'))
subnet4.default = uci:get('network', NETWORK, 'ipaddr')

local subnet6 = s:option(Value, 'subnet6', translate('IPv6 range'),
	translate('Paste the range you were assigned, with the node\'s address in '
		.. 'it, for example 2001:db8:1234::1/64. The mesh is told to route it '
		.. 'here. Leave empty for one made up locally, which stays behind the '
		.. 'node.'))
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
