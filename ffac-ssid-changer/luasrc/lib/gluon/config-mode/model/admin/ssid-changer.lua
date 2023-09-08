local uci = require('simple-uci').cursor()

local pkg_i18n = i18n 'ffac-ssid-changer'

local f = Form(pkg_i18n.translate('Offline-SSID'))

local s = f:section(Section, nil, pkg_i18n.translate(
	'Here you can enable to automatically change the SSID to the Offline-SSID '
	.. 'when the node has no connection to the selected Gateway.'
))

local enabled = s:option(Flag, 'enabled', pkg_i18n.translate('Enabled'))
enabled.default = uci:get_bool('ssid-changer', 'settings', 'enabled')

-- local prefix = s:option(Value, 'prefix', pkg_i18n.translate('First part of the Offline SSID'))
-- prefix:depends(enabled, true)
-- prefix.datatype = 'maxlength(32)'
-- prefix.default = uci:get('ssid-changer', 'settings', 'prefix')

function f:write()
	if enabled.data then
		uci:section('ssid-changer', 'settings', 'settings', {
			enabled = '1',
			-- switch_timeframe = switch_timeframe.data or '1440'
			-- tq_limit_max = tq_limit_max.data or '55'
			-- first = first.data or '5'
			-- prefix = prefix.data or 'FF_Offline_'
			-- prefix_owe = prefix.data or 'FF_Off_OWE'
			-- suffix = suffix.data or 'nodename'
			-- tq_limit_min = tq_limit_min.data or '45'
			-- tq_limit_enabled = tq_limit_enabled.data or '0'
		})
	else
		uci:set('ssid-changer', 'settings', 'enabled', '0')
	end

	uci:commit('ssid-changer')
end

return f
