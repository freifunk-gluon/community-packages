local uci = require("simple-uci").cursor()

local f = Form(translate("Private WAN DHCP"))

local s = f:section(Section, nil, translate('ffac-web-private-wan-dhcp:description'))

local enabled = s:option(Flag, "enabled", translate("Enabled"))
enabled.default = uci:get_bool('private-wan-dhcp', 'settings', 'enabled', false)

local ipaddr = s:option(Value, "ipaddr", translate("IP address"))
ipaddr.default = uci:get('private-wan-dhcp', 'settings', 'ipaddr', '192.168.222.1')

local netmask = s:option(Value, "netmask", translate("Netmask"))
netmask.default = uci:get('private-wan-dhcp', 'settings', 'netmask', '255.255.255.0')

local dns_server = s:option(Value, "dns_server", translate("Static DNS servers") ..  ' ' ..translate("IPv4"))
dns_server.default = uci:get('private-wan-dhcp', 'settings', 'dns_server', '9.9.9.9')

local uradvd_dns_server = s:option(Value, "uradvd_dns_server",
	translate("Static DNS servers") .. ' ' .. translate("IPv6"))
uradvd_dns_server.default = uci:get('private-wan-dhcp', 'settings', 'uradvd_dns_server', '2620:fe::fe')

function f:write()
	uci:set('private-wan-dhcp', 'settings', 'enabled', enabled.data)
	uci:set('private-wan-dhcp', 'settings', 'ipaddr', ipaddr.data)
	uci:set('private-wan-dhcp', 'settings', 'netmask', netmask.data)
	uci:set('private-wan-dhcp', 'settings', 'dns_server', dns_server.data)
	uci:set_list('private-wan-dhcp', 'settings', 'uradvd_dns_server', { uradvd_dns_server.data })
	uci:commit('private-wan-dhcp')
end

return f
