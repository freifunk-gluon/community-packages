local site_i18n = i18n 'gluon-site'

local uci = require("simple-uci").cursor()
local lutil = require "gluon.web.util"
local unistd = require 'posix.unistd'

local site = require 'gluon.site'
local sysconfig = require 'gluon.sysconfig'
local util = require "gluon.util"

local pretty_hostname = require 'pretty_hostname'



local has_fastd = unistd.access('/lib/gluon/mesh-vpn/fastd')
local has_tunneldigger = unistd.access('/lib/gluon/mesh-vpn/tunneldigger')
local has_wireguard = unistd.access('/lib/gluon/mesh-vpn/wireguard')


local hostname = pretty_hostname.get(uci)
local contact = uci:get_first("gluon-node-info", "owner", "contact")

local pubkey
local msg


if has_tunneldigger then
	local tunneldigger_enabled = uci:get_bool("tunneldigger", "mesh_vpn", "enabled")
	if not tunneldigger_enabled then
		msg = _translate('gluon-config-mode:novpn')
	end
elseif has_fastd then
	local fastd_enabled = uci:get_bool("fastd", "mesh_vpn", "enabled")
	if fastd_enabled then
		pubkey = util.trim(lutil.exec("/etc/init.d/fastd show_key mesh_vpn"))
		msg = _translate('gluon-config-mode:pubkey')
	else
		msg = _translate('gluon-config-mode:novpn')
	end
elseif has_wireguard then
	local wireguard_enabled = uci:get_bool("wireguard", "wireguard", "enabled")
        if not wireguard_enabled then
                msg = _translate('gluon-config-mode:novpn')
        end
end

if not msg then return end

renderer.render_string(msg, {
	pubkey = pubkey,
	hostname = hostname,
	site = site,
	sysconfig = sysconfig,
	contact = contact,
})
