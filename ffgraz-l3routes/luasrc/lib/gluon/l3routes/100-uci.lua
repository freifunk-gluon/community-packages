-- Routes and imports other modules stored with gluon.l3routes.add()

local uci = require('simple-uci').cursor()

uci:foreach('gluon-l3routes', 'route', function(s)
	if s.enabled ~= '0' then
		route({
			cidr = s.cidr,
			interface = s.interface,
			gateway = s.gateway,
			metric = s.metric,
			table = s.table,
			is_local = s.is_local,
			firewall = s.firewall,
			comment = s.comment,
			source = s.source or s['.name'],
		})
	end
end)

uci:foreach('gluon-l3routes', 'import', function(s)
	if s.enabled ~= '0' then
		import({
			table = s.table,
			proto = s.proto,
			cidr = s.cidr,
			le = s.le,
			family = s.family,
			source = s.source or s['.name'],
		})
	end
end)
