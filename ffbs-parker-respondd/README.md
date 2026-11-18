ffbs-parker-respondd
====================

This is a package of [gluon-parker](https://github.com/ffbs/gluon-parker),
a Gluon fork that uses routing between the nodes
(aka. Router devices) and the infrastructure.
It is currently in use at Freifunk Braunschweig.
Other communities are interested in adopting it as well.

This module extends `respondd`'s `statistics` object with the following
info, as long as the node routes for its clients itself, that is: as long
as it has a default route over one of its own `wg_*` tunnels.

* `gateway6`: IPv6 gateway of the default route over the tunnel.
* `gateway_nexthop`: The name of the tunnel that default route uses.
* `gateway`: IPv4 gateway of the default route over the tunnel - only
  present as long as there is one.

The IPv6 default route is the one that describes how the node is connected:
a node running 464XLAT translates the clients' IPv4 traffic to IPv6 before
it enters the tunnel, so IPv4 does not have to be routed over the tunnel at
all.

For a node, that itself has a wireguard connection this can look like this:
(Other information removed for readability.)
```shell
root@hostname:~# gluon-neighbour-info -r statistics
{
  "gateway": "10.0.0.3",
  "gateway6": "2001:bf7:381::1",
  "gateway_nexthop": "wg_c3",
  (...)
}
```

In multi-site operation (see ffbs-mesh-vpn-parker), the default routes
have no gateway address. Then `parker-sites` writes the fields to
`/tmp/parker-sites/respondd.json`, and this module sends that file:

* `gateway`: the name of the pgw and the site of the active site, for
  example `pgw01 (muc)`.
* `gateway6` and `gateway_nexthop`: the pgw and the tunnel of the active
  site.
* `mesh_vpn`: one group for each site with its pgw, in the format of
  gluon-mesh-vpn-fastd. `established` is the time in seconds since the
  site is up. `method` is `active`, `standby` or `down`. The status page
  shows this in the "Mesh VPN" section.

Traffic
-------

The clients of a parker node use the `wg_*` tunnels, not `bat0`. When the
node has a `wg_*` tunnel, this module sets `traffic.rx` and `traffic.tx`
(`packets`, `bytes`, `dropped`) to the sum of the counters of all `wg_*`
tunnels. `traffic.forward`, `traffic.mgmt_rx` and `traffic.mgmt_tx` stay
as gluon-mesh-batman-adv sends them for the batman-adv mesh to other
nodes.

respondd merges its modules in the order of the file names. For the same
key, the last module wins. Thus this package installs its module as
`zz-ffbs-parker-respondd.so`, after `gluon-mesh-batman-adv.so` and
`gluon-radv-filterd.so`.

For a node that does not have a WireGuard connection (and is thus using another node
as gateway) this module reports nothing. The same fields are filled in by
`gluon-mesh-batman-adv` (`gateway`, `gateway_nexthop`) and the router
advertisement filter (`gateway6`) instead, which describe the selected
batman-adv gateway by its MAC addresses:

```shell
root@anotherhostname:~# gluon-neighbour-info -r statistics
{
  "gateway": "8e:fd:c1:15:46:3b",
  "gateway_nexthop": "86:7b:fe:68:65:15",
  "gateway6": "2c:3a:fd:1b:fe:71",
  (...)
}
```

Usage with Meshviewer
---------------------

Meshviewer, our trusty Freiunk Network Map, can consume and display these fields.

* For a meshing node we replicate the behavior of *fastd*-based networks:
  Meshviewer will resolve the MAC-addresses into the corresponding names and
  display those.
* For a node with uplink Meshviewer will fail to parse the MAC-addresses and
  fall back to display the strings instead.
  This means that we can use a stock Meshviewer without customizations.
