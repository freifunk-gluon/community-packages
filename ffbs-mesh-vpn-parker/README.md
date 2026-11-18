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

Client addresses
----------------

The config service hands the same `range4` and the same `address4` to every
node, so all the nodes that mesh with each other claim the same address on
the client network they share. A node that finds another one using its
address therefore moves to one of the first 16 addresses of `range4`, chosen
from its own MAC, and remembers that in `parker.client.address4` until the
config service gives it a different range. Nodes that have moved keep that
block of addresses out of the DHCP pool they hand to their clients.

MTU
---

Everything our clients send leaves the node through a WireGuard tunnel,
so how big their packets may be is decided by what is left of the WAN
MTU once WireGuard, and with 464XLAT the CLAT as well, have taken their
share.

`nodeconfig.sh` reports the MTU `br-wan` uses for IPv6 to the config
service, which answers with an upper bound in `mtu`. The service cannot
know whether a tunnel ends up running over IPv6 or over IPv4, which
differ by the 20 bytes between the two IP headers, so `nodeconfig.lua`
finishes the calculation once it has resolved an endpoint, and
`noderoute.lua` passes the result on to the clients:

    A         the MTU br-wan uses for IPv6, 1436 behind DS-Lite
    wg MTU  = min(conf.mtu, A - 80)   for an endpoint reached over IPv6
            = min(conf.mtu, A - 60)   for one reached over IPv4
    RA MTU  = the smallest wg MTU of the tunnels with a live handshake
    DHCP 26 = RA MTU - 28             while the CLAT translates for us
            = RA MTU                  when it does not
    MSS     = RA MTU - 60             for TCP over IPv6
            = DHCP 26 - 40            for TCP over IPv4

With the `mtu = min(v6mtu, 1375)` the config service answers with today
that comes out as:

| WAN MTU | endpoint | wg MTU | RA option 5 | DHCP option 26 | MSS v6 | MSS v4 |
| ------: | :------- | -----: | ----------: | -------------: | -----: | -----: |
|    1436 | IPv6     |   1356 |        1356 |           1328 |   1296 |   1288 |
|    1436 | IPv4     |   1375 |        1375 |           1347 |   1315 |   1307 |
|    1500 | IPv6     |   1375 |        1375 |           1347 |   1315 |   1307 |
|    1500 | IPv4     |   1375 |        1375 |           1347 |   1315 |   1307 |

The 1375 is what keeps the last three rows from reaching the 1420, 1440
and 1376 their WAN would allow.

The 28 bytes the CLAT costs are the 20 between the IPv4 header it takes
off and the IPv6 header it puts on, plus the 8 bytes of the fragment
header RFC 7915 asks a translator to add to an IPv4 fragment. The kernel
fragments IPv4 packets without DF at the 1347 of the route, and
ebpf-clat translates each TCP or UDP fragment to an IPv6 fragment of at
most 1375 bytes. Fragmented ICMP is dropped (RFC 7915 section 1.3), so
a `ping -s 1400` over IPv4 gets no answer.

The tunnels with a live handshake are all candidates for the default
route, and noderoute may pick another one on any of its cycles without
the clients noticing, so they are told the smallest of them. A tunnel is
never sized below the 1280 bytes IPv6 needs on a link, and no MTU is
announced in the router advertisements below that either: uradvd rejects
one and exits, which would leave the client network without router
advertisements at all.

Nothing announces an MSS. fw4 clamps it, from `mtu_fix '1'` on the
`vpn_parker` zone, by way of a `tcp option maxseg size set rt mtu` rule
in `mangle_forward` and `mangle_postrouting`; the kernel subtracts 40
bytes of IPv4 or 60 bytes of IPv6 and TCP header from the MTU of the
route a packet takes. That clamp runs before the CLAT, which is attached
to the tc egress hook of the wg-interface, and it therefore sees the
untranslated IPv4 packet. The 28 bytes reach it because noderoute puts
them on the IPv4 default route rather than on the interface, which
carries the IPv6 packets that do not pay them.

site.conf
---------

This package relies on the following parameters in your `site.conf`:

```json
parker = {
        config_server = "config.yourcommunity.net",
        config_pubkey = "<Your usign config signing pubkey>",

        -- optional
        client_ntp_servers4 = { "198.51.100.123" },
        unifi_controller4 = "198.51.100.10",
        omada_controllers4 = { "198.51.100.11" },
        disable_client_snooping = false,
},
```

`client_ntp_servers4` lists the NTP servers announced to clients via
DHCPv4 option 42. That option carries IPv4 addresses only, so hostnames
and IPv6 addresses cannot be used here — unlike in `ntp_servers`, which
configures the node's own clock.

When it is unset, a single IPv4 address in `ntp_servers` is passed on to
clients instead.

`unifi_controller4` and `omada_controllers4` tell the access points an
operator hangs off the client network where to find their controller, so
that they can be adopted without the controller sharing their broadcast
domain. Both take IPv4 addresses only.

A UniFi access point learns `unifi_controller4` from suboption 1 of the
vendor-specific DHCPv4 option 43. Only clients whose vendor class says
`ubnt` are sent that option, so the address stays invisible to everyone
else on the client network.

Omada access points learn `omada_controllers4` from DHCPv4 option 138,
the CAPWAP access controller list of RFC 5417, which takes more than one
address. Nothing identifies an Omada access point before it is adopted,
so this one is handed to every client that asks for option 138.

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
