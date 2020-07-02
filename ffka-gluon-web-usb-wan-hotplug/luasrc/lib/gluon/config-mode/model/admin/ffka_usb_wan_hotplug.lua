local uci = require("simple-uci").cursor()

local f = Form(translate("USB-WAN-Hotplug"))

local s = f:section(Section, nil, translate('ffka-gluon-web-usb-wan-hotplug:description'))

local enabled = s:option(Flag, "enabled", translate("Enabled"))
enabled.default = uci:get_bool('usb-wan-hotplug', 'settings', 'enabled', false)

function f:write()
	if enabled.data then
		uci:set('usb-wan-hotplug', 'settings', 'enabled', true)
	else
		uci:set('usb-wan-hotplug', 'settings', 'enabled', false)
	end
	uci:commit('usb-wan-hotplug')
end

return f
