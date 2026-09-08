-- A private network on an assigned IPv6 range is announced, so the mesh knows
-- to route it here. One the node made up for itself is not: it means nothing
-- anywhere else.

local privatenet = require 'gluon.privatenet'

local prefix = privatenet.public6(privatenet.address6())

if prefix then
	route({
		cidr = prefix,
		interface = 'private',
		source = 'private-net',
	})
end
