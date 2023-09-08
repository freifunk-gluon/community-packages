local required = need_boolean({'mesh', 'yggdrasil', 'enabled'}, false)
need_string_array_match({'mesh', 'yggdrasil', 'peers'}, '^%l+://.+$', required)
