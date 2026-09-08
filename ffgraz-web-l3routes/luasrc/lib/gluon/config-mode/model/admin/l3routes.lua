local uci = require('simple-uci').cursor()
local l3routes = require 'gluon.l3routes'

local CONFIG = 'gluon-l3routes-custom'

--[[
	Which prefixes are announced, and the routes and firewall rules they need,
	are all decided when the configuration is generated. Rather than generating
	it from inside the request, the node is flagged the way gluon-switch-domain
	does it: gluon-core-reconfigure picks the flag up at boot, and gluon-reload
	applies it without one.
]]
local function needs_reconfigure()
	uci:set('gluon', 'core', 'reconfigure', true)
	uci:save('gluon')
	uci:commit('gluon')
end

local devices = l3routes.devices()

local function entries(stype)
	local ret = {}
	uci:foreach(CONFIG, stype, function(s) table.insert(ret, s) end)
	return ret
end

local route_entries = entries('route')
local import_entries = entries('import')

local f = Form(translate('Shared networks'))
-- saving can rename the sections (their titles carry the prefix), so the page
-- is built again from what was written
f.reload = true

if #route_entries == 0 and #import_entries == 0 then
	local s = f:section(Section, nil, translate(
		'This node only shares its own addresses so far. Add a network below '
		.. 'to let the rest of the mesh reach it through here.'))
	s:element('model/warning', {
		content = translate('Nothing is shared yet.'),
	}, 'empty')
end

-- Routes

local routes = {}

for _, entry in ipairs(route_entries) do
	local name = entry['.name']

	local title = entry.cidr
		and translatef('%s via %s', entry.cidr, entry.interface or '?')
		or translate('New network')

	local s = f:section(Section, title, translate(
		'A network this node can reach, or an address of its own, offered to '
		.. 'the rest of the mesh.'))

	local enabled = s:option(Flag, name .. '_enabled', translate('Share this'))
	enabled.default = entry.enabled ~= '0'

	local cidr = s:option(Value, name .. '_cidr', translate('Address range'),
		translate('For example 10.42.7.0/24 or 2001:db8:1::/48'))
	cidr.default = entry.cidr

	function cidr:validate()
		return self.data ~= nil and l3routes.parse(self.data) ~= nil
	end

	local interface = s:option(ListValue, name .. '_interface', translate('Reached over'),
		translate('Where this network is connected'))
	for _, dev in ipairs(devices) do
		interface:value(dev.interface, l3routes.device_label(dev))
	end
	interface.default = entry.interface or (devices[1] and devices[1].interface)

	local kind = s:option(ListValue, name .. '_kind', translate('This is'))
	kind:value('route', translate('A network behind it'))
	kind:value('local', translate('An address of this node'))
	kind.default = entry.is_local == '1' and 'local' or 'route'

	local metric = s:option(Value, name .. '_metric', translate('Priority'),
		translate('Leave empty unless this route should win over another'))
	metric.optional = true
	metric.datatype = 'uinteger'
	metric.default = entry.metric

	local rtable = s:option(Value, name .. '_table', translate('Routing table'),
		translate('Advanced. Leave as it is unless something else manages this route.'))
	rtable.optional = true
	rtable.default = entry.table or 'main'
	rtable:depends(kind, 'route')

	local firewall = s:option(Flag, name .. '_firewall', translate('Open the firewall'),
		translate('Let the mesh actually reach it. Turn this off only if you set '
			.. 'the firewall up yourself.'))
	firewall.default = entry.firewall ~= '0'
	firewall:depends(kind, 'route')

	table.insert(routes, {
		name = name,
		enabled = enabled,
		cidr = cidr,
		interface = interface,
		kind = kind,
		metric = metric,
		rtable = rtable,
		firewall = firewall,
	})
end

-- Imports

local imports = {}

for _, entry in ipairs(import_entries) do
	local name = entry['.name']

	local title
	if entry.table and entry.proto then
		title = translatef('Import protocol %s from table %s', entry.proto, entry.table)
	elseif entry.table then
		title = translatef('Import table %s', entry.table)
	elseif entry.proto then
		title = translatef('Import protocol %s', entry.proto)
	else
		title = translate('New import')
	end

	local s = f:section(Section, title, translate(
		'Share routes this node already learned from another routing daemon. '
		.. 'Always set a limit, or the node would offer the whole internet to '
		.. 'the mesh.'))

	local enabled = s:option(Flag, name .. '_enabled', translate('Share this'))
	enabled.default = entry.enabled ~= '0'

	local rtable = s:option(Value, name .. '_table', translate('Routing table'),
		translate('Which table to take them from, as a number'))
	rtable.optional = true
	rtable.datatype = 'uinteger'
	rtable.default = entry.table

	local proto = s:option(Value, name .. '_proto', translate('Routing protocol'),
		translate('Which daemon they came from, as a number or name'))
	proto.optional = true
	proto.default = entry.proto

	local cidr = s:option(Value, name .. '_cidr', translate('Limit to'),
		translate('Only share routes inside this range'))
	cidr.optional = true
	cidr.default = entry.cidr

	function cidr:validate()
		if self.data ~= nil and not l3routes.parse(self.data) then
			return false
		end
		-- an import selecting a whole table and nothing else would announce
		-- the uplink default route along with everything else in it
		return self.data ~= nil or proto.data ~= nil
	end

	local le = s:option(Value, name .. '_le', translate('Smallest range'),
		translate('Skip anything smaller than this, for example 24'))
	le.optional = true
	le.datatype = 'uinteger'
	le.default = entry.le

	local family = s:option(ListValue, name .. '_family', translate('Applies to'))
	family:value('', translate('IPv4 and IPv6'))
	family:value('4', translate('IPv4'))
	family:value('6', translate('IPv6'))
	family.default = entry.family or ''

	local metric = s:option(Value, name .. '_metric', translate('Priority'),
		translate('Leave empty unless these should win over other routes'))
	metric.optional = true
	metric.datatype = 'uinteger'
	metric.default = entry.metric

	table.insert(imports, {
		name = name,
		enabled = enabled,
		rtable = rtable,
		proto = proto,
		cidr = cidr,
		le = le,
		family = family,
		metric = metric,
	})
end

local ROUTE_KEYS = { 'cidr', 'interface', 'metric', 'table', 'is_local', 'firewall', 'enabled' }
local IMPORT_KEYS = { 'table', 'proto', 'cidr', 'le', 'family', 'metric', 'enabled' }

--[[
	uci:section() only ever sets what it is given, so an option that no longer
	applies - the routing table of an entry that became a local address - would
	keep its old value. Every key is written explicitly instead, and
	simple-uci's set() deletes the ones that are nil.
]]
local function put(stype, keys, name, values)
	uci:section(CONFIG, stype, name)

	for _, key in ipairs(keys) do
		uci:set(CONFIG, name, key, values[key])
	end
end

function f:write()
	for _, r in ipairs(routes) do
		local is_local = r.kind.data == 'local'

		put('route', ROUTE_KEYS, r.name, {
			cidr = r.cidr.data,
			interface = r.interface.data,
			metric = r.metric.data,
			table = (not is_local) and r.rtable.data or nil,
			is_local = is_local and '1' or nil,
			firewall = (not is_local and not r.firewall.data) and '0' or nil,
			enabled = (not r.enabled.data) and '0' or nil,
		})
	end

	for _, i in ipairs(imports) do
		put('import', IMPORT_KEYS, i.name, {
			['table'] = i.rtable.data,
			proto = i.proto.data,
			cidr = i.cidr.data,
			le = i.le.data,
			family = i.family.data ~= '' and i.family.data or nil,
			metric = i.metric.data,
			enabled = (not i.enabled.data) and '0' or nil,
		})
	end

	uci:save(CONFIG)
	uci:commit(CONFIG)

	needs_reconfigure()
end

-- Actions: adding and removing entries, the way the network page adds VLANs

local f_actions = Form(translate('Actions'))
-- adding and removing entries changes which sections exist, and they should
-- show up in the answer to that very request
f_actions.reload = true

local sa = f_actions:section(Section)

local action = sa:option(ListValue, 'action', translate('Action'))
action:value('add_route', translate('Add a network'))
action:value('add_import', translate('Add an import'))
if #route_entries > 0 or #import_entries > 0 then
	action:value('delete', translate('Remove one'))
end

local add_interface = sa:option(ListValue, 'add_interface', translate('Interface'))
for _, dev in ipairs(devices) do
	add_interface:value(dev.interface, l3routes.device_label(dev))
end
add_interface:depends(action, 'add_route')

local remove = sa:option(ListValue, 'remove', translate('Which one'))
for _, entry in ipairs(route_entries) do
	remove:value(entry['.name'],
		translatef('%s via %s', entry.cidr or '?', entry.interface or '?'))
end
for _, entry in ipairs(import_entries) do
	remove:value(entry['.name'], translatef('Import %s',
		entry.proto or entry.table or '?'))
end
remove:depends(action, 'delete')

-- a name no section has yet, so that entries keep theirs across edits
local function free_name(prefix)
	local i = 1
	while uci:get(CONFIG, prefix .. i) do
		i = i + 1
	end
	return prefix .. i
end

function f_actions:write()
	if action.data == 'add_route' then
		uci:section(CONFIG, 'route', free_name('route_'), {
			interface = add_interface.data,
		})
	elseif action.data == 'add_import' then
		uci:section(CONFIG, 'import', free_name('import_'), {})
	elseif action.data == 'delete' and remove.data then
		uci:delete(CONFIG, remove.data)
	end

	uci:save(CONFIG)
	uci:commit(CONFIG)

	needs_reconfigure()
end

return f, f_actions
