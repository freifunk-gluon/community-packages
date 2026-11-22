Multicast snooping on br-client
===============================

The optional `site.conf` key `parker.disable_client_snooping` switches off
multicast snooping and the multicast querier on `br-client`:

```lua
parker = {
        -- ...
        disable_client_snooping = true,
},
```

The default is `false`. Then the node keeps the Gluon defaults, and
snooping and the querier stay on. The upgrade script
`902-parker-client-no-snooping` applies the option.

When to use it
--------------

Use this option when clients lose IPv6. With snooping, the bridge sends the
neighbour solicitation (NS) for a client address only to the ports that
have an entry for the solicited-node group of that address. Some clients
(seen with iPhones) have no entry on their port, so they do not get the NS.
Their address then stays INCOMPLETE on the node, and the client loses IPv6.

Effects
-------

* The bridge sends each multicast packet to all ports of `br-client`.
* batman-adv marks the node as not able to snoop, so the other nodes send
    all multicast to this node.
* The additional multicast stays in the local mesh, because a parker node
    has no VPN mesh.
