# ffmuc-mesh-vpn-wireguard-vxlan

You can use this package for connecting with wireguard to the Freifunk Munich network.

You should use something like the following in the site.conf:

	
```
 mesh_vpn = {
	mtu = 1400,
	wireguard = {
		enabled = '1',
		iface = 'mesh-vpn',
		limit = '1', -- actually unused
		broker = 'broker.ffmuc.net/api/v1/wg/key/exchange',
		peers = {
				{
					publickey ='N9uF5Gg1B5AqWrE9IuvDgzmQePhqhb8Em/HrRpAdnlY=',
					endpoint ='ffkwsn01.freifunk-koenigswinter.de:30020',
					link_address = 'fe80::f000:22ff:fe12:01',
				},
				{
					publickey ='liatbdT62FbPiDPHKBqXVzrEo6hc5oO5tmEKDMhMTlU=',
					endpoint ='ffkwsn02.freifunk-koenigswinter.de:30020',
					link_address = 'fe80::f000:22ff:fe12:02',
				},
				{
					publickey ='xakSGG39D1v90j3Z9eVWzojh6nDbnsVUc/RByVdcKB0=',
					endpoint ='ffkwsn03.freifunk-koenigswinter.de:30020',
					link_address = 'fe80::f000:22ff:fe12:07',
				},

			},
	},
	
```
And you should include the package in the site.mk of course!

### Dependencies

This relies on [wgkex](https://github.com/freifunkMUC/wgkex) the FFMUC wireguard broker running on the configured broker address. The broker programms the gateway to accept the WireGuard key which is transmitted during connection.

For the health-checks a webserver of some kind needs to listen to `HTTP GET` requests on the gateways.

### How it works

When `checkuplink` gets called (which happens every minute via cronjob), it checks if the gateway connection is still alive by calling `wget` and connecting to `wireguard.peer.peer_[number].link_address`. If this address replies we also start a `batctl ping` to the same address. If both checks succeed the connection just stays alive.

If one of the checks above bails out with an error the reconnect cycle is started. Which means `checkuplink` registers itself with `wireguard.broker` by sending the WireGuard public_key over either http or https (depending on the device support). After the key was sent the script tries to randomely connect to one of the `wireguard.peer`. This script prefers to establish connections over IPv6 and falls back to IPv4 only if there is no IPv6 default route.

### Interesting Links

- [FFMUC: Half a year with WireGuard](https://www.slideshare.net/AnnikaWickert/ffmuc-half-a-year-with-wireguard)
- [FFMUC: WireGuard Firmware (German)](https://ffmuc.net/freifunkmuc/2020/12/03/wireguard-firmware/)
- [FFMUC: Statistics](https://stats.ffmuc.net)

### Contact

Feel free to ask questions in the [FFMUC chat](https://chat.ffmuc.net).
