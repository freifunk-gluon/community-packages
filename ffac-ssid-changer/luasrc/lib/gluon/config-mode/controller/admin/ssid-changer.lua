local uci = require("simple-uci").cursor()
local wireless = require 'gluon.wireless'

package 'ffac-ssid-changer'

if wireless.device_uses_wlan(uci) then
	entry({"admin", "ssid-changer"}, model("admin/ssid-changer"), _("Offline-SSID"), 35)
end
