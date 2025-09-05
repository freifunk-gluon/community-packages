local uci = require("simple-uci").cursor()
local wireless = require 'gluon.wireless'

package 'ff-web-ap-timer'

if wireless.device_uses_wlan(uci) then
	entry({"admin", "ap-timer"}, model("admin/ap-timer"), _("AP Timer"), 30)
end
