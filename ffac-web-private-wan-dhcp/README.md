# ffac-web-private-wan-dhcp

This package adds configuration options to the config mode to configure ffac-private-wan-dhcp.
It can be used to activate a DHCP server on devices which terminate an uplink connection.

It allows to set the following:

* enabled
* ipaddr of the advertised WAN network
* netmask of the advertised WAN network
* dns server for IPv4 (advertised with dnsmasq)
* dns server for IPv6 (advertised with uradvd)
