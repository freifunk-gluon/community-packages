ffbs-mesh-vpn-parker
======================

This is the core package of [gluon-parker](https://github.com/ffbs/gluon-parker),
a Gluon fork that uses routing between the nodes 
(aka. Router devices) and the infrastructure. 
It is currently in use at Freifunk Braunschweig. 
Other communities are interested in adopting it as well.

This package installs the `nodeconfig` and `noderoute` services together
with a set of new firewall-rules.

The core services are:

* **Nodeconfig**:
  This service downloads and validates a node configuration from
  the concentrators and applies it.
* **Noderoute**:
  The service automatically chooses a default route from the available
  Wireshark concentrator connections.

They have their corresponding services in `/etc/init.d/` and are usually quite verbose
in `logread`.
This package also takes care of generating the WireGuard Keypair for the node.

Broadcasts after a restart
--------------------------

batman-adv starts the broadcast sequence number at 1.
Gluon creates `bat0` again at each boot and at each change of the gateway mode.
The other nodes keep the old number of the node for about 200 seconds.
They drop all its broadcasts (also router advertisements) until the new number is higher than the old number.
This can take a long time.

To prevent this, the node sends 70 small broadcasts directly on `bat0` (UDP to `255.255.255.255`, port 9) each time `bat0` is new.
It sends them when `bat0` has a neighbour, because batman-adv also counts broadcasts that no neighbour receives.
When `bat0` starts, bridge loop avoidance drops all broadcasts for about 30 seconds.
Thus the node first sends one test broadcast per second. It sends the 70 broadcasts when `tx_dropped` of `bat0` does not increase, or after 60 seconds.
The code is in `/etc/hotplug.d/net/50-parker-bcast-burst` and `/usr/share/lua/parker/bcast.lua`.
`lua5.1 tests/bcast-sim.lua` (in the package directory) simulates the probe and the burst with mock modules.

Cellular uplink
---------------

Parker puts the IPv4 routes of `wan` into table 1. Traffic with mark 1
uses only table 1. This traffic includes the DNS queries of
gluon-wan-dnsmasq, which resolve the config server name.

Gluon sets `ip6table 1` on the `cellular` uplink, but not `ip4table`.
Then the IPv4 routes of `cellular_4` go into the main table. DNS queries
to the IPv4 servers of the provider are unreachable, and `nodeconfig.sh`
stops with exit code 4.

The upgrade script `251-parker-cellular-ip4table` sets `ip4table 1` on
`cellular`. The proto handler copies it to `cellular_4`. Nodes without
`cellular` do not change.

A cellular node has no `br-wan`. The WAN device is the device of the
default route in table 1 (IPv6 first), for example `wwan0`.
`nodeconfig.sh` sends the IPv6 MTU of this device as `v6mtu`. When it
cannot read the MTU, it sends 1280. `status` uses the same device.

MTU
---

Everything our clients send leaves the node through a WireGuard tunnel,
so how big their packets may be is decided by what is left of the WAN
MTU once WireGuard has taken its share.

`nodeconfig.sh` reports the MTU the WAN device uses for IPv6 to the config
service, which answers with the MTU of the tunnels in `mtu`.
`nodeconfig.lua` puts it on every tunnel, and `noderoute.lua` passes it
on to the clients:

    wg MTU  = conf.mtu
    RA MTU  = the smallest wg MTU of the tunnels with a live handshake
    DHCP 26 = RA MTU
    MSS     = RA MTU - 60             for TCP over IPv6
            = DHCP 26 - 40            for TCP over IPv4

The tunnels with a live handshake are all candidates for the default
route, and noderoute may pick another one on any of its cycles without
the clients noticing, so they are told the smallest of them. No MTU is
announced in the router advertisements below the 1280 bytes IPv6 needs
on a link: uradvd rejects one and exits, which would leave the client
network without router advertisements at all.

Nothing announces an MSS. fw4 clamps it, from `mtu_fix '1'` on the
`vpn_parker` zone, by way of a `tcp option maxseg size set rt mtu` rule
in `mangle_forward` and `mangle_postrouting`; the kernel subtracts 40
bytes of IPv4 or 60 bytes of IPv6 and TCP header from the MTU of the
route a packet takes.

site.conf
---------

This package relies on the following parameters in your `site.conf`:

```json
parker = {
        config_server = "config.yourcommunity.net",
        config_pubkey = "<Your usign config signing pubkey>",

        -- optional
        disable_client_snooping = false,
},
```

Multicast snooping
------------------

`disable_client_snooping` is optional. The default is `false`. Then the
node keeps the Gluon defaults: multicast snooping and the multicast querier
are on for `br-client`.

Set it to `true` to switch off snooping and the querier on `br-client`. The
querier needs snooping, so it has no function without it. The upgrade
script `902-parker-client-no-snooping` does this step.

Use this option when clients lose IPv6. With snooping, the bridge sends a
multicast packet only to the ports that have an entry for its group. The
neighbour solicitation (NS) for a client address goes to the
solicited-node group of that address. When a client has no entry (seen
with iPhones), it does not get the NS. Its address stays INCOMPLETE, and
the client loses IPv6.

Without snooping:

* The bridge sends each multicast packet to all ports of `br-client`.
* batman-adv marks the node as not able to snoop. Other nodes then send
  all multicast to this node.
* This adds multicast traffic only in the local mesh. A Parker node has
  no VPN mesh, so no multicast goes through the tunnels.
