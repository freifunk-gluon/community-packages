DHCP for the clients
====================

`dnsmasq` serves the clients of the node from the section `dhcp.local_client`,
the one `gluon-client-bridge` creates for the client interface with
`ignore=1`.

* While the node routes, `noderoute.lua` sets `ignore=0` and adds the pool.
    The DHCP options of this package (MTU, NTP server) live in the same
    section.
* Without a tunnel, `noderoute.lua` restores `ignore=1` and removes the pool.
* Gluon forks that delete the section in `gluon-client-bridge` keep working:
    `noderoute.lua` and `996-parker-dhcp-ntp-option` create it if it is
    missing.
* Older firmware of this package served the clients from its own section
    `dhcp.client`. `302-parker-legacy-client-dhcp` and `noderoute.lua`
    remove it, because two sections for one interface would both feed
    `dnsmasq`.
