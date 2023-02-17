local uci = require("simple-uci").cursor()
local site = require 'gluon.site'

local f = Form(translate("Public IP"))

local s = f:section(Section, nil, translate(
	'Configuration for OLSR Public IP. You will get the necesarry details from the mesh admins.'
))

local enabled = s:option(Flag, "enabled", translate("Enabled"))
enabled.default = uci:get_bool('gluon', 'olsr_public_ip', 'enabled')

local publicIP = s:option(Value, "publicip", translate("Public IP"), translate("IPv4 Address"))
publicIP:depends(enabled, true)
publicIP.datatype = "maxlength(32)"
publicIP.default = uci:get('gluon-static-ip', 'olsr_public_ip', 'ip4')
publicIP.required = true

local peeraddr = s:option(Value, "peeraddr", translate("Peer IP"), translate("IPv4 Address"))
peeraddr:depends(enabled, true)
peeraddr.datatype = "maxlength(32)"
peeraddr.default = uci:get('gluon', 'olsr_public_ip', 'peeraddr') or site.olsr_public_ip_default_peeraddr()
peeraddr.required = true

function f:write()
	uci:section('gluon', 'olsr_public_ip', 'olsr_public_ip', {
		enabled = enabled.data,
		peeraddr = peeraddr.data,
	})
	uci:save('gluon')

	uci:section('gluon-static-ip', 'interface', 'olsr_public_ip', {
		ip4 = publicIP.data,
	})
	uci:save('gluon-static-ip')
end

return f
