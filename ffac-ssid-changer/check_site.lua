need_boolean({'ssid_changer', 'enabled'}, false)
need_number_range({'ssid_changer', 'switch_timeframe'}, 1, math.huge, false)
need_string({'ssid_changer', 'prefix'}, false)
local suffix = need_one_of({'ssid_changer', 'suffix'}, {'nodename', 'mac', 'none'}, false) or 'nodename'

-- The Offline-SSID must not exceed 32 bytes. A long nodename is shortened to
-- its first and last characters, which only works for a prefix of at most 26
-- bytes, and a MAC address needs 12 bytes.
local max_prefix_length = ({nodename = 26, mac = 20, none = 32})[suffix]
need({'ssid_changer', 'prefix'}, function(prefix)
	return #prefix <= max_prefix_length
end, false, string.format("be at most %d bytes long with suffix '%s'", max_prefix_length, suffix))
need_boolean({'ssid_changer', 'debug_log_enabled'}, false)
if need_boolean({'ssid_changer','tq_limit_enabled'}, false) then
	need_number({'ssid_changer', 'tq_limit_max'}, false)
	need_number({'ssid_changer', 'tq_limit_min'}, false)
end

obsolete({'ssid_changer', 'first'},
	'The Offline-SSID is now set after switch_timeframe / 2 offline minutes.')
obsolete({'ssid_changer', 'prefix_owe'},
	'OWE client networks are disabled while the node is offline.')
