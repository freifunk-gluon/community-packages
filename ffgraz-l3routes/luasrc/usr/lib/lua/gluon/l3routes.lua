-- Extra route announcements for the mesh.
--
-- The prefixes come from the drop-in snippets in /lib/gluon/l3routes, loaded
-- the way gluon-firewall loads /lib/gluon/nftables. The mesh protocols pick
-- the collected set up and announce it their own way.

local glob = require 'posix.glob'
local ip   = require 'luci.ip' -- luci-lib-ip
local util = require 'gluon.util'
local uci  = require('simple-uci').cursor()

local SNIPPET_DIR = '/lib/gluon/l3routes'

local M = {}

-- the firewall zone the announced prefixes that need one are put into
M.ZONE = 'l3routes'

-- A prefix, normalised. Returns nil for anything that is not one - a bare
-- address included, so that a typo'd host does not silently become a /32.
function M.parse(str)
	if type(str) ~= 'string' or not str:match('/%d') then
		return nil
	end

	local addr = ip.new(str)
	if not addr then
		return nil
	end

	local plen = addr:prefix()
	local network = addr:network():string()

	return {
		cidr = network .. '/' .. plen,
		network = network,
		plen = plen,
		family = addr:is4() and 4 or 6,
		-- olsrd's Hna4 wants a dotted netmask, Hna6 wants the prefix length
		mask = addr:is4() and addr:mask():string() or nil,
		addr = addr,
	}
end

local collected

function M.collect()
	if collected then
		return collected
	end

	local routes, imports, seen = {}, {}, {}

	local function route(spec)
		local p = M.parse(spec.cidr or '')
		assert(p, 'l3routes: not a prefix: ' .. tostring(spec.cidr))
		assert(spec.interface, 'l3routes: route without interface: ' .. p.cidr)

		local key = p.cidr .. ' via ' .. spec.interface
		if seen[key] then
			return
		end
		seen[key] = true

		p.interface = spec.interface

		-- a next hop, for a prefix that is not on the interface itself
		if spec.gateway then
			local gateway = ip.new(spec.gateway)
			assert(gateway, 'l3routes: not an address: ' .. tostring(spec.gateway))
			assert((gateway:is4() and 4 or 6) == p.family,
				'l3routes: gateway ' .. spec.gateway .. ' is not of the same family as ' .. p.cidr)

			p.gateway = gateway:string()
		end

		p.metric = tonumber(spec.metric)
		-- netifd reads "main" as "no table given" anyway, and then uses the
		-- table the interface itself is configured with
		p.table = spec.table
		p.is_local = spec.is_local == true or spec.is_local == '1'
		-- a local address needs no route and no zone; putting the interface it
		-- lives on into a REJECT-input zone would break the address itself
		p.firewall = not p.is_local and spec.firewall ~= false and spec.firewall ~= '0'
		p.comment = spec.comment
		p.source = spec.source

		table.insert(routes, p)
	end

	local function import(spec)
		-- an unrestricted filter would drag the uplink default route into the mesh
		assert(spec.proto or spec.cidr, 'l3routes: import needs a proto or a cidr')

		local p = spec.cidr and M.parse(spec.cidr)
		assert(not spec.cidr or p, 'l3routes: not a prefix: ' .. tostring(spec.cidr))

		table.insert(imports, {
			table = spec.table and tonumber(spec.table),
			proto = spec.proto,
			prefix = p,
			le = tonumber(spec.le) or (p and (p.family == 4 and 32 or 128)),
			family = tonumber(spec.family) or (p and p.family),
			metric = tonumber(spec.metric),
			source = spec.source,
		})
	end

	local env = setmetatable({ route = route, import = import }, { __index = _G })

	local paths = glob.glob(SNIPPET_DIR .. '/*.lua', 0) or {}
	table.sort(paths)

	for _, path in ipairs(paths) do
		local f = assert(loadfile(path))
		setfenv(f, setmetatable({}, { __index = env }))
		f()
	end

	table.sort(routes, function(a, b)
		return a.cidr .. a.interface < b.cidr .. b.interface
	end)

	collected = { routes = routes, imports = imports }
	return collected
end

-- The kernel routes an import selects, over netlink. olsrd has no
-- redistribution of its own and has to snapshot them into HNAs.
function M.resolve(imp)
	local found = {}

	ip.routes({
		family = imp.family,
		table = imp.table,
		proto = imp.proto,
		dest = imp.prefix and imp.prefix.cidr or nil,
	}, function(rt)
		if rt.type ~= 1 or not rt.dest then
			return -- unicast only
		end
		if rt.dest:prefix() > (imp.le or 128) then
			return
		end
		if rt.proto == 42 then
			return -- babeld's own routes, already in the mesh
		end

		local p = M.parse(rt.dest:string() .. '/' .. rt.dest:prefix())
		if p then
			p.dev = rt.dev
			p.source = imp.source
			table.insert(found, p)
		end
	end)

	return found
end

--[[
	The network interfaces gluon itself sets up. A route may perfectly well
	point at one of them, but the firewall around them is gluon's business:
	adding br-client or br-wan to a second zone changes how the node treats
	clients or the uplink, which is not something announcing a prefix should
	do as a side effect.
]]
M.GLUON_MANAGED = {
	loopback = true,
	client = true,
	local_node = true,
	wan = true,
	wan6 = true,
	cellular = true,
	cellular_4 = true,
	mmfd = true,
	l3roamd = true,
}

function M.is_gluon_managed(interface)
	return M.GLUON_MANAGED[interface] == true or interface:match('^mesh') ~= nil
end

local function file_exists(path)
	local f = io.open(path)
	if not f then
		return false
	end
	f:close()
	return true
end

--[[
	Which address families a mesh protocol may announce on this node.

	This is gluon's own split, in one place: 300-gluon-mesh-babel-mkconfig keeps
	babel off IPv4 where olsrd carries it, and 360-gluon-mesh-olsrd-setup-intf
	does not even run olsrd6 where gluon-mesh-babel is installed. Announcing a
	prefix through both protocols at once would undo that.
]]
function M.families(protocol)
	local olsr = uci:get_bool('gluon', 'mesh_olsrd', 'enabled')
	local babel = file_exists('/etc/init.d/gluon-mesh-babel')

	if protocol == 'babel' then
		return { [4] = not olsr, [6] = true }
	end

	return { [4] = olsr, [6] = olsr and not babel }
end

-- The interfaces gluon knows about, by role, out of /etc/config/gluon.
--
-- Not from netifd's configuration: gluon-reconfigure runs from uci-defaults at
-- boot, before netifd is up, so anything needing ubus is not there to ask.
local ROLES = { 'uplink', 'mesh', 'client', 'private' }

-- the interfaces a network section is made of, however they are spelled
local function members(section)
	local ret = {}

	for _, key in ipairs({ 'ifname', 'device', 'ports' }) do
		local value = section[key]

		if type(value) == 'table' then
			for _, name in ipairs(value) do
				table.insert(ret, name)
			end
		elseif type(value) == 'string' then
			for name in value:gmatch('%S+') do
				table.insert(ret, name)
			end
		end
	end

	return ret
end

-- The device netifd will give an interface, worked out rather than asked for
-- so it is the same before netifd runs as after. Reporting a bridge's first
-- port instead once built a macvlan on eth0, enslaved to br-wan, which never
-- came up.
local function device_of(section, name)
	if section.device then
		return section.device
	end

	if section.type == 'bridge' then
		return 'br-' .. name
	end

	return section.ifname and section.ifname:match('^%S+')
end

-- the network interface carrying any of these ports, and its device
local function carrier(ifnames)
	local want, found = {}, nil

	for _, ifname in ipairs(ifnames) do
		want[ifname] = true
	end

	uci:foreach('network', 'interface', function(section)
		if found then
			return
		end

		for _, member in ipairs(members(section)) do
			if want[member] then
				local name = section['.name']
				found = { network = name, device = device_of(section, name) }
				return
			end
		end
	end)

	return found
end

-- role -> {network, device}: a route attaches to the network interface, a
-- firewall zone or a macvlan is built on the device.
function M.interfaces()
	local ret = {}

	for _, role in ipairs(ROLES) do
		local ifnames = util.get_role_interfaces(uci, role)

		if #ifnames > 0 then
			local found = carrier(ifnames)

			if found then
				ret[role] = {
					interface = role,
					network = found.network,
					device = found.device,
					roles = { role },
				}
			end
		end
	end

	return ret
end

-- The roles worth offering as a route target.
function M.devices()
	local ret = {}

	for _, iface in pairs(M.interfaces()) do
		table.insert(ret, iface)
	end

	table.sort(ret, function(a, b) return a.interface < b.interface end)
	return ret
end

-- The firewall zone covering an interface, by device rather than by name: two
-- zones naming different interfaces of the same bridge still overlap.
function M.zones()
	local devices, ret = {}, {}

	uci:foreach('network', 'interface', function(section)
		local name = section['.name']
		devices[name] = device_of(section, name)
	end)

	uci:foreach('firewall', 'zone', function(zone)
		for _, network in ipairs(zone.network or {}) do
			local name = zone.name or zone['.name']

			-- by device, so that two zones naming different interfaces of one
			-- bridge are seen to overlap, and by network name as well: a route
			-- may name an interface directly rather than through a role, and
			-- looking only by device left those looking unzoned - which put
			-- them in a second zone of our own alongside the one they had
			ret[devices[network] or network] = name
			ret[network] = name
		end
	end)

	return ret
end

function M.zone_of(role, zones, ifaces)
	zones = zones or M.zones()
	ifaces = ifaces or M.interfaces()

	local iface = ifaces[role]

	return zones[(iface and iface.device) or role]
end

-- Whether an interface has an address covering the given one. netifd only
-- installs a route through a next hop it can place, and a mesh interface is a
-- /32, so nothing ever is. nil where it cannot be told.
function M.reaches(role, address, ifaces)
	local iface = (ifaces or M.interfaces())[role]

	if not (iface and iface.addresses) then
		return nil
	end

	local target = ip.new(address)

	for _, own in ipairs(iface.addresses) do
		local prefix = ip.new(own)

		if prefix and target and prefix:network(prefix:prefix()):contains(target) then
			return true
		end
	end

	return false
end

-- How an interface is named in the config mode: "wan (br-wan, uplink)"
-- How a role is named in the config mode: "uplink (br-wan)"
function M.device_label(dev)
	if not dev.device then
		return dev.interface
	end

	return string.format('%s (%s)', dev.interface, dev.device)
end

-- Persistent, id-keyed adds for other modules; replayed by 100-uci.lua.
function M.add(id, spec)
	local stype = (spec.cidr and spec.interface) and 'route' or 'import'

	uci:section('gluon-l3routes', stype, id, spec)
	uci:save('gluon-l3routes')
end

function M.remove(id)
	uci:delete('gluon-l3routes', id)
	uci:save('gluon-l3routes')
end

return M
