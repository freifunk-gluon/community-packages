#!/usr/bin/lua
-- Self-check for gluon.l3routes prefix handling. Run on a node:
--   scp tests/parse.lua root@<node>:/tmp/ && ssh root@<node> lua /tmp/parse.lua

local l3routes = require 'gluon.l3routes'

local failed = 0

local function fail(fmt, ...)
	failed = failed + 1
	io.stderr:write('FAIL: ', string.format(fmt, ...), '\n')
end

local function case(input, expected)
	local p = l3routes.parse(input)
	local shown = tostring(input)

	if expected == nil then
		if p ~= nil then
			fail('parse(%s) should be rejected, got %s', shown, p.cidr)
		end
		return
	end

	if not p then
		fail('parse(%s) should be accepted, was rejected', shown)
		return
	end

	for k, v in pairs(expected) do
		if p[k] ~= v then
			fail('parse(%s).%s: expected %s, got %s',
				shown, k, tostring(v), tostring(p[k]))
		end
	end
end

-- a bare address is not a prefix: a typo'd host must not become a /32
case('10.42.7.0', nil)
case('2001:db8::1', nil)
case('', nil)
case('not a prefix', nil)
case('10.42.7.0/33', nil)
case('10.42.7.0/', nil)
case(nil, nil)
case(42, nil)

-- host bits are normalised away
case('10.42.7.5/24', { cidr = '10.42.7.0/24', network = '10.42.7.0', plen = 24,
	family = 4, mask = '255.255.255.0' })
case('10.42.7.0/24', { cidr = '10.42.7.0/24', family = 4, mask = '255.255.255.0' })
case('10.0.0.1/32', { cidr = '10.0.0.1/32', plen = 32, mask = '255.255.255.255' })
case('0.0.0.0/0', { cidr = '0.0.0.0/0', plen = 0, mask = '0.0.0.0' })
case('172.16.9.3/12', { cidr = '172.16.0.0/12', mask = '255.240.0.0' })

-- a dotted netmask is a prefix too
case('10.42.7.0/255.255.255.0', { cidr = '10.42.7.0/24', plen = 24 })

-- v6 carries a prefix length, not a mask
case('2001:db8:1:2::5/64', { cidr = '2001:db8:1:2::/64', network = '2001:db8:1:2::',
	plen = 64, family = 6, mask = nil })
case('2001:db8::/48', { cidr = '2001:db8::/48', family = 6 })
case('fd00::1/128', { cidr = 'fd00::1/128', plen = 128, family = 6 })

-- containment, used to restrict imports
local outer = l3routes.parse('10.42.0.0/16').addr
if not outer:contains('10.42.7.0/24') then fail('10.42.0.0/16 should contain 10.42.7.0/24') end
if outer:contains('10.43.7.0/24') then fail('10.42.0.0/16 should not contain 10.43.7.0/24') end
if outer:contains('2001:db8::/48') then fail('10.42.0.0/16 should not contain a v6 prefix') end

-- a v6 prefix with a nil mask must still round-trip through the olsr applier's
-- expectations: Hna6 uses the prefix length, Hna4 the dotted mask
local v6 = l3routes.parse('2001:db8::/48')
if v6.mask ~= nil then fail('a v6 prefix must not carry a netmask') end
if l3routes.parse('10.0.0.0/8').mask == nil then fail('a v4 prefix must carry a netmask') end

if failed > 0 then
	io.stderr:write(('gluon.l3routes: %d check(s) failed\n'):format(failed))
	os.exit(1)
end

print('gluon.l3routes: parse ok')
