local uci = require("simple-uci").cursor()
local wireless = require 'gluon.wireless'

package 'ffgraz-web-private-ap'

if wireless.device_uses_wlan(uci) then
	entry({"admin", "privateap"}, model("admin/privateap"), _("Private AP"), 31)
end
