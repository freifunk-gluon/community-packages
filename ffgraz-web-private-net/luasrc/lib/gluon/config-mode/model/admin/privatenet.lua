local uci = require("simple-uci").cursor()

local NETWORK = 'private'

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
	translate('An address range of your own, or "auto" to have one made up'))
subnet6.optional = true
subnet6.default = uci:get('network', 'globals', 'ula_prefix')

function f:write()
	uci:set('network', NETWORK, 'ipaddr', subnet4.data)
	uci:set('network', 'globals', 'ula_prefix', subnet6.data)
	uci:save('network')

	-- the bridge, the DHCP server and the firewall around them are all set up
	-- when the configuration is generated
	uci:set('gluon', 'core', 'reconfigure', true)
	uci:save('gluon')
	uci:commit('gluon')
	uci:commit('network')
end

return f
