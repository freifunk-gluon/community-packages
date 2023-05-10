if need_table(in_site({'scheduled_sysupgrade'}), nil, false) then
	need_string(in_site({'scheduled_sysupgrade', 'firmware_server'}))
	need_number(in_site({'scheduled_sysupgrade', 'switch_after_existing_mins'}))
	need_number(in_site({'scheduled_sysupgrade', 'switch_time'}))
end
