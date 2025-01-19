local uci = require("simple-uci").cursor()

local f = Form(translate("DSL"))

local s = f:section(Section, nil, translate('ffac-web-dsl:description'))

local enabled = s:option(Flag, "enabled", translate("Enabled"))
enabled.default = uci:get_bool('gluon', 'dsl', 'enabled', false)

local username = s:option(Value, "username", translate("Username"))
username:depends(enabled, true)
username.default = uci:get('gluon', 'dsl', 'username')

local password = s:option(Value, "password", translate("Password"))
password:depends(enabled, true)
password.default = uci:get('gluon', 'dsl', 'password')

local vlanid = s:option(Value, "vlanid", translate("VlanID"))
vlanid:depends(enabled, true)
vlanid.default = uci:get('gluon', 'dsl', 'vlanid') or '0'

function f:write()
	local dsl_enabled = false
	if enabled.data then
		dsl_enabled = true
	end

	uci:section('gluon', 'dsl', 'dsl', {
		enabled = dsl_enabled,
		vlanid = vlanid.data,
		username = username.data,
		password = password.data,
	})

	uci:commit('gluon')
end

return f
