-- Extra prefixes every node of the domain announces. An entry with a cidr and
-- an interface is a route, anything else is an import of a kernel routing
-- table or of a routing protocol.
need_array(in_domain({'l3routes'}), function(entry)
	need_string_match(extend(entry, {'cidr'}), '^[%x:%.]+/%d+$', false)
	need_string(extend(entry, {'interface'}), false)
	need_number(extend(entry, {'metric'}), false)
	need_boolean(extend(entry, {'is_local'}), false)
	need_boolean(extend(entry, {'firewall'}), false)
	need_number(extend(entry, {'table'}), false)
	need_number(extend(entry, {'le'}), false)
	need_one_of(extend(entry, {'family'}), {4, 6}, false)
end, false)
