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

local file = assert(io.open(PATH, 'w'))
for _, line in ipairs(out) do
	file:write(line, '\n')
end
file:close()

include('public_ip', {
	position = 'ruleset-prepend',
})
