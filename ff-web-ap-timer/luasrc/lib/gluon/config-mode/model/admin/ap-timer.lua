local uci = require('simple-uci').cursor()

local pkg_i18n = i18n 'ff-web-ap-timer'

if not uci:get('ap-timer', 'settings') then
	uci:section('ap-timer', 'ap-timer', 'settings')
	uci:save('ap-timer')
end

if not uci:get('ap-timer', 'all') then
	uci:section('ap-timer', 'day', 'all')
	uci:save('ap-timer')
end

local f = Form(pkg_i18n.translate('AP Timer'), pkg_i18n.translate(
	'You can setup the AP Timer here'))

local sec1 = f:section(Section)

local enabled = sec1:option(Flag, 'enabled', pkg_i18n.translate('Enabled'))
enabled.default = uci:get_bool('ap-timer', 'settings', 'enabled')
enabled.optional = false
function enabled:write(data)
	uci:set('ap-timer', 'settings', 'enabled', data)
end

local timer_type = sec1:option(ListValue, 'type', pkg_i18n.translate('Type'))
timer_type.default = uci:get('ap-timer', 'settings', 'type')
timer_type:depends(enabled, true)
timer_type:value('day', pkg_i18n.translate('Daily'))
function timer_type:write(data)
	uci:set('ap-timer', 'settings', 'type', data)
end

local sec2 = f:section(Section)

local on = sec2:option(DynamicList, 'on', pkg_i18n.translate('ON'))
on.default = uci:get_list('ap-timer', 'all', 'on')
on.placeholder = '06:30'
on:depends(timer_type, 'day')
on.optional = false
on.datatype = 'minlength(5)'
function on:write(data)
	uci:set_list('ap-timer', 'all', 'on', data)
end

local off = sec2:option(DynamicList, 'off', pkg_i18n.translate('OFF'))
off.default = uci:get_list('ap-timer', 'all', 'off')
off.placeholder = '23:00'
off:depends(timer_type, 'day')
off.optional = false
off.datatype = 'minlength(5)'
function off:write(data)
	uci:set_list('ap-timer', 'all', 'off', data)
end

function f:write()
	uci:commit('ap-timer')
end

return f
