need_boolean({'ssid_changer', 'enabled'}, false)
need_number({'ssid_changer', 'switch_timeframe'}, false)
need_string({'ssid_changer', 'prefix'}, false)
need_one_of({'ssid_changer', 'suffix'}, {'nodename', 'mac', 'none'}, false)
if need_boolean({'ssid_changer','tq_limit_enabled'}, false) then
	need_number({'ssid_changer', 'tq_limit_max'}, false)
	need_number({'ssid_changer', 'tq_limit_min'}, false)
end

-- Settings that used to exist but are ignored now. obsolete() is deliberately not
-- used here, as it would abort the firmware build: a leftover setting does no harm,
-- so warn about it and let the build finish.
local function removed(path, msg)
	if loadvar(path) ~= nil then
		io.stderr:write('*** ', conf_src(path), ' warning: ', table.concat(path, '.'),
			' is obsolete and ignored. ', msg, '\n')
	end
end

removed({'ssid_changer', 'first'},
	'The Offline-SSID is now set after switch_timeframe / 2 offline minutes; ' ..
	'the first minutes after a reboot are no longer special-cased.')
removed({'ssid_changer', 'prefix_owe'},
	'OWE client networks are disabled while the node is offline instead of being renamed.')
