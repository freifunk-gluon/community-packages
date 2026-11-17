Module order
============

respondd merges the output of its modules in the order of their file names.
For the same key, the last module wins. This package installs its module as
`zz-ffbs-parker-respondd.so`, so it comes after `gluon-mesh-batman-adv.so`
and `gluon-radv-filterd.so`. Thus its values replace theirs for these keys
of `statistics`:

* `gateway`, `gateway6` and `gateway_nexthop`, when the default route goes
    through a `wg_*` tunnel.
* `traffic.rx` and `traffic.tx`, when the node has a `wg_*` tunnel. They
    are the sums of the counters of all `wg_*` tunnels, because the clients
    of a parker node use the tunnels, not `bat0`.

`traffic.forward`, `traffic.mgmt_rx` and `traffic.mgmt_tx` stay as
gluon-mesh-batman-adv sends them for the batman-adv mesh to other nodes.
