local util = require "gluon.util"
local uci = require("simple-uci").cursor()

local f = Form(translate("Welcome!"))
f.reset = false

local s = f:section(Section)
s.template = "wizard/welcome"
s.package = "gluon-config-mode-core"

for _, entry in ipairs(util.glob('/lib/gluon/config-mode/wizard/*')) do
	local section = assert(loadfile(entry))
	setfenv(section, getfenv())
	section()(f, uci)
end

return f
