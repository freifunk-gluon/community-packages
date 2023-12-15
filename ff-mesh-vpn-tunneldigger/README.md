# ff-mesh-vpn-tunneldigger

This package is based on the former core gluon package [gluon-mesh-vpn-tunneldigger](https://github.com/freifunk-gluon/gluon/tree/c2dc338abfbebb34dcf62124dc09be85fa88f8ef/package/gluon-mesh-vpn-tunneldigger).

It you want to keep using tunneldigger you need to take the following steps:

- `modules`: add this repo as described in the [README.md](../README.md#using-this-repository)
- `image-customization.lua`: remove the `mesh-vpn-tunneldigger` feature
- `image-customization.lua`: add the `config-mode-mesh-vpn` feature:  
  `features({'config-mode-mesh-vpn'})`  
  Not needed if you don't use the config mode or don't want to enable configuration of VPN settings via the config mode.
- `image-customization.lua`: add the `ff-mesh-vpn-tunneldigger` package:  
  `packages({'ff-mesh-vpn-tunneldigger'})`
