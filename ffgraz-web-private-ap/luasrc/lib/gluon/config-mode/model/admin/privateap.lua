local uci = require("simple-uci").cursor()
local wireless = require 'gluon.wireless'

--[[
	Where the settings live. Not in the wireless sections they end up in:
	wireless is not regenerated on reconfigure, so what was written straight
	into it was gone as soon as the interfaces were rebuilt.
]]
local CONFIG = 'private_ap'

local f = Form(translate("Private AP"))

local s = f:section(Section, nil, translate(
	'A wifi network of your own on this node. It reaches the same private '
	.. 'network as the ports set aside for it, which is configured under '
	.. 'Network ranges. Gluon\'s own private WLAN is a different thing: that '
	.. 'one extends the network the node is plugged into.'
))

local enabled = s:option(Flag, "enabled", translate("Enabled"))
enabled.default = uci:get_bool('gluon', CONFIG, 'enabled')

local ssid = s:option(Value, "ssid", translate("Name (SSID)"))
ssid:depends(enabled, true)
ssid.datatype = "maxlength(32)"
ssid.default = uci:get('gluon', CONFIG, 'ssid')

local key = s:option(Value, "key", translate("Key"), translate("8-63 characters"))
key:depends(enabled, true)
key.datatype = "wpakey"
key.default = uci:get('gluon', CONFIG, 'key')

local encryption = s:option(ListValue, "encryption", translate("Encryption"))
encryption:depends(enabled, true)
encryption:value("psk2", translate("WPA2"))
if wireless.device_supports_wpa3() then
	encryption:value("sae-mixed", translate("WPA2 / WPA3"))
	encryption:value("sae", translate("WPA3"))
end
encryption.default = uci:get('gluon', CONFIG, 'encryption') or "psk2"

local mfp = s:option(ListValue, "mfp", translate("Management Frame Protection"))
mfp:depends(enabled, true)
mfp:value("0", translate("Disabled"))
if wireless.device_supports_mfp(uci) then
	mfp:value("1", translate("Optional"))
	mfp:value("2", translate("Required"))
end
mfp.default = uci:get('gluon', CONFIG, 'mfp') or "0"

function f:write()
	uci:section('gluon', CONFIG, CONFIG, {
		enabled = enabled.data,
		ssid = enabled.data and ssid.data or nil,
		key = enabled.data and key.data or nil,
		encryption = enabled.data and encryption.data or nil,
		mfp = enabled.data and mfp.data or nil,
	})

	-- the interfaces themselves are built when the configuration is generated
	uci:set('gluon', 'core', 'reconfigure', true)
	uci:save('gluon')
	uci:commit('gluon')
end

return f
