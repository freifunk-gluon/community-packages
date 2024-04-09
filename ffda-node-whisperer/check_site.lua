local information = {
	'hostname',
	'node_id',
	'uptime',
	'site_code',
	'domain',
	'system_load',
	'firmware_version',
	'batman_adv'
}

need_boolean({'node_whisperer', 'enabled'}, false)
need_array_of({'node_whisperer', 'information'}, information, false)
