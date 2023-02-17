package 'ffgraz-config-mode-at-runtime'

local classes = require 'gluon.web.model.classes'
local uci = require('simple-uci').cursor()

local Form = classes.Form

function Form:handle()
	if self.state == classes.FORM_VALID then
		for _, node in ipairs(self.children) do
			node:handle()
		end
		self:write(self.data)

    uci:set('gluon', 'core', 'reconfigure', true)
    uci:save('gluon')
    os.execute('uci commit')
	end
end

local authenticate = require 'gluon.config-mode.runtime.auth'

local err, res = authenticate()

if err then
	io.write("Status: 403 Forbidden\r\n")
	io.write("Content-Type: text/plain\r\n")
	io.write("\r\n")
	io.write("Failed to authenticate:\r\n")
	io.write(err .. "\r\n")
	os.exit(0)
end

local Auth = res

classes.Auth = Auth

entry({}, alias("main"))
entry({"main"}, model("gluon-config-mode-runtime/main"), _("Main"), 2)
entry({"wizard"}, model("gluon-config-mode-runtime/wizard"), _("Wizard"), 5)
entry({"apply"}, model("gluon-config-mode-runtime/apply"), _("Apply"), 100).hidden = true
