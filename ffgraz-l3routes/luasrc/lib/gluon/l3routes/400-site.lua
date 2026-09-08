-- Announcements the whole domain makes, from site.conf

local site = require 'gluon.site'

for _, entry in ipairs(site.l3routes({})) do
	if entry.cidr and entry.interface then
		route({
			cidr = entry.cidr,
			interface = entry.interface,
			gateway = entry.gateway,
			metric = entry.metric,
			is_local = entry.is_local,
			firewall = entry.firewall,
			source = 'site',
		})
	else
		import({
			table = entry.table,
			proto = entry.proto,
			cidr = entry.cidr,
			le = entry.le,
			family = entry.family,
			source = 'site',
		})
	end
end
