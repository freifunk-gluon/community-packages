ffbs-mesh-batman-adv-parker
===========================

batman-adv mesh for [parker](https://github.com/ffbs/gluon-parker) networks.
It takes the place of `gluon-mesh-batman-adv-15` and builds on the same
`gluon-mesh-batman-adv-common`, but announces IPv6 routers differently:

* A node with a tunnel is the default router of its clients. `uradvd`
  announces the node's own range on `br-client`, and these advertisements
  also cross `bat0`, so nodes meshed behind it get their default route
  from it.
* A node without a tunnel announces the site's `prefix6` on `local-node`,
  never as a default router, as in a classic Gluon mesh.

See [docs/router-advertisements.md](docs/router-advertisements.md) for the
details.

The node configuration comes from `ffbs-mesh-vpn-parker`, which this package
depends on.

site.conf
---------

* `prefix6` (a unique local prefix, fc00::/7):
  The nodes announce it to their clients next to their own routed range,
  so it must not be routable; the build fails otherwise.
* `radvd.default_lifetime`, `radvd.min_interval`, `radvd.max_interval`,
  `radvd.preferred_lifetime`, `radvd.valid_lifetime` (optional, numbers):
  These set the lifetimes and the interval of the router advertisements
  of a routing node and are checked at build time, see
  [docs/router-advertisements.md](docs/router-advertisements.md).

Requirements
------------

A Gluon that ships `gluon-mesh-batman-adv-common` separately from
`gluon-mesh-batman-adv-15`.

Usage
-----

In `image-customization.lua`, select the feature `mesh-batman-adv-parker`
instead of `mesh-batman-adv-15`:

```lua
features {
        'mesh-batman-adv-parker',
        'status-page',
        -- ...
}
```

Like `mesh-batman-adv-15`, the feature adds `gluon-ebtables-limit-arp`, and
`gluon-status-page-mesh-batman-adv` together with `status-page`.
