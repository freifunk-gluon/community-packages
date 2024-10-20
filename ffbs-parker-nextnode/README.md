ffbs-parker-nextnode
====================

This is a package of [gluon-parker](https://github.com/ffbs/gluon-parker),
a Gluon fork that uses routing between the nodes
(aka. Router devices) and the infrastructure.
It is currently in use at Freifunk Braunschweig.
Other communities are interested in adopting it as well.

This package provides `ebtables`-rules that redirect traffic to the
`localnode` IPs on the node itself.

This is needed in networks where the `localnode` addresses are outside the client network - for example when 
using with `parker`.

In Freifunk Braunschweig, for example, the `localnode` address is `2001:bf7:382:0::1`.
But the IP addresses of routers and clients are in `2001:bf7:381::`.
With this rule traffic to the `localnode` address is always forwarded to the router.

(The service on the router should redirect the client to one of routers public addresses - otherwise the TCP connection
would break when the client roams to another node with the same redirect.)

site.conf
---------

Your `site.conf` probably already contains a `next_node` section, as
requested by the [documentation](https://gluon.readthedocs.io/en/latest/user/site.html).

For Freifunk Braunschweig this section look like this:

```json
next_node = {
        ip4 = "172.16.127.1",
        ip6 = "2001:bf7:382:0::1",
        name = { "node.ffbs" },
        mac = "72:02:46:6a:1c:27",
},
```
