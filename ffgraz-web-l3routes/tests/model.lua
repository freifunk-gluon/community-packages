#!/usr/bin/lua
--[[
	Drives the config mode model without a web server: builds the same
	environment the dispatcher builds, feeds it form values and checks what
	lands in uci.

	Run on a node:
	  scp -O tests/model.lua root@<node>:/tmp/ && ssh root@<node> lua /tmp/model.lua
]]

local classes = require 'gluon.web.model.classes'

-- The model uses a cursor of its own, and a cursor caches the packages it has
-- loaded; reading through a long-lived one would not see what the model just
-- committed. Every read here takes a fresh one.
local function cursor()
	return require('simple-uci').cursor()
end

local MODEL = '/lib/gluon/config-mode/model/admin/l3routes.lua'
local CONFIG = 'gluon-l3routes-custom'

local failed = 0

local function fail(fmt, ...)
	failed = failed + 1
	io.stderr:write('FAIL: ', string.format(fmt, ...), '\n')
end

local i18n = {
	translate = function(s) return s end,
	translatef = function(s, ...) return string.format(s, ...) end,
	_ = function(s) return s end,
}

-- the model flags the node instead of reconfiguring it itself
local function reconfigure_flag()
	return cursor():get_bool('gluon', 'core', 'reconfigure')
end

local function clear_reconfigure_flag()
	local c = cursor()
	c:delete('gluon', 'core', 'reconfigure')
	c:save('gluon')
	c:commit('gluon')
end

local function load_models()
	local func = assert(loadfile(MODEL))

	setfenv(func, setmetatable({}, { __index = function(_, key)
		return classes[key] or i18n[key] or _G[key]
	end }))

	local maps = { func() }
	for i, map in ipairs(maps) do
		-- the dispatcher numbers the models it loaded; ids depend on it
		map.index = i
	end

	return maps
end

-- the options of a loaded model, by the name they were declared with
local function options(node, into)
	into = into or {}

	for _, child in ipairs(node.children) do
		if child.name then
			into[child.name] = child
		end
		options(child, into)
	end

	return into
end

local function http(params)
	return {
		formvalue = function(_, name) return (params[name] or {})[1] end,
		formvaluetable = function(_, name) return params[name] or {} end,
		getenv = function(_, name)
			return name == 'REQUEST_METHOD' and 'POST' or nil
		end,
	}
end

--[[
	Submits one of the forms. Values are given by option name, so the test does
	not depend on where in the tree an option sits; a Flag is a checkbox, so
	false means leaving the field out of the submission entirely.
]]
local function submit(which, values)
	local maps = load_models()
	local map = maps[which]
	local opts = options(map)
	local params = { [map:id()] = { '1' } }

	for name, value in pairs(values) do
		local opt = opts[name]
		if not opt then
			fail('the model has no option named %s', name)
		elseif value == false then
			params[opt:id()] = nil
		elseif type(value) == 'table' then
			params[opt:id()] = value
		else
			params[opt:id()] = { tostring(value) }
		end
	end

	local ok, err = pcall(function()
		map:parse(http(params))
		map:handle()
	end)

	if not ok then
		fail('submitting form %d raised: %s', which, tostring(err))
	end

	return map
end

local function entries(stype)
	local ret = {}
	cursor():foreach(CONFIG, stype, function(s) table.insert(ret, s) end)
	return ret
end

local function clear()
	local c = cursor()
	c:delete_all(CONFIG, 'route')
	c:delete_all(CONFIG, 'import')
	c:save(CONFIG)
	c:commit(CONFIG)
end

clear()
clear_reconfigure_flag()

if reconfigure_flag() then
	fail('the reconfigure flag was not cleared before the test')
end

-- Adding

submit(2, { action = 'add_route', add_interface = 'olsr12' })

local added = entries('route')
if #added ~= 1 then
	fail('adding a route produced %d entries', #added)
elseif added[1].interface ~= 'olsr12' then
	fail('the added route points at %s', tostring(added[1].interface))
elseif added[1].cidr then
	fail('a freshly added route should have no prefix yet')
end

submit(2, { action = 'add_import' })

if #entries('import') ~= 1 then
	fail('adding an import produced %d entries', #entries('import'))
end

-- An entry that is still empty must not break the announcement collection:
-- gluon-reconfigure runs right after it was added.
local l3routes = require 'gluon.l3routes'
local ok, err = pcall(l3routes.collect)
if not ok then
	fail('an empty entry broke the collection: %s', tostring(err))
end

local route_name = added[1] and added[1]['.name']
local import_name = entries('import')[1] and entries('import')[1]['.name']

-- Filling the entries in

submit(1, {
	[route_name .. '_enabled'] = '1',
	[route_name .. '_cidr'] = '10.77.0.0/16',
	[route_name .. '_interface'] = 'olsr12',
	[route_name .. '_kind'] = 'route',
	[route_name .. '_metric'] = '128',
	[route_name .. '_table'] = 'main',
	[route_name .. '_firewall'] = false, -- an unchecked box is not submitted
	[import_name .. '_enabled'] = '1',
	[import_name .. '_family'] = '4',
	[import_name .. '_table'] = '42',
	[import_name .. '_proto'] = '4',
	[import_name .. '_cidr'] = '10.0.0.0/8',
	[import_name .. '_le'] = '24',
	[import_name .. '_metric'] = '256',
})

local r = entries('route')[1]
if not r then
	fail('the route entry disappeared')
else
	if r.cidr ~= '10.77.0.0/16' then fail('route cidr: got %s', tostring(r.cidr)) end
	if r.interface ~= 'olsr12' then fail('route interface: got %s', tostring(r.interface)) end
	if r.metric ~= '128' then fail('route metric: got %s', tostring(r.metric)) end
	if r.table ~= 'main' then fail('route table: got %s', tostring(r.table)) end
	if r.firewall ~= '0' then fail('route firewall: got %s', tostring(r.firewall)) end
	if r.is_local then fail('a plain route must not be marked local') end
end

local i = entries('import')[1]
if not i then
	fail('the import entry disappeared')
else
	if i.table ~= '42' then fail('import table: got %s', tostring(i.table)) end
	if i.proto ~= '4' then fail('import proto: got %s', tostring(i.proto)) end
	if i.cidr ~= '10.0.0.0/8' then fail('import cidr: got %s', tostring(i.cidr)) end
	if i.le ~= '24' then fail('import le: got %s', tostring(i.le)) end
	if i.family ~= '4' then fail('import family: got %s', tostring(i.family)) end
	if i.metric ~= '256' then fail('import metric: got %s', tostring(i.metric)) end
end

if not reconfigure_flag() then
	fail('saving did not flag the node as needing a reconfigure')
end

-- A local address needs no routing table, and keeps the firewall out of it

submit(1, {
	[route_name .. '_enabled'] = '1',
	[route_name .. '_cidr'] = '10.88.0.1/32',
	[route_name .. '_interface'] = 'olsr12',
	[route_name .. '_kind'] = 'local',
	[import_name .. '_enabled'] = '1',
	[import_name .. '_proto'] = '4',
	-- a browser always submits a select, so the test has to as well
	[import_name .. '_family'] = '',
})

r = entries('route')[1]
if r.is_local ~= '1' then fail('local address: is_local is %s', tostring(r.is_local)) end
if r.table then fail('a local address needs no routing table, got %s', r.table) end
if r.firewall then fail('a local address needs no firewall handling, got %s', r.firewall) end

-- Validation

local bad = submit(1, {
	[route_name .. '_cidr'] = 'not a prefix',
	[route_name .. '_interface'] = 'olsr12',
	[route_name .. '_kind'] = 'route',
	[import_name .. '_proto'] = '4',
	[import_name .. '_family'] = '',
})
if bad.state ~= classes.FORM_INVALID then
	fail('an invalid prefix was accepted')
end
if entries('route')[1].cidr ~= '10.88.0.1/32' then
	fail('an invalid submission still changed the configuration')
end

local unrestricted = submit(1, {
	[route_name .. '_cidr'] = '10.88.0.1/32',
	[route_name .. '_interface'] = 'olsr12',
	[route_name .. '_kind'] = 'local',
	[import_name .. '_table'] = '42',
	[import_name .. '_family'] = '',
})
if unrestricted.state ~= classes.FORM_INVALID then
	fail('a table import with neither a protocol nor a restriction was accepted')
end

-- Removing

submit(2, { action = 'delete', remove = route_name })
if #entries('route') ~= 0 then
	fail('the route was not removed')
end

submit(2, { action = 'delete', remove = import_name })
if #entries('import') ~= 0 then
	fail('the import was not removed')
end

clear()
clear_reconfigure_flag()

if failed > 0 then
	io.stderr:write(('ffgraz-web-l3routes: %d check(s) failed\n'):format(failed))
	os.exit(1)
end

print('ffgraz-web-l3routes: model ok')
