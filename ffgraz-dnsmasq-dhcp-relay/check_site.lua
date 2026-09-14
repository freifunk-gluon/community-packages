#!/usr/bin/lua

-- the address clients reach their own node on: the relay puts it in the
-- link selection, so it is what picks the network the server allocates from
need_string_match(in_domain({'next_node', 'ip4'}), '^%d+.%d+.%d+.%d+$')

need_string_match({'dnsmasq_dhcp_relay', 'server'}, '^%d+.%d+.%d+.%d+$')

-- the relay answers to an address of the node's own, which is derived from
-- node_prefix4 where gluon-mesh-olsrd is not installed to do it
need_string({'node_prefix4'}, false)
