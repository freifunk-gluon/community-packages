# ffgraz-dnsmasq-dhcp-relay

Serve the client network from one DHCP server in the mesh, and relay into it
from every node - the centralised counterpart to [ffgraz-ddhcpd](../ffgraz-ddhcpd/README.md).

Add the package to your `image-customization.lua` and name the server in your
`site.conf`:

    dnsmasq_dhcp_relay = {
      server = '10.12.6.66',
    },

`next_node.ip4` is required, and so is a prefix to derive the node's own
address from (`node_prefix4`, falling back to `prefix4`).

## Why a split relay

IPv4 DHCP uses one address, `giaddr`, for two jobs: the server picks the
network to allocate from by it, and sends its answer there. In a layer 3 mesh
those want to be different addresses.

The only address a node has on the client link is `next_node.ip4`, and every
other node has it too, so an answer sent there comes back to whichever node is
nearest the server. The node's own address routes to this node, but it is not
in the client network, so a server picking a range by it finds none.

dnsmasq's `dhcp-split-relay` splits the two. The node's own address goes into
`giaddr`, so the answer comes back here; `next_node.ip4` travels next to it as
an RFC 3527 link selection, so the server allocates out of the client range,
and as an RFC 5107 server-id override, so renewals come through the node as
well.

## The server

Anything that understands the link selection sub-option will do. dnsmasq needs
the range spelled out with its netmask - it is not a network the server is on:

    dhcp-range=10.12.244.10,10.12.247.254,255.255.252.0,1h
    dhcp-option=option:router,10.12.244.1
    dhcp-option=option:dns-server,10.12.244.1

Both options have to be given: the defaults are addresses of the server, and a
client cannot reach those. Its own node is its router and its resolver, and it
answers on the next_node address.

For ffgraz this is `hell-vm`, on the mesh identity 10.12.6.66
(`hell-pi/dnsmasq.nix` in funkfeuer-nixos).

## Notes

`dhcp-split-relay` is not one of the options OpenWrt's dnsmasq init script
writes from uci, so it is put in through `extraconftext` on the dnsmasq
section. Nothing else in the image uses that option.

The node's own address is taken from loopback, where gluon-mesh-olsrd puts it
and ffgraz-static-ip overrides it. A node that meshes with babel alone has
neither, so this package derives one the same way instead.

#### turn the relay off on one node:

     ssh <router ip> "uci delete dhcp.\$(uci show dhcp | sed -n 's/^dhcp\.\(@\?[^.]*\)=dnsmasq$/\1/p').extraconftext; uci commit dhcp && /etc/init.d/dnsmasq restart; echo done"

## Testing

`contrib/split-relay-test.sh` builds the three namespaces this relies on - a
node, a client behind it and the server - and checks that the client ends up
with a lease out of the central range and its own node as router, resolver and
server-id. Needs root, and takes the two binaries to use:

    sudo ./contrib/split-relay-test.sh dnsmasq dhcpcd
