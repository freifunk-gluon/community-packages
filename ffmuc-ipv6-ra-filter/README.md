# ffmuc-ipv6-ra-filter

The package disables forwarding router advertisements on `bat0` which were sent from a different source than the connected gateway. This is based on the output of `batctl gwl` and sets the IPv6 gateway to the IPv4 gateway.

It makes sure that clients only learn the IPv6 gateway of the gateway it is connected to and does not receive other router advertisements in the mesh.

A node which is a gateway itself (`batctl gw_mode` reports `server`) never selects a gateway and therefore has nothing to filter for. On such a node the filter does not apply and returns to the `FORWARD` chain, which leaves the router advertisements to whatever configures the node as gateway.

### Credits

This is based on the FFMUC package [ffmuc-simple-radv-filter](https://github.com/freifunkMUC/gluon-packages/tree/7c2e1224c0cfc1e66f93738aefbcd401bfb11f2c/ffmuc-simple-radv-filter).

### Contact

Feel free to ask questions in the [FFMUC chat](https://chat.ffmuc.net).
