# ffac-mesh-vpn-wireguard-openwrt19

You can use this package for connecting with wireguard to a upstream gluon-mesh-vpn-wireguard compatible network.
When upgrading to the upstream version of mesh-vpn-wireguard, the same wireguard privatekey is used.

A special thanks to Annika Wickert @awlx who first developed ffmuc-mesh-vpn-wireguard-vxlan

This version is compatible with Gluon v2021.1.x and later, but it is highly advertised to use gluon-mesh-vpn-wireguard on v2022.1.x and later.

You should use something like the following in the site.conf:

**Note that the peers are not named in contrast to the upstream package version**
	
```
 mesh_vpn = {
	mtu = 1400,
	wireguard = {
		enabled = '1',
		iface = 'mesh-vpn',
		broker = 'wg-broker.freifunk-aachen.de/api/add_key',
		peers = {
				{
					public_key ='N9uF5Gg1B5AqWrE9IuvDgzmQePhqhb8Em/HrRpAdnlY=',
					endpoint ='ffkwsn01.freifunk-koenigswinter.de:30020',
					link_address = 'fe80::f000:22ff:fe12:01',
				},
				{
					public_key ='liatbdT62FbPiDPHKBqXVzrEo6hc5oO5tmEKDMhMTlU=',
					endpoint ='ffkwsn02.freifunk-koenigswinter.de:30020',
					link_address = 'fe80::f000:22ff:fe12:02',
				},
				{
					public_key ='xakSGG39D1v90j3Z9eVWzojh6nDbnsVUc/RByVdcKB0=',
					endpoint ='ffkwsn03.freifunk-koenigswinter.de:30020',
					link_address = 'fe80::f000:22ff:fe12:07',
				},

			},
	},
	
```

And you should include the package in the site.mk of course!

### Dependencies

This relies on a broker which accepts post requests like `{'node_name': 'name', 'public_key': 'my_wg_pubkey'}`.
The broker adds the publickey to the WireGuard supernodes so that they accept the WireGuard key which is transmitted during connection.

### How it works

When `checkuplink` gets called (which happens every minute via cronjob), it checks if the gateway connection is still alive by calling `wget` and connecting to `wireguard.peer.peer_[number].link_address`. If this address replies we also start a `batctl ping` to the same address. If both checks succeed the connection just stays alive.

If one of the checks above bails out with an error the reconnect cycle is started. Which means `checkuplink` registers itself with `wireguard.broker` by sending the WireGuard public_key over either http or https (depending on the device support). After the key was sent the script tries to randomely connect to one of the `wireguard.peer`. This script prefers to establish connections over IPv6 and falls back to IPv4 only if there is no IPv6 default route.

### Interesting Links

- [FFAC Broker](https://github.com/ffac/ff-supernode/blob/main/playbooks/roles/ff.wgbroker/templates/broker.py)
- [FFMUC: Half a year with WireGuard](https://www.slideshare.net/AnnikaWickert/ffmuc-half-a-year-with-wireguard)
- [FFMUC: WireGuard Firmware (German)](https://ffmuc.net/freifunkmuc/2020/12/03/wireguard-firmware/)
- [FFMUC: Statistics](https://stats.ffmuc.net)

### Upstream

This package is compatible with the upstream support for wireguard added in Gluon.
In contrast to FFMUC it uses:

- udp6zerocsumtx and udp6zerocsumrx
- 4789
- different domain_seed_bytes calculation
- public_key instead of publickey in site
