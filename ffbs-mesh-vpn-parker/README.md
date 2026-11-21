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

DHCPv4 after a gateway change
-----------------------------

The node gives leases of 3 minutes to its clients.
A client renews its lease per unicast at the node that gave it, after half of the lease time.

A client of a routing node can still have a lease of another node, for example from the time when its node did not route.
The renewal goes through the mesh to the other node, so the other node stays the IPv4 router of the client as long as it answers.
When the other node does not answer (it has stopped routing, or it is off), the client sends its request as a broadcast after 87.5 % of the lease time.
batman-adv does not send a DHCP request of a client into the mesh while the node is a gateway server, so only the node of the client receives the broadcast.

dnsmasq is authoritative, as OpenWrt sets it.
`dhcp_authoritative = false` in the `parker` section of `site.conf` switches this off (`/lib/gluon/upgrade/905-dhcp-not-authoritative`).
This option is for sites where all nodes get the same `range4`, so the address of the client is in the client network of its node.
There, an authoritative dnsmasq answers the broadcast with a DHCPACK for the same address, but with the router address of this node.
Some clients (Android 11) then lose their IPv4 default route until they connect again.
A non-authoritative dnsmasq does not answer a broadcast request (rebinding or INIT-REBOOT) for a lease that it does not know.
It answers a unicast renewal of such a lease with a DHCPNAK.
At the end of the lease, the client sends a DHCPDISCOVER and gets a new lease from its own node, at most 3 minutes after the other node stops answering.

A site where each node has its own `range4` keeps the default.
With `false`, its nodes no longer send these answers:

* the DHCPNAK ("wrong network") to a rebinding request for an address of another node,
* the DHCPNAK ("wrong network") to an INIT-REBOOT request for an address of another node,
* the DHCPACK to an INIT-REBOOT request for an address of its own range after a reboot of the node, which loses the lease file in `/tmp`.

The client then waits for a timeout before it sends a DHCPDISCOVER.
`tests/dhcp-authoritative-test.sh` (in the package directory) tests the answers of dnsmasq with and without authoritative (see the script for the command).
`lua5.1 tests/dhcp-authoritative-upgrade-test.lua` tests the upgrade script with mock modules.

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

464XLAT
-------

The 464XLAT mode is on while the config service answers with
`xlat_range6`. A node whose config has no `xlat_range6` runs none of
this. In this mode, nodeconfig configures the tunnels with allowed-ips
`::/0` only. While the node routes for its clients, noderoute also:

* writes the prefix to `/tmp/xlat_range6` and runs
  `/etc/init.d/ebpf-clat start`,
* announces DHCPv4 option 108, IPv6-Only Preferred (RFC 8925),
* writes the NAT64 prefix `64:ff9b::/96` to `/tmp/pref64`,
* subtracts 28 bytes from DHCP option 26 and puts the result on the
  IPv4 default route as its MTU, see the section "MTU".

The mode needs two things outside this package:

* The package `ffmuc-ebpf-clat`, which provides `/etc/init.d/ebpf-clat`.
  This package does not depend on it.
* A Gluon whose radvd arguments pass `/tmp/pref64` to uradvd, as the
  Gluon change "gluon-mesh-batman-adv: announce the NAT64 prefix in
  router advertisements" does. `/tmp/adv_mtu` of the section "MTU"
  needs the same kind of change.

With `xlat_range6` in the config but without `ffmuc-ebpf-clat` in the
firmware, the tunnels allow only IPv6, the clients get option 108, and
the start of `/etc/init.d/ebpf-clat` fails. Nothing translates the IPv4
traffic of the clients then.

MTU
---

Everything our clients send leaves the node through a WireGuard tunnel,
so how big their packets may be is decided by what is left of the WAN
MTU once WireGuard, and with 464XLAT the CLAT as well, have taken their
share.

`nodeconfig.sh` reports the MTU the WAN device uses for IPv6 to the config
service, which answers with the MTU of the tunnels in `mtu`.
`nodeconfig.lua` puts it on every tunnel, and `noderoute.lua` passes it
on to the clients:

    wg MTU  = conf.mtu
    RA MTU  = the smallest wg MTU of the tunnels with a live handshake
    DHCP 26 = RA MTU - 28             while the CLAT translates for us
            = RA MTU                  when it does not
    MSS     = RA MTU - 60             for TCP over IPv6
            = DHCP 26 - 40            for TCP over IPv4

The 28 bytes the CLAT costs are the 20 between the IPv4 header it takes
off and the IPv6 header it puts on, plus the 8 bytes of the fragment
header RFC 7915 asks a translator to add to an IPv4 fragment. The kernel
fragments IPv4 packets without DF at the MTU of the route, which is
DHCP 26. ebpf-clat translates each TCP or UDP fragment to an IPv6
fragment that fits into the wg MTU. Fragmented ICMP is dropped (RFC 7915
section 1.3), so an IPv4 ping bigger than DHCP 26 gets no answer.

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
route a packet takes. That clamp runs before the CLAT, which is attached
to the tc egress hook of the wg-interface, and it therefore sees the
untranslated IPv4 packet. The 28 bytes reach it because noderoute puts
them on the IPv4 default route rather than on the interface, which also
carries the IPv6 packets that the CLAT does not translate.

site.conf
---------

This package relies on the following parameters in your `site.conf`:

```json
parker = {
        config_server = "config.yourcommunity.net",
        config_pubkey = "<Your usign config signing pubkey>",

        -- optional
        client_ntp_servers4 = { "198.51.100.123" },
        disable_client_snooping = false,
        dhcp_authoritative = true,
},
```

`client_ntp_servers4` lists the NTP servers announced to clients via
DHCPv4 option 42. That option carries IPv4 addresses only, so hostnames
and IPv6 addresses cannot be used here — unlike in `ntp_servers`, which
configures the node's own clock.

When it is unset or empty, the first entry of `ntp_servers` is passed on
to clients as it is. This entry then has to be an IPv4 address, because
dnsmasq does not start with a hostname or an IPv6 address in option 42.

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
