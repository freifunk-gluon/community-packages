--[[
	What the operator entered in the config mode.

	An entry that was just added through the page is still empty, and one can
	be left half filled in. Those are skipped rather than collected: a prefix
	nobody has typed yet must not make gluon-reconfigure fail.
]]

local uci = require('simple-uci').cursor()

uci:foreach('gluon-l3routes-custom', 'route', function(s)
	if s.enabled ~= '0' and s.cidr and s.interface then
		route({
			cidr = s.cidr,
			interface = s.interface,
			metric = s.metric,
			table = s.table,
			is_local = s.is_local,
			firewall = s.firewall,
			source = 'custom',
		})
	end
end)

uci:foreach('gluon-l3routes-custom', 'import', function(s)
	if s.enabled ~= '0' and (s.proto or s.cidr) then
		import({
			table = s.table,
			proto = s.proto,
			cidr = s.cidr,
			le = s.le,
			family = s.family,
			metric = s.metric,
			source = 'custom',
		})
	end
end)
