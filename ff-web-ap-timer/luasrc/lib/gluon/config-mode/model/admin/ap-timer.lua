local uci = require('simple-uci').cursor()

pkg_i18n = i18n 'ffho-web-ap-timer'

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

local s = f:section(Section)

enabled = s:option(Flag, 'enabled', pkg_i18n.translate('Enabled'))
enabled.default = uci:get_bool('ap-timer', 'settings', 'enabled')
enabled.optional = false
function enabled:write(data)
	uci:set('ap-timer', 'settings', 'enabled', data)
end

local timer_type = s:option(ListValue, 'type', pkg_i18n.translate('Type'))
timer_type.default = uci:get('ap-timer', 'settings', 'type')
timer_type:depends(enabled, true)
timer_type:value('day', pkg_i18n.translate('Daily'))
function timer_type:write(data)
	uci:set('ap-timer', 'settings', 'type', data)
end

local s = f:section(Section)

o = s:option(DynamicList, 'on', pkg_i18n.translate('ON'))
o.default = uci:get_list('ap-timer', 'all', 'on')
o.placeholder = '06:30'
o:depends(timer_type, 'day')
o.optional = false
o.datatype = 'minlength(5)'
function o:write(data)
	uci:set_list('ap-timer', 'all', 'on', data)
end

o = s:option(DynamicList, 'off', pkg_i18n.translate('OFF'))
o.default = uci:get_list('ap-timer', 'all', 'off')
o.placeholder = '23:00'
o:depends(timer_type, 'day')
o.optional = false
o.datatype = 'minlength(5)'
function o:write(data)
	uci:set_list('ap-timer', 'all', 'off', data)
end

function f:write()
	uci:commit('ap-timer')
end

return f
