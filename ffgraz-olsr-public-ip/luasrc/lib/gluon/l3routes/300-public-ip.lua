-- The public address, announced to the mesh

local uci = require('simple-uci').cursor()

if uci:get_bool('gluon', 'olsr_public_ip', 'enabled') then
	local address = uci:get('gluon-static-ip', 'olsr_public_ip', 'ip4')

	if address then
		-- the address sits on the tunnel this package sets up, so there is no
		-- route to install for it - only a host prefix to announce
		route({
			cidr = address .. '/32',
			interface = 'olsr_public_ip',
			is_local = true,
			source = 'olsr-public-ip',
		})
	end
end
