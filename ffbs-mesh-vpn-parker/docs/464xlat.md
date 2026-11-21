464XLAT
=======

The 464XLAT mode is on while the config service answers with
`xlat_range6`. A node whose config has no `xlat_range6` runs none of
this. In this mode, `nodeconfig.lua` configures the tunnels with
allowed-ips `::/0` only. While the node routes for its clients,
`noderoute.lua` also:

* writes the prefix to `/tmp/xlat_range6` and runs
    `/etc/init.d/ebpf-clat start`,
* announces DHCPv4 option 108, IPv6-Only Preferred (RFC 8925),
* writes the NAT64 prefix `64:ff9b::/96` to `/tmp/pref64`,
* subtracts 28 bytes from DHCP option 26 and puts the result on the
    IPv4 default route as its MTU, see [mtu.md](mtu.md).

Dependencies
------------

The mode needs two things outside this package:

* The package `ffmuc-ebpf-clat`, which provides `/etc/init.d/ebpf-clat`.
    This package does not depend on it.
* A Gluon whose radvd arguments pass `/tmp/pref64` to uradvd, as the
    Gluon change "gluon-mesh-batman-adv: announce the NAT64 prefix in
    router advertisements" does. `/tmp/adv_mtu` needs the same kind of
    change, see [mtu.md](mtu.md).

With `xlat_range6` in the config but without `ffmuc-ebpf-clat` in the
firmware, the tunnels allow only IPv6 and the clients get option 108. The
start of `/etc/init.d/ebpf-clat` fails, so nothing translates the IPv4
traffic of the clients.
