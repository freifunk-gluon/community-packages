# ffac-wg-registration

You can use this package to publish the wg publickey to the server.

You should use something like the following in the site.conf:

	
```
 mesh_vpn = {
	enabled = true,
	wireguard = {
		broker = 'wg-broker.freifunk-aachen.de/api/add_key',
		peers = {
			{
				public_key ='N9uF5Gg1B5AqWrE9IuvDgzmQePhqhb8Em/HrRpAdnlY=',
				endpoint ='01.wg-node.freifunk-aachen.de:51819',
			},
			{
				public_key ='liatbdT62FbPiDPHKBqXVzrEo6hc5oO5tmEKDMhMTlU=',
				endpoint ='01.wg-node.freifunk-aachen.de:51820',
			},
		},
		mtu = 1400,
	},
	
```
And you should include the package in the site.mk of course!

### Dependencies

This relies on a broker which accepts post requests like `{'node_name': 'name', 'public_key': 'my_wg_pubkey'}`.
The broker programms the gateway to accept the WireGuard key which is transmitted during connection.

An example broker can be found here: https://gist.github.com/maurerle/2e4a434a882f524d1304bd82c7307984