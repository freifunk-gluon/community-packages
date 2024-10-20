ffbs-parker-nodeconfig
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
},
```
