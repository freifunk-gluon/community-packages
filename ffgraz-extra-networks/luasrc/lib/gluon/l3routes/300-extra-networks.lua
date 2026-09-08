-- A network on a range the mesh knows - an assigned IPv6 one, or an IPv4 one
-- out of the mesh's own prefix - is announced, so the rest of the mesh routes
-- it here. One the node made up for itself is not: it means nothing anywhere
-- else. The exposed network is only ever the first kind.

local extranets = require 'gluon.extranets'

for _, network in ipairs(extranets.NETWORKS) do
	local prefixes = {}

	-- collected one by one: a table constructor with a nil in it ends at the
	-- hole, and either family on its own is the normal case
	table.insert(prefixes, extranets.public6(extranets.address6(network.name)))
	table.insert(prefixes, extranets.routed4(extranets.address4(network.name)))

	for _, prefix in ipairs(prefixes) do
		route({
			cidr = prefix,
			interface = network.name,
			source = 'extra-networks',
		})
	end
end
