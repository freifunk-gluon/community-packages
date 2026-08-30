local uci = require('simple-uci').cursor()

local site = require 'gluon.site'
local vpn_core = require 'gluon.mesh-vpn'

local M = {}

function M.public_key()
	-- TODO: get key from openvpn.mesh_vpn.key and then get fingerprint
	return nil
end

function M.enable(val)
	uci:set('openvpn', 'mesh_vpn', 'enabled', val)
	uci:save('openvpn')
end

function M.active()
	return site.mesh_vpn.openvpn() ~= nil
end

function M.set_limit(ingress_limit, egress_limit)
	uci:delete('simple-tc', 'mesh_vpn')
	if ingress_limit ~= nil and egress_limit ~= nil then
		uci:section('simple-tc', 'interface', 'mesh_vpn', {
			ifname = vpn_core.get_interface(),
			enabled = true,
			limit_egress = egress_limit,
			limit_ingress = ingress_limit,
		})
	end

	uci:save('simple-tc')
end

function M.mtu()
	return site.mesh_vpn.openvpn.mtu(1500)
end

-- Part of the provider interface: gluon.mesh-vpn asks every provider
-- this before it publishes a key, and a provider that does not answer
-- takes the status page down with "attempt to call field
-- 'pubkey_privacy' (a nil value)". A node identifies itself to the
-- OpenVPN server with a client certificate and has no public key to
-- hand out in the first place, so there is nothing to publish.
function M.pubkey_privacy()
	return true
end

return M
