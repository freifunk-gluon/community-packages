need_boolean({'mesh', 'yggdrasil', 'enabled'}, false)
need_string_array_match({'mesh', 'yggdrasil', 'peers'}, '^[a-z]{3}://.+$', false)
