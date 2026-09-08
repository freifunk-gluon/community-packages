-- Forward mode: make the kernel decapsulate a tunnel that is not addressed to
-- this node.
--
-- The packets arrive with the public address as their outer destination, which
-- the node does not have. Rewriting it to the node's own address on the way in
-- makes the ipip tunnel take them; l3routes routes what comes out onward.
--
-- An ingress hook has to name its devices, so it runs on every device the mesh
-- comes in over.

local publicip = require 'gluon.publicip'
local util = require 'gluon.util'

local PATH = '/lib/gluon/nftables/public_ip.nft'

local config = publicip.config()

local function mesh_devices()
	local ok, ubus = pcall(require, 'ubus')
	local conn = ok and ubus.connect()

	if not conn then
		-- ponytail: without ubus the bridge device names are not known, so no
		-- rules are written. This runs from uci-defaults at boot, where ubus
		-- is up, and again on every gluon-reconfigure.
		return {}
	end

	local devices = util.get_mesh_devices(conn)
	table.sort(devices)

	return devices
end

-- Declared and deleted every time, filled only when there is something to
-- rewrite: firewall4 flushes its own table on reload and not this one, so
-- leaving the file out would leave the previous rules in the kernel.
local out = {
	'table netdev gluon_public_ip',
	'delete table netdev gluon_public_ip',
}

if config and config.mode == 'forward' then
	local devices = mesh_devices()

	if #devices > 0 then
		table.insert(out, 'table netdev gluon_public_ip {')

		for _, device in ipairs(devices) do
			local chain = 'ingress_' .. device:gsub('[^%w]', '_')

			table.insert(out, '\tchain ' .. chain .. ' {')
			table.insert(out, ('\t\ttype filter hook ingress device "%s" priority -500; policy accept;')
				:format(device))
			-- ip protocol 4 is ipip: only the tunnel is redirected, anything
			-- else addressed to the public address is routed as it is
			table.insert(out, ('\t\tip daddr %s ip protocol 4 counter ip daddr set %s comment "public ip %s"')
				:format(config.ip4, config.node_ip4, config.ip4))
			table.insert(out, '\t}')
		end

		table.insert(out, '}')
	end
end

--[[
	The tunnel takes 1280 bytes and the networks either side take 1500, so a
	full sized segment does not fit and neither end knows why: the host just
	sends it again until it gives up. Ping and anything small gets through,
	which makes the forward look fine.

	firewall4's mtu_fix clamps to the route's MTU, which for a packet on its way
	to the device is the 1500 of the network it sits on - so the size that
	matters, the tunnel's, has to be named here.
]]
if config then
	local device = publicip.tunnel_device()
	local mss = publicip.tunnel_mss()

	table.insert(out, '')
	table.insert(out, 'table inet gluon_public_ip')
	table.insert(out, 'delete table inet gluon_public_ip')
	table.insert(out, 'table inet gluon_public_ip {')
	table.insert(out, '	chain mss {')
	table.insert(out, '		type filter hook forward priority mangle; policy accept;')

	for _, dir in ipairs({ 'iifname', 'oifname' }) do
		table.insert(out, ('		%s "%s" tcp flags & (syn|rst) == syn counter tcp option maxseg size set %d')
			:format(dir, device, mss))
	end

	table.insert(out, '	}')
	table.insert(out, '}')
else
	table.insert(out, '')
	table.insert(out, 'table inet gluon_public_ip')
	table.insert(out, 'delete table inet gluon_public_ip')
end

local file = assert(io.open(PATH, 'w'))
for _, line in ipairs(out) do
	file:write(line, '\n')
end
file:close()

include('public_ip', {
	position = 'ruleset-prepend',
})
