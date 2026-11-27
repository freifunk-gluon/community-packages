Router advertisements
=====================

`gluon-radvd` runs `uradvd` with the arguments from
`/lib/gluon/radvd/arguments`, which this package installs. The
node is the default router of its clients, so `uradvd` on `br-client`
announces the range of the node together with the RDNSS address, the NAT64
prefix (if there is one) and the MTU of the tunnels, followed by the site's
`prefix6` as an on-link prefix. `noderoute.lua` writes `/tmp/range6`,
`/tmp/addr6` and `/tmp/adv_mtu` for this and restarts `gluon-radvd`.
Unlike `gluon-mesh-batman-adv-15`, this package does not drop router
advertisements sent to `bat0` or router solicitations received from it, so
nodes meshed behind a routing node get their default route from it.

Without `/tmp/range6` (no tunnel, the node only meshes) `uradvd` runs on
`local-node` and announces the site's `prefix6` as in a classic Gluon mesh,
never as a default router (lifetime 0). These advertisements stay on the
node: the next-node rules of `gluon-mesh-batman-adv-common` drop all traffic
from `local-node` towards `bat0`. Clients get their default route from the
advertisements of other nodes, which `gluon-radv-filterd` passes on. A
site without `prefix6` gets no `uradvd` in this mode: the script exits with
an error.

A routing node does not receive its own advertisement, so `noderoute.lua`
also gives `br-client` the address that SLAAC would derive from `prefix6`
and the MAC of `br-client` (as a `/64`, next to the address of its range).
`gluon-status-page` redirects a visit of the next-node address only to a
node address inside `prefix6`, and the node has such an address in both
modes: a mesh-only node takes it by SLAAC from the advertisements it
receives.

Both modes rely on the next-node address lying inside `prefix6`, which the
clients then resolve on their own segment. A site whose next-node address is
outside of it, or which sets `next_node.ip4`, adds `ffbs-parker-nextnode` to
its packages: its dnat rule makes the node answer these addresses although
clients send them to their router.

`uradvd` marks every prefix it announces for SLAAC, so clients also take an
address from `prefix6`. With a unique local prefix this is harmless: address
selection (RFC 6724) never uses it as source for a global destination. A
global `prefix6` would be used for internet traffic, but only the range of
a node is routed back to it. `check_site.lua` therefore requires `prefix6`
to be a unique local prefix (fc00::/7).

Gluon requirements
------------------

This package needs a Gluon that ships `gluon-mesh-batman-adv-common`
separately from `gluon-mesh-batman-adv-15`.

This package also installs the empty file
`/lib/gluon/features/radv-filterd-redirect`. A Gluon with the opt-in redirect
of `gluon-radv-filterd` then redirects IPv6 packets to the router that owns
the source prefix, as several routers with their own prefixes share one
mesh. The forks, where the redirect is always on, do not use this package.

The Gluon forks that carry the parker arguments in `gluon-mesh-batman-adv`
(`ffbs/gluon-parker`, FreifunkMUC) do not use this package: they keep
`mesh-batman-adv-15` together with `ffbs-mesh-vpn-parker`, and their own
script reads the same runtime files.

Lifetimes
---------

The router lifetime, the interval of the advertisements and the lifetimes of
the prefix come from `site.conf`:

```lua
radvd = {
        default_lifetime = 180,
        min_interval = 20,
        max_interval = 50,
        preferred_lifetime = 120,
        valid_lifetime = 180,
},
```

These are also the values the script falls back to if an option is missing.
The script reads the options itself, so they need nothing from Gluon;
`check_site.lua` of this package checks them at build time against the limits
`uradvd` enforces (RFC 4861), taking the fallbacks into account: all three
values are integers, `min_interval` is at most 0.75 times `max_interval`,
and `default_lifetime` is 0 or at least `max_interval`.
They belong together: the router lifetime equals the valid lifetime, and the
advertisements come often enough for at least three of them to fall into one
lifetime. Every node announces its own prefix, so a client that roams to
another node has to drop the old prefix and router quickly.
