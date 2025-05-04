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

return M
