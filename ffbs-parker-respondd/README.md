ffbs-parker-respondd
====================

This is a package of [gluon-parker](https://github.com/ffbs/gluon-parker),
a Gluon fork that uses routing between the nodes
(aka. Router devices) and the infrastructure.
It is currently in use at Freifunk Braunschweig.
Other communities are interested in adopting it as well.

This module extends `respondd`'s `statistics` object with the following
info:

* `gateway`: IPv4 default gateway for the client net - if set.
* `gateway6`: IPv6 default gateway for the client net - if set.
* `gateway_nexthop`: The name of the currently selected gateway - if set.

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

For a node that does not have a WireGuard connection (and is thus using another node
as gateway) this may look like this:

```shell
root@anotherhostname:~# gluon-neighbour-info -r statistics
{
  "gateway": "8e:fd:c1:15:46:3b",
  "gateway_nexthop": "86:7b:fe:68:65:15",
  "gateway6": "2c:3a:fd:1b:fe:71",
  (...)
}
```

Clients
-------

gluon-mesh-batman-adv sets `clients.total` to the number of clients in
the local translation table of `bat0`. A routing node is the router of
its clients. Their frames stay in `br-client` and do not go into `bat0`.
Thus `clients.total` is 0 or too low.

While the node routes for its clients (`network.client.proto` is
`static`), this module sets `clients.total` to the number of unique MACs
of:

* the bridge FDB of `br-client`: learned entries on all ports except
  `bat0` and `local-port`, with a frame in the last 60 seconds,
* the stations of the client access points with activity in the last
  60 seconds (a sleeping station sends no frames to the bridge).

The clients of other nodes come in through `bat0`. They do not count.
The count does not use ARP, the neighbour table or the DHCP leases: these
contain the clients of other nodes that use this node as router, and
they do not contain IPv6-only (CLAT) clients.

A mesh-only node keeps the value of gluon-mesh-batman-adv. This module
does not change `clients.wifi*` and `clients.owe*` (gluon-respondd).
Meshviewer (yanic) shows `total - wifi` as other (LAN) clients.

`tests/run.sh` tests the FDB filter on a Linux host.

respondd merges its modules in the order of the file names. For the same
key, the last module wins. Thus this package installs its module as
`zz-ffbs-parker-respondd.so`, after `gluon-mesh-batman-adv.so` and
`gluon-radv-filterd.so`.

Usage with Meshviewer
---------------------

Meshviewer, our trusty Freiunk Network Map, can consume and display these fields.

* For a meshing node we replicate the behavior of *fastd*-based networks:
  Meshviewer will resolve the MAC-addresses into the corresponding names and
  display those.
* For a node with uplink Meshviewer will fail to parse the MAC-addresses and
  fall back to display the strings instead.
  This means that we can use a stock Meshviewer without customizations.
