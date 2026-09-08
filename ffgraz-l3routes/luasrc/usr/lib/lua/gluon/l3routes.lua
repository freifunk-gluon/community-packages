--[[
	Extra route announcements for the mesh.

	Prefixes to announce come from the drop-in snippets in /lib/gluon/l3routes,
	loaded the way gluon-firewall loads /lib/gluon/nftables: every snippet is
	Lua and calls route{} / import{}. The mesh protocols pick the collected set
	up in their own upgrade scripts and announce it their own way.
]]

local glob = require 'posix.glob'
local ip   = require 'luci.ip' -- luci-lib-ip
local util = require 'gluon.util'
local uci  = require('simple-uci').cursor()

local SNIPPET_DIR = '/lib/gluon/l3routes'

local M = {}

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
		p.metric = tonumber(spec.metric)
		p.table = spec.table or 'main'
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

local ROLES = { 'uplink', 'mesh', 'client', 'private' }

-- The role gluon gave each physical interface, keyed by interface name, out of
-- the interface sections of /etc/config/gluon.
local function roles_by_ifname()
	local ret = {}

	for _, role in ipairs(ROLES) do
		for _, ifname in ipairs(util.get_role_interfaces(uci, role)) do
			ret[ifname] = ret[ifname] or {}
			table.insert(ret[ifname], role)
		end
	end

	return ret
end

-- The interfaces a network section is made of, however they are spelled
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

--[[
	Every configured network interface, as a name -> {device, up, roles} map.

	The list comes out of uci, so it is the same before and after netifd has
	brought anything up, and each entry carries the roles gluon gave the
	interfaces it is made of. ubus is only asked for the device names and the
	current state, which uci cannot know.
]]
function M.interfaces()
	local ret = {}
	local roles = roles_by_ifname()

	uci:foreach('network', 'interface', function(s)
		local name = s['.name']
		local seen, own = {}, {}

		for _, member in ipairs(members(s)) do
			for _, role in ipairs(roles[member] or {}) do
				if not seen[role] then
					seen[role] = true
					table.insert(own, role)
				end
			end
		end

		table.sort(own)

		ret[name] = {
			interface = name,
			device = s.device or s.ifname,
			roles = own,
		}
	end)

	local ok, ubus = pcall(require, 'ubus')
	local conn = ok and ubus.connect()
	local dump = conn and conn:call('network.interface', 'dump', {})

	if dump then
		for _, iface in ipairs(dump.interface) do
			local entry = ret[iface.interface]

			if entry then
				entry.device = iface.l3_device or iface.device or entry.device
				entry.up = iface.up
			end
		end
	end

	return ret
end

-- The interfaces worth offering as a route target, for the UI.
function M.devices()
	local ifaces = M.interfaces()
	local names = {}

	for name in pairs(ifaces) do
		-- the mesh is where the announcement goes, not where it points, and
		-- the daemons' own plumbing is never a route target
		if not (name == 'loopback' or name == 'local_node' or name == 'mmfd'
			or name == 'l3roamd' or name:match('^mesh')) then
			table.insert(names, name)
		end
	end

	-- sort before de-duplicating, so that of two interfaces on one device the
	-- same one always wins: wan and wan6 are both br-wan, and it should stay
	-- "wan" from one reconfigure to the next
	table.sort(names)

	local ret, by_device = {}, {}

	for _, name in ipairs(names) do
		local iface = ifaces[name]

		if not (iface.device and by_device[iface.device]) then
			by_device[iface.device or name] = true
			table.insert(ret, iface)
		end
	end

	return ret
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
