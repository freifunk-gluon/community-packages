DHCPv4 lease limit
==================

dnsmasq gives out no more than `dhcp-lease-max` leases (default 1000).
Gluon does not set it. When the node routes, `noderoute.lua` sets
`dhcpleasemax` to the pool size of `range4` (at least 1000), for example
4093 for a /20. When the node stops routing, `noderoute.lua` removes the
option again.
