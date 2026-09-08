-- The public address of a node and what happens with it.
--
-- local    the node carries the address itself: the tunnel terminates on it
--          and it is announced as one of the node's own.
-- forward  the address belongs to another device. The tunnel terminates on
--          the node's address, an nftables rule rewrites the outer
--          destination so the kernel decapsulates, and what comes out is
--          routed on to that device.

local ip = require 'luci.ip' -- luci-lib-ip
local uci = require('simple-uci').cursor()

local M = {}

M.MODES = { 'local', 'forward' }

-- the uci section type of a single port forward
M.PORT = 'olsr_public_ip_port'

-- The netifd interface the tunnel runs on. Short on purpose: netifd calls the
-- device it creates "ipip-<interface>" and a device name is capped at 15
-- characters, so the old olsr_public_ip made one four too long and the tunnel
-- never came up at all.
M.INTERFACE = 'pubip'

-- the alias that carries the address itself, see 500-public-ip
M.ADDRESS_INTERFACE = 'pubip4'

-- Forwarding rides a macvlan child of the interface it is pointed at, with
-- its own address and firewall zone. Sharing the uplink would mean carving the
-- prefix out of gluon's uplink policy one exception at a time; gluon does the
-- same for the mesh where it rides the uplink port (m_uplink).
M.FORWARD_INTERFACE = 'pubfwd'

-- the device section is named separately: a uci section name is unique across
-- the file whatever its type, so sharing one would merge the two
M.FORWARD_DEVICE_SECTION = 'pubfwd_dev'

-- Where the address sends its own traffic: out of the tunnel, not out of
-- whatever uplink this node has, where it would leave with a source address
-- that does not belong there and be dropped as spoofed. A table of its own and
-- a rule picking it, as the proto handler here once did by hand.
M.TABLE = 112

-- what netifd gives an ipip tunnel, and what fits in it once the outer header
-- is on
M.TUNNEL_MTU = 1280
M.RULE_PRIORITY = 21100

-- the firewall zone the tunnel is put into, so that what arrives through it
-- can be forwarded on
M.ZONE = 'public_ip'

-- The IPv4 address of the node itself, the one that is not 127.0.0.0/8
function M.node_ip4()
	for _, address in ipairs(uci:get_list('network', 'loopback', 'ipaddr')) do
		local host = address:match('^[^/]+')

		if host and not host:match('^127%.') then
			return host
		end
	end
end

local function address(value)
	local parsed = value and ip.new(value)

	if parsed and parsed:is4() then
		return parsed:string()
	end
end

-- The configuration, or nil when there is nothing to set up: turned off, or
-- missing something. Every consumer asks here, so a half-filled form leaves the
-- node alone rather than half configured.
function M.config()
	if not uci:get_bool('gluon', 'olsr_public_ip', 'enabled') then
		return nil
	end

	local ip4 = address(uci:get('gluon', 'olsr_public_ip', 'ip4'))
	local peeraddr = address(uci:get('gluon', 'olsr_public_ip', 'peeraddr'))

	if not (ip4 and peeraddr) then
		return nil
	end

	local mode = uci:get('gluon', 'olsr_public_ip', 'mode') or 'local'
	local node_ip4 = M.node_ip4()

	local config = {
		mode = mode,
		ip4 = ip4,
		peeraddr = peeraddr,
		node_ip4 = node_ip4,
	}

	if mode ~= 'forward' then
		config.mode = 'local'
		return config
	end

	config.target = address(uci:get('gluon', 'olsr_public_ip', 'target'))
	config.target_interface = uci:get('gluon', 'olsr_public_ip', 'target_interface')

	-- The address the node takes on that segment: the gateway the forwarded
	-- device talks back to, and what the node ARPs for the public address from -
	-- without one the requests go out from 0.0.0.0 and are ignored. A /32 on
	-- both sides, each reaching the other by an explicit route.
	config.gateway = address(uci:get('gluon', 'olsr_public_ip', 'gateway'))

	-- Forwarding needs an interface to ride, an address on it, and an address to
	-- terminate the tunnel on. The device's own address is optional: with one the
	-- public address is routed to it as a next hop, without one it is routed onto
	-- the segment and the device answers for it there.
	if not (config.target_interface and config.gateway and node_ip4) then
		return nil
	end

	return config
end

-- Ports handed on to a device behind the node. Only where the node holds the
-- address itself; in forward mode the whole address belongs elsewhere.
function M.ports()
	local ret = {}

	uci:foreach('gluon', M.PORT, function(section)
		if section.enabled == '0' then
			return
		end

		local dest = address(section.dest_ip)

		-- a half-filled entry is skipped rather than turned into a rule that
		-- sends traffic somewhere nobody asked for
		if not (dest and section.src_dport) then
			return
		end

		table.insert(ret, {
			name = section['.name'],
			proto = section.proto or 'tcp',
			src_dport = section.src_dport,
			dest_ip = dest,
			dest_port = section.dest_port,
			-- the interface the destination sits behind; it decides what the
			-- forwarded port is allowed to reach, so it is named per entry
			-- rather than opening the tunnel onto everything at once
			dest_interface = section.dest_interface,
			comment = section.comment,
		})
	end)

	table.sort(ret, function(a, b) return a.name < b.name end)

	return ret
end

-- The device the tunnel runs on, and the largest segment that fits through it
function M.tunnel_device()
	return 'ipip-' .. M.INTERFACE
end

function M.tunnel_mss()
	local f = io.open('/sys/class/net/' .. M.tunnel_device() .. '/mtu')
	local mtu = M.TUNNEL_MTU

	if f then
		mtu = tonumber(f:read('*l')) or mtu
		f:close()
	end

	-- room for the IPv4 and TCP headers
	return mtu - 40
end

return M
