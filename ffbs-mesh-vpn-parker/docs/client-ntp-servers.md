NTP servers for clients
=======================

The optional `site.conf` key `parker.client_ntp_servers4` lists the NTP
servers announced to clients via DHCPv4 option 42:

```lua
parker = {
        -- ...
        client_ntp_servers4 = { "198.51.100.123" },
},
```

Option 42 carries IPv4 addresses only. Hostnames and IPv6 addresses
cannot be used here. This is different from `ntp_servers`, which
configures the clock of the node itself.

When the key is unset or empty, the first entry of `ntp_servers` is passed
on to clients as it is. This entry then has to be an IPv4 address, because
dnsmasq does not start with a hostname or an IPv6 address in option 42.
