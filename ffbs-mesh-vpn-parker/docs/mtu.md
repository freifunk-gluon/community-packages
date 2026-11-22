MTU
===

Each packet of a client leaves the node through a WireGuard tunnel. Thus
the clients must not send packets larger than the MTU of the tunnels.

* `nodeconfig.sh` sends the IPv6 MTU of the WAN uplink to the config
    service as `v6mtu`.
* The config service answers with the tunnel MTU in `mtu`.
* `nodeconfig.lua` sets this MTU on every `wg_*` tunnel.
* `noderoute.lua` announces the smallest MTU of the tunnels with a live
    handshake, because each of these tunnels can carry the default route
    after the next cycle. It announces the MTU in the router
    advertisements for IPv6 and in DHCP option 26 for IPv4.

Router advertisements
---------------------

`noderoute.lua` writes the MTU to `/tmp/adv_mtu`, and
`/lib/gluon/radvd/arguments` has to pass it to uradvd with
`--adv-link-mtu`. Upstream Gluon does not pass it, and the main branch of
uradvd has no `--adv-link-mtu`. Thus the router advertisements only carry
the MTU with the radvd arguments of the FreifunkMUC Gluon fork (branch
`v2025.1.x-parker`) and a uradvd that has `--adv-link-mtu`.

uradvd exits when it gets an MTU below 1280, so `noderoute.lua` does not
write such a value.

MSS clamping
------------

The node does not announce a TCP MSS. fw4 clamps it, because
`904-parker-firewall` sets `mtu_fix '1'` on the `vpn_parker` zone. For
this option, fw4 adds the rule `tcp option maxseg size set rt mtu`. The
kernel then sets the MSS to the MTU of the route of the packet minus 40
bytes for IPv4 or minus 60 bytes for IPv6.
