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
