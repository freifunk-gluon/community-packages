# ffmuc-mesh-vpn-wireguard-vxlan

This package adds support for WireGuard+VXLAN as Mesh VPN protocol stack as it is used in the Freifunk Munich network.

### Dependencies

This relies on [wgkex](https://github.com/freifunkMUC/wgkex), the FFMUC WireGuard key exchange broker running on the configured broker address. The broker programms the gateway to accept the WireGuard key which is transmitted during connection.
Starting with the key exchange API v2, the wgkex broker also returns WireGuard peer data for a gateway selected by the broker, which this package then configures as mesh VPN peer/endpoint. This can be enabled by setting the `loadbalancing` option accordingly.

For the health-checks a webserver of some kind needs to listen to `HTTP GET` requests on the gateways.

### How it works

When `checkuplink` gets called (which happens every minute via cronjob), it checks if the gateway connection is still alive by calling `wget` and connecting to the WireGuard peer link address. If this address replies, we also start a `batctl ping` to the same address. If both checks succeed the connection just stays alive.

If one of the checks above bails out with an error the reconnect cycle is started. This means `checkuplink` registers itself with `wireguard.broker` by sending the WireGuard public key over either HTTP or HTTPS (depending on the device support).
The broker responds with JSON data containing the gateway peer data (pubkey, address, port, allowed IPs aka link address). `checkuplink` adds the peer to the wg interface using this data, and sets up the VXLAN interface with the peer link address as remote endpoint.

This script prefers to establish connections over IPv6 and falls back to IPv4 **only if there is no IPv6 default route**.

### Configuration

You should use something like the following in the site.conf:

```lua
 mesh_vpn = {
	wireguard = {
		enabled = true,
		iface = 'wg_mesh_vpn', -- not 'mesh-vpn', this is used for the VXLAN interface
		mtu = 1406,
		broker = 'broker.ffmuc.net', -- base path of broker, will be combined with API path

		-- loadbalancing controls whether the client can enable the loadbalancing/gateway assignment feature of the broker
		-- on: the client will always use loadbalancing
		-- off: the client cannot enable loadbalancing
		-- on-by-default: the client can enable/disable loadbalancing and will use loadbalancing by default
		-- off-by-default: the client can enable/disable loadbalancing and will not use loadbalancing by default
		loadbalancing = 'on-by-default', -- optional

		peers = { -- not needed if loadbalancing = 'on'
			{
				publickey = 'TszFS3oFRdhsJP3K0VOlklGMGYZy+oFCtlaghXJqW2g=',
				endpoint = 'gw04.ext.ffmuc.net:40011',
				link_address = 'fe80::27c:16ff:fec0:6c74',
			},
			{
				publickey = 'igyqOmWiz4EZxPG8ZzU537MnHhaqlwfa7HarB3KmnEg=',
				endpoint = 'gw05.ext.ffmuc.net:40011',
				link_address = 'fe80::281:8eff:fef0:73aa',
			},
		},
	},
```

And you should include the package in the site.mk of course!

### Interesting Links

- [FFMUC: Half a year with WireGuard](https://www.slideshare.net/AnnikaWickert/ffmuc-half-a-year-with-wireguard)
- [FFMUC: WireGuard Firmware (German)](https://ffmuc.net/freifunkmuc/2020/12/03/wireguard-firmware/)
- [FFMUC: Statistics](https://stats.ffmuc.net)

### Contact

Feel free to ask questions in the [FFMUC chat](https://chat.ffmuc.net).
