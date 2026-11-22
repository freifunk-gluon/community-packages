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

This package uses the following parameters in your `site.conf`:

```lua
ntp_servers = { "ntp.yourcommunity.net" },

parker = {
        config_server = "config.yourcommunity.net",
        config_pubkey = "<Your usign config signing pubkey>",
        disable_client_snooping = false,
},

mesh_vpn = {
        parker = {
                mtu = 1406,
        },
},
```

* `ntp_servers` (required, list of strings):
  The node sends the first entry of this list to its clients in DHCP
  option 42.
* `parker.config_server` (required, string):
  This is the host name of the config service from which `nodeconfig`
  downloads the node configuration.
* `parker.config_pubkey` (required, string):
  This is the usign public key with which `nodeconfig` checks the
  signature of the node configuration.
* `parker.disable_client_snooping` (optional, boolean, default `false`):
  If this is `true`, the node switches off multicast snooping and the
  multicast querier on `br-client`.
  [docs/client-multicast-snooping.md](docs/client-multicast-snooping.md)
  explains when to use this option and what it changes.
* `mesh_vpn.parker.mtu` (required, number):
  Gluon sets this MTU on the `mesh_vpn` interface, whereas the WireGuard
  tunnels take their MTU from the config service as described in
  [docs/mtu.md](docs/mtu.md).
  Gluon selects parker as the mesh VPN provider if the `mesh_vpn.parker`
  table exists.
