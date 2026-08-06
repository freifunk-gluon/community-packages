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
