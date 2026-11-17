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
