need_boolean({'ssid_changer', 'enabled'}, false)
need_number({'ssid_changer', 'switch_timeframe'}, false)
need_number({'ssid_changer', 'first'}, false)
need_string({'ssid_changer', 'prefix'}, false)
need_string({'ssid_changer', 'prefix_owe'}, false)
need_one_of({'ssid_changer', 'suffix'}, {'nodename', 'mac', 'none'}, false)
need_boolean({'ssid_changer', 'debug_log_enabled'}, false)
if need_boolean({'ssid_changer','tq_limit_enabled'}, false) then
	need_number({'ssid_changer', 'tq_limit_max'}, false)
	need_number({'ssid_changer', 'tq_limit_min'}, false)
end
