-- The public address, announced to the mesh

local publicip = require 'gluon.publicip'

local config = publicip.config()

if config then
	if config.mode == 'forward' then
		-- the address is another device's; the mesh reaches it through here
		route({
			cidr = config.ip4 .. '/32',
			interface = config.target_interface,
			gateway = config.target,
			source = 'olsr-public-ip',
		})
	else
		-- the address sits on the tunnel this package sets up, so there is no
		-- route to install for it - only a host prefix to announce
		route({
			cidr = config.ip4 .. '/32',
			interface = publicip.INTERFACE,
			is_local = true,
			source = 'olsr-public-ip',
		})
	end
end
