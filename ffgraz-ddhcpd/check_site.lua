#!/usr/bin/lua

need_string_match(in_domain({'next_node', 'ip4'}), '^%d+.%d+.%d+.%d+$')
local has_prefix4 = need_string_match(in_domain({'prefix4'}), '^%d+.%d+.%d+.%d+/%d+$', false)

need_boolean({'ddhcpd', 'enabled'}, false)
need_string_match({'ddhcpd', 'range'}, '^%d+.%d+.%d+.%d+/%d+$', not has_prefix4)
need_number({'ddhcpd', 'block_size'}, false)
need_number({'ddhcpd', 'block_timeout'}, false)
need_number({'ddhcpd', 'dhcp_lease_time'}, false)
need_number({'ddhcpd', 'spare_leases'}, false)
need_number({'ddhcpd', 'tentative_timeout'}, false)
