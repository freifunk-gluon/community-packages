local function check_peer(k)
	-- we do need unnamed / numeric keys
	need_string_match(in_domain(extend(k,
		{'publickey'})), "^" .. ("[%a%d+/]"):rep(42) .. "[AEIMQUYcgkosw480]=$")
	need_string(in_domain(extend(k, {'endpoint'})))
	need_string(in_domain(extend(k, {'link_address'})))
end

need_table({'mesh_vpn', 'wireguard', 'peers'}, check_peer)
need_number({'mesh_vpn', 'wireguard', 'mtu'})
need_string({'mesh_vpn', 'wireguard', 'broker'})
