local uci = require("simple-uci").cursor()

local site = require("gluon.site")
local util = require("gluon.util")

local M = {}

function M.public_key()
	local key = util.trim(util.exec("cat /etc/parker/wg-pubkey"))

	if key == "" then
		key = nil
	end

	return key
end

function M.enable(val)
	uci:set("parker", "mesh_vpn", "enabled", val)
	uci:save("parker")
end

function M.active()
	return site.mesh_vpn.parker() ~= nil
end

function M.mtu()
	return site.mesh_vpn.parker.mtu()
end

function M.set_limit(ingress_limit, egress_limit) -- luacheck: ignore
	-- In Parker limits have to be applied at runtime since the VPN interfaces
	-- are dynamically configured during runtime.
	-- Let's just implement this interface to other scripts can call it without
	-- raising exceptions.
end


return M
