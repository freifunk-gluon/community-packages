# ffac-wg-registration

You can use this package to publish the wg publickey to the server.

You should use something like the following in the site.conf:

	
```
 mesh_vpn = {
	mtu = 1400,
	wireguard = {
		broker = '01.wg-test.freifunk-aachen.de:8080',
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
		},
	},
	
```
And you should include the package in the site.mk of course!

### Dependencies

This relies on a broker which accepts post requests like `{'node_name': 'name', 'public_key': 'my_wg_pubkey'}`.
The broker programms the gateway to accept the WireGuard key which is transmitted during connection.

An example broker can be found here: https://gist.github.com/maurerle/2e4a434a882f524d1304bd82c7307984