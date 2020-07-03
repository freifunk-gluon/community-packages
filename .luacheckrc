codes = true
std = "min"
self = false

read_globals = {
	"getfenv",
	"setfenv",
	"unpack",
}

include_files = {
	"**/*.lua",
	"**/luasrc/**/*",
}

files["**/luasrc/lib/gluon/config-mode/*"] = {
	globals = {
		"DynamicList",
		"Flag",
		"Form",
		"i18n",
		"ListValue",
		"renderer.render",
		"renderer.render_string",
		"Section",
		"TextValue",
		"_translate",
		"translate",
		"translatef",
		"Value",
	},
}

files["**/luasrc/lib/gluon/**/controller/*"] = {
	read_globals = {
		"_",
		"alias",
		"call",
		"entry",
		"model",
		"node",
		"template",
	},
}

