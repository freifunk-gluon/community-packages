# ff-mesh-vpn-parker-migrate

This package lets a node go from a firmware with
`ffmuc-mesh-vpn-wireguard-vxlan` to a firmware with
`ffbs-mesh-vpn-parker` with a normal sysupgrade or autoupdater run.
You do not need config mode.

Add the package to the Parker firmware. On the first boot after the
upgrade, it does these steps:

1. It copies the WireGuard private key from `wireguard.mesh_vpn.privatekey`
   to `/etc/parker/wg-privkey`. The node keeps its public key. It does
   this step only if `/etc/parker/wg-privkey` is empty.
2. It removes the `simple-tc.mesh_vpn` section of the old provider.

The package does not remove `/etc/config/wireguard`. If the node goes back
to the old firmware, it uses the same key again.

Gluon keeps all other settings (hostname, location, contact, mesh VPN on
or off, bandwidth limit, wired mesh and domain). Make sure that each old
domain code is a domain code or an alias in the Parker site.
