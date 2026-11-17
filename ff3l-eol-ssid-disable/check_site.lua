obsolete({'eol_wifi_ssid'}, 'Use eol_ssid.ssid instead.')
if need_boolean({'eol_ssid', 'enabled'}, false) then
	need_string({'eol_ssid', 'ssid'})
	need_string_match({'eol_ssid', 'date_ssid'}, '^%d%d%d%d%-%d%d%-%d%d$', false)
	need_string_match({'eol_ssid', 'date_wifi_off'}, '^%d%d%d%d%-%d%d%-%d%d$', false)
end
