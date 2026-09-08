local uci = require("simple-uci").cursor()
local ip = require 'luci.ip'
local extranets = require 'gluon.extranets'

local f = Form(translate('Network ranges'))

--[[
	Whether what the node is configured with right now is a range the rest of
	the mesh routes here, or one that means nothing outside this node and is
	translated on the way out. Which of the two it is follows from the address
	itself, so it is worth saying rather than leaving to be worked out.
]]
local function shared(prefix, unset)
	if prefix then
		return translatef('Shared with the mesh as %s.', prefix)
	end

	return unset or translate('Kept behind this node, reached through its own address.')
end

local function is4(value)
	local address = value and ip.new(value)
	return address ~= nil and address:is4() and value:match('/%d') ~= nil
end

local function is6(value)
	local address = value and ip.new(value)
	return address ~= nil and address:is6() and value:match('/%d') ~= nil
end

-- The private network: anything goes, and what the mesh does not route is
-- translated on the way out.

local s = f:section(Section, translate('Private network'), translate(
	'A network of your own behind the node, with its own addresses. Whatever '
	.. 'you plug into the ports set aside for it lands here, and reaches the '
	.. 'internet through the mesh.'
))

local private4 = s:option(Value, 'private4', translate('IPv4 range'),
	translate('The node takes the first address, for example 192.168.66.1/24. '
		.. 'A range out of the mesh\'s own is announced and reachable from the '
		.. 'other nodes; any other stays behind this one.')
	.. ' ' .. shared(extranets.routed4(extranets.address4('private'))))
private4.default = extranets.address4('private')

function private4:validate()
	return is4(self.data)
end

local private6 = s:option(Value, 'private6', translate('IPv6 range'),
	translate('Paste the range you were assigned, with the node\'s address in '
		.. 'it, for example 2001:db8:1234::1/64. The mesh is told to route it '
		.. 'here. Leave empty for one made up locally, which stays behind the '
		.. 'node.')
	.. ' ' .. shared(extranets.public6(extranets.address6('private'))))
private6.optional = true
private6.default = extranets.address6('private')
	or uci:get('network', 'globals', 'ula_prefix')

function private6:validate()
	if self.data == nil or self.data == 'auto' then
		return true
	end

	-- either an assigned range, which is announced, or a made up one, which
	-- is not; anything else is neither
	return extranets.public6(self.data) ~= nil or is6(self.data)
end

-- The exposed network: only what the mesh routes, because there is nothing
-- else to reach it by.

local x = f:section(Section, translate('Exposed network'), translate(
	'A network the rest of the mesh reaches directly, without going through '
	.. 'the node\'s own address. It takes only ranges the mesh routes, so ask '
	.. 'for one before setting this up. Leave the IPv4 range empty to do '
	.. 'without it.'
))

local exposed4 = x:option(Value, 'exposed4', translate('IPv4 range'),
	translate('A range out of the mesh\'s own, with the node\'s address in it, '
		.. 'for example 10.12.232.57/29.')
	.. ' ' .. shared(extranets.routed4(extranets.address4('exposed')),
		translate('Not set up.')))
exposed4.optional = true
exposed4.default = extranets.address4('exposed')

function exposed4:validate()
	if self.data == nil then
		return true
	end

	-- the same range on both bridges would be announced twice, out of two
	-- interfaces, and reach neither
	if extranets.routed4(self.data) == extranets.routed4(private4.data) then
		return false
	end

	-- an address the mesh does not carry would leave this network with no way
	-- in at all, rather than merely a private one
	return extranets.routed4(self.data) ~= nil
end

local exposed6 = x:option(Value, 'exposed6', translate('IPv6 range'),
	translate('Optional, and likewise a range you were assigned, for example '
		.. '2001:db8:1234::1/64.')
	.. ' ' .. shared(extranets.public6(extranets.address6('exposed')),
		translate('Not set up.')))
exposed6.optional = true
exposed6.default = extranets.address6('exposed')

function exposed6:validate()
	if self.data == nil then
		return true
	end

	if extranets.public6(self.data) == extranets.public6(private6.data) then
		return false
	end

	return extranets.public6(self.data) ~= nil
end

function f:write()
	--[[
		An assigned range goes on the bridge and gets announced; a made up one
		is a prefix to carve from. Whichever is not in use is removed, or the
		node would keep addressing itself out of both.
	]]
	uci:set('network', 'private', 'ipaddr', private4.data)

	if extranets.public6(private6.data) then
		uci:set('network', 'private', 'ip6addr', private6.data)
		uci:delete('network', 'globals', 'ula_prefix')
	else
		uci:delete('network', 'private', 'ip6addr')
		uci:set('network', 'globals', 'ula_prefix', private6.data)
	end

	-- the exposed network exists only for as long as it has a range to be
	-- reached on, so clearing that is how it is taken away again
	uci:set('network', 'exposed', 'ipaddr', exposed4.data)
	uci:set('network', 'exposed', 'ip6addr', exposed4.data and exposed6.data or nil)

	uci:save('network')

	-- the bridges, the DHCP servers and the firewall around them are all set
	-- up when the configuration is generated
	uci:set('gluon', 'core', 'reconfigure', true)
	uci:save('gluon')
	uci:commit('gluon')
	uci:commit('network')
end

return f
