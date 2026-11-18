obsolete({'eol_wifi_ssid'}, 'Use eol_ssid.ssid instead.')
if need_boolean({'eol_ssid', 'enabled'}, false) then
	need_string({'eol_ssid', 'ssid'})
end
