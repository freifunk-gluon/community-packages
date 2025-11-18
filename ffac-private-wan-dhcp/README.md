# ffac-private-wan-dhcp

This package adds dynamic uci configurations when a cellular or wan interface is made available.
It can be used to activate and configure a DHCP server on devices which terminate an uplink connection.

On cellular devices, activating the private wlan creates an interface in which no gateway is set by default.
For this situation, a dhcp server on br-wan is configured through this package.
