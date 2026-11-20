DHCPv4 after a gateway change
=============================

The optional `site.conf` key `parker.dhcp_authoritative` switches off the
authoritative mode of dnsmasq:

```lua
parker = {
        -- ...
        dhcp_authoritative = false,
},
```

The default is `true`, which keeps the OpenWrt default. The upgrade script
`905-dhcp-not-authoritative` applies the option.

Lease renewal through the mesh
------------------------------

The node gives leases of 3 minutes to its clients. A client renews its
lease per unicast at the node that gave it, after half of the lease time.

A client of a routing node can still have a lease of another node, for
example from the time when its node did not route. The renewal goes
through the mesh to the other node. Thus the other node stays the IPv4
router of the client as long as it answers.

When the other node does not answer (it has stopped routing, or it is
off), the client sends its request as a broadcast after 87.5 % of the
lease time. batman-adv does not send a DHCP request of a client into the
mesh while the node is a gateway server. Thus only the node of the client
receives the broadcast.

Sites with one range4 for all nodes
-----------------------------------

The option is for sites where all nodes get the same `range4`. There, the
address of the client is in the client network of its own node. An
authoritative dnsmasq answers the broadcast with a DHCPACK for the same
address, but with the router address of this node. Some clients
(Android 11) then lose their IPv4 default route until they connect again.

A non-authoritative dnsmasq does not answer a broadcast request
(rebinding or INIT-REBOOT) for a lease that it does not know. It answers a
unicast renewal of such a lease with a DHCPNAK. At the end of the lease,
the client sends a DHCPDISCOVER and gets a new lease from its own node.
This happens at most 3 minutes after the other node stops answering.

Sites with one range4 per node
------------------------------

A site where each node has its own `range4` keeps the default. With
`false`, its nodes no longer send these answers:

* the DHCPNAK ("wrong network") to a rebinding request for an address of
    another node,
* the DHCPNAK ("wrong network") to an INIT-REBOOT request for an address
    of another node,
* the DHCPACK to an INIT-REBOOT request for an address of its own range
    after a reboot of the node, which loses the lease file in `/tmp`.

The client then waits for a timeout before it sends a DHCPDISCOVER.
