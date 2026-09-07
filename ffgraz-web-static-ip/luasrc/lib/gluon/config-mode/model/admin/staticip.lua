local uci = require("simple-uci").cursor()
local ip = require 'luci.ip'
local site = require 'gluon.site'

-- The node has one address per family, both on loopback (310-static-ip).
-- An empty field means "keep the address derived from the node's MAC".

local function host(address)
	return address and address:match('^[^/]+')
end

-- the IPv4 one shares loopback with 127.0.0.1
local function current4()
	for _, address in ipairs(uci:get_list('network', 'loopback', 'ipaddr')) do
		if not address:match('^127%.') then
			return host(address)
		end
	end
end

local f = Form(translate("Static IPs"))

local function warn_temporary(s, id, address, prefix, range)
	if not (address and prefix) then
		return
	end

	local tmp = ip.new(prefix, range)
	if not tmp:contains(ip.new(address):host()) then
		return
	end

	s:element('model/warning', {
		content = string.format(translate(
			'The address %s is in the temporary address range %s.<br />' ..
			'It should be replaced by a properly assigned address as soon as possible.'
		), address, tmp:string()),
	}, id)
end

local function setting(s, option, title, description, datatype, effective)
	local v = s:option(Value, option, title, description)
	v.datatype = datatype
	v.optional = true
	v.default = effective

	function v:write(data)
		uci:set("gluon-static-ip", "loopback", option, host(data))
	end
end

if site.prefix4() then
	local s = f:section(Section, nil, translate('Configure the IPv4 address of your node.'))
	local effective = host(uci:get('gluon-static-ip', 'loopback', 'ip4')) or current4()

	if site.node_prefix4() and site.node_prefix4_temporary() then
		warn_temporary(s, 'w4', effective, site.node_prefix4(), site.node_prefix4_range())
	end

	setting(s, 'ip4', translate("IPv4 for this node"),
		translate("IPv4 address (e.g. 1.2.3.4)"), 'ip4addr', effective)
end

if site.prefix6() then
	local s = f:section(Section, nil, translate('Configure the IPv6 address of your node.'))
	local effective = host(uci:get('gluon-static-ip', 'loopback', 'ip6'))
		or host(uci:get('network', 'loopback', 'ip6addr'))

	if site.node_prefix6() and site.node_prefix6_temporary() then
		warn_temporary(s, 'w6', effective, site.node_prefix6(), site.node_prefix6_range(128))
	end

	setting(s, 'ip6', translate("IPv6 for this node"),
		translate("IPv6 address (e.g. aa:bb:cc:dd:ee::ff)"), 'ip6addr', effective)
end

function f:write()
	uci:save("gluon-static-ip")
end

return f
