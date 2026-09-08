local uci = require("simple-uci").cursor()
local site = require 'gluon.site'
local l3routes = require 'gluon.l3routes'
local publicip = require 'gluon.publicip'

local f = Form(translate("Public IP"))
-- adding and removing port forwards changes which sections the page has
f.reload = true

-- the interfaces gluon knows, the same list the routes page offers
local devices = l3routes.devices()

local s = f:section(Section, nil, translate(
	'Configuration for OLSR Public IP. You will get the necessary details from '
	.. 'the mesh admins.'
))

local enabled = s:option(Flag, "enabled", translate("Enabled"))
enabled.default = uci:get_bool('gluon', 'olsr_public_ip', 'enabled')

local mode = s:option(ListValue, "mode", translate("Use of the address"))
mode:value('local', translate('Give this node the public IP'))
mode:value('forward', translate('Forward the public IP to another device'))
mode.default = uci:get('gluon', 'olsr_public_ip', 'mode') or 'local'
mode:depends(enabled, true)

local publicIP = s:option(Value, "publicip", translate("Public IP"),
	translate("IPv4 address, for example 193.33.151.50"))
publicIP:depends(enabled, true)
publicIP.datatype = "ip4addr"
publicIP.default = uci:get('gluon', 'olsr_public_ip', 'ip4')

local peeraddr = s:option(Value, "peeraddr", translate("Peer IP"),
	translate("IPv4 address of the other end of the tunnel"))
peeraddr:depends(enabled, true)
peeraddr.datatype = "ip4addr"
peeraddr.default = uci:get('gluon', 'olsr_public_ip', 'peeraddr')
	or site.olsr_public_ip_default_peeraddr()

local fs = f:section(Section, translate('Forwarding'), translate(
	'The device the public IP belongs to. The node announces the address to '
	.. 'the mesh, takes the tunnel apart and passes what comes out on to this '
	.. 'device, which is where the address is configured.'
))


local target = fs:option(Value, "target", translate("Device address"),
	translate("IPv4 address this node reaches the device at. Leave empty when "
		.. "the device answers for the public IP on the interface below."))
target:depends(mode, 'forward')
target.datatype = "ip4addr"
target.optional = true
target.default = uci:get('gluon', 'olsr_public_ip', 'target')

local target_interface = fs:option(ListValue, "target_interface", translate("Interface"),
	translate("The interface the device is reached over"))
for _, dev in ipairs(devices) do
	target_interface:value(dev.interface, l3routes.device_label(dev))
end
target_interface.default = uci:get('gluon', 'olsr_public_ip', 'target_interface')
target_interface:depends(mode, 'forward')

-- Forwarding terminates the tunnel on the node's own address, so there has to
-- be one; without it the setup could not work and saying so beats writing a
-- configuration that quietly does nothing.
if not publicip.node_ip4() then
	fs:element('model/warning', {
		content = translate(
			'This node has no IPv4 address of its own, so it cannot take a '
			.. 'tunnel apart on behalf of another device. Forwarding will not work.'),
	}, 'no_node_ip')
end

--[[
	Port forwards, for a node that holds the address itself. What comes out of
	the tunnel is traffic from the internet, and the zone it arrives in
	forwards nothing on its own - only the ports listed here get through, each
	as the one forward rule firewall4 derives from its redirect.
]]

-- a single port or a range, the way firewall4 spells them; there is no
-- datatype for this in gluon-web-model
local function is_port(value)
	if type(value) ~= 'string' then
		return false
	end

	local first, last = value:match('^(%d+)%-(%d+)$')

	if not first then
		first = value:match('^(%d+)$')
	end
	if not first then
		return false
	end

	for _, port in ipairs({ first, last or first }) do
		local number = tonumber(port)

		if number < 1 or number > 65535 then
			return false
		end
	end

	return true
end

local entries = {}
uci:foreach('gluon', publicip.PORT, function(section)
	table.insert(entries, section)
end)

local forwards = {}

for _, entry in ipairs(entries) do
	local name = entry['.name']

	local title = entry.src_dport
		and translatef('Port %s to %s', entry.src_dport, entry.dest_ip or '?')
		or translate('New port forward')

	local ps = f:section(Section, title)

	local on = ps:option(Flag, name .. '_enabled', translate('Forward this'))
	on.default = entry.enabled ~= '0'

	local proto = ps:option(ListValue, name .. '_proto', translate('Protocol'))
	proto:value('tcp', 'TCP')
	proto:value('udp', 'UDP')
	proto:value('tcpudp', translate('TCP and UDP'))
	proto.default = entry.proto or 'tcp'

	local sport = ps:option(Value, name .. '_src_dport', translate('Public port'),
		translate('The port on the public address, for example 443 or 8000-8010'))
	sport.default = entry.src_dport

	function sport:validate()
		return is_port(self.data)
	end

	local dip = ps:option(Value, name .. '_dest_ip', translate('Device address'),
		translate('IPv4 address of the device the port leads to'))
	dip.datatype = 'ip4addr'
	dip.default = entry.dest_ip

	local dport = ps:option(Value, name .. '_dest_port', translate('Device port'),
		translate('Leave empty to use the public port'))
	dport.optional = true
	dport.default = entry.dest_port

	function dport:validate()
		return self.data == nil or is_port(self.data)
	end

	local dzone = ps:option(ListValue, name .. '_dest_interface', translate('Device network'),
		translate('The interface the device is reached over; nothing beyond it '
			.. 'becomes reachable'))
	for _, dev in ipairs(devices) do
		dzone:value(dev.interface, l3routes.device_label(dev))
	end
	dzone.default = entry.dest_interface or 'local_node'

	local comment = ps:option(Value, name .. '_comment', translate('Description'))
	comment.optional = true
	comment.default = entry.comment

	table.insert(forwards, {
		name = name,
		enabled = on,
		proto = proto,
		src_dport = sport,
		dest_ip = dip,
		dest_port = dport,
		dest_interface = dzone,
		comment = comment,
	})
end

local PORT_KEYS = {
	'enabled', 'proto', 'src_dport', 'dest_ip', 'dest_port', 'dest_interface', 'comment',
}

function f:write()
	uci:section('gluon', 'olsr_public_ip', 'olsr_public_ip', {
		enabled = enabled.data,
		mode = mode.data,
		ip4 = publicIP.data,
		peeraddr = peeraddr.data,
		target = target.data,
		target_interface = target_interface.data,
	})

	for _, forward in ipairs(forwards) do
		local values = {
			enabled = (not forward.enabled.data) and '0' or nil,
			proto = forward.proto.data,
			src_dport = forward.src_dport.data,
			dest_ip = forward.dest_ip.data,
			dest_port = forward.dest_port.data,
			dest_interface = forward.dest_interface.data,
			comment = forward.comment.data,
		}

		uci:section('gluon', publicip.PORT, forward.name)

		-- set() removes what is nil, which uci:section() on its own would leave
		-- behind from an earlier save
		for _, key in ipairs(PORT_KEYS) do
			uci:set('gluon', forward.name, key, values[key])
		end
	end

	-- the tunnel, the announcement, the nftables rule and the port forwards
	-- are all set up when the configuration is generated
	uci:set('gluon', 'core', 'reconfigure', true)
	uci:save('gluon')
	uci:commit('gluon')
end

-- Actions: adding and removing port forwards

local f_actions = Form(translate('Actions'))
f_actions.reload = true

local sa = f_actions:section(Section)

local action = sa:option(ListValue, 'action', translate('Action'))
action:value('add', translate('Add a port forward'))
if #entries > 0 then
	action:value('remove', translate('Remove a port forward'))
end

local remove = sa:option(ListValue, 'remove', translate('Port forward'))
for _, entry in ipairs(entries) do
	remove:value(entry['.name'],
		translatef('Port %s to %s', entry.src_dport or '?', entry.dest_ip or '?'))
end
remove:depends(action, 'remove')

local function free_name()
	local i = 1
	while uci:get('gluon', 'public_ip_port_' .. i) do
		i = i + 1
	end
	return 'public_ip_port_' .. i
end

function f_actions:write()
	if action.data == 'add' then
		uci:section('gluon', publicip.PORT, free_name(), {})
	elseif action.data == 'remove' and remove.data then
		uci:delete('gluon', remove.data)
	end

	uci:set('gluon', 'core', 'reconfigure', true)
	uci:save('gluon')
	uci:commit('gluon')
end

return f, f_actions
