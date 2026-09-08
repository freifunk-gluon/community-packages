-- A private network on a range the mesh knows - an assigned IPv6 one, or an
-- IPv4 one out of the mesh's own prefix - is announced, so the rest of the
-- mesh routes it here. One the node made up for itself is not: it means
-- nothing anywhere else.

local privatenet = require 'gluon.privatenet'

local prefixes = {}

-- collected one by one: a table constructor with a nil in it ends at the hole,
-- and either family on its own is the normal case
table.insert(prefixes, privatenet.public6(privatenet.address6()))
table.insert(prefixes, privatenet.routed4(privatenet.address4()))

for _, prefix in ipairs(prefixes) do
	route({
		cidr = prefix,
		interface = 'private',
		source = 'private-net',
	})
end
