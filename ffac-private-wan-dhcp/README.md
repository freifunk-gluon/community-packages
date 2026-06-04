# ffac-private-wan-dhcp

Allows devices connected to a private WAN WiFi (terminating an LTE/DSL uplink) to
use that uplink directly instead of being offloaded into the Freifunk mesh.

On `ifup` of the cellular uplink (`cellular` / `cellular_4`) it:

* switches the `wan` interface to a static IPv4 net and runs a DHCP server on it
  (range, lease, DNS configurable via `/etc/config/private-wan-dhcp`),
* sets up firewall rules + NAT (`wan` → `wwan`) so IPv4 clients reach the internet,
* requests a `/64` on the cellular interface, derives the current global IPv6 /64
  from `wwan0` and advertises it to the private WAN clients via **uradvd** on `br-wan`,
* **adds an IPv6 policy-routing rule** (`network.lte_clients`, a `rule6`) that sends
  traffic from that /64 into the LTE routing table (lookup `1`, priority `9999`).
  Without it the clients' IPv6 traffic falls back to the `main` table, whose
  default route points at Freifunk — so they would get an address but no internet.

The IPv6 rule is recreated with the *current* prefix on every uplink `ifup`, so it
survives provider prefix changes automatically. On `ifdown` all of the above
(including the rule) is reverted.

## Config options (`/etc/config/private-wan-dhcp`)

* `enabled` — master switch (`0`/`1`)
* `ipaddr` / `netmask` — advertised private WAN IPv4 network
* `dns_server` — IPv4 DNS advertised via dnsmasq
* `uradvd_dns_server` — IPv6 DNS advertised via uradvd (list)

> Why NAT-free routing works for IPv6: the cellular uplink (`wwan0`) is a
> point-to-point link and the mobile network routes the whole /64 to the device
> (3GPP / RFC 7278). The /64 can therefore be handed to clients and routed
> directly — no NAT66 or NDP proxy required.
