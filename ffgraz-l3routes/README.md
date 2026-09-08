# ffgraz-l3routes

Announce extra prefixes into the mesh.

A node announces its own addresses and the site prefixes on its own. This adds
everything else: a range behind one of its interfaces, an address on a tunnel,
or whole kernel routing tables and routing protocols another daemon fills in.

## Declaring something to announce

Drop a Lua file into `/lib/gluon/l3routes/`, the same way `gluon-firewall`
takes rule snippets from `/lib/gluon/nftables/`. Two functions are in scope:

```lua
-- a range this node reaches over one of its interfaces
route({
    cidr      = '10.42.7.0/24',  -- required, host bits are normalised away
    interface = 'lan',           -- required, a network interface, not a device
    metric    = 128,             -- optional
    table     = 'main',          -- optional, the table the route is installed in
    is_local  = false,           -- the prefix is an address the node already has
    firewall  = true,            -- manage a firewall zone for the interface
    comment   = 'downstream',
    source    = 'my-package',
})

-- routes the kernel already has, by table and/or by routing protocol
import({
    table  = 42,                 -- optional
    proto  = 4,                  -- proto number or name
    cidr   = '10.42.0.0/16',     -- optional restriction
    le     = 24,                 -- optional longest prefix, defaults to the family max
    family = 4,                  -- optional
})
```

An import needs at least a `proto` or a `cidr`: an unrestricted filter would
drag the uplink default route into the mesh.

`is_local` is for a prefix the node already carries as an address rather than a
range behind an interface - a tunnel endpoint, a public IP. No kernel route is
installed for it, and the firewall is left alone: the address lives on an
interface that is already reachable, and putting that interface into a
REJECT-input zone would break it.

Packages that keep their announcements in uci can use the module directly:

```lua
local l3routes = require 'gluon.l3routes'
l3routes.add('my-package-downstream', { cidr = '10.42.7.0/24', interface = 'lan' })
l3routes.remove('my-package-downstream')
```

which stores them in `/etc/config/gluon-l3routes`; `100-uci.lua` replays them.
The whole domain can announce something through `site.conf`:

```lua
l3routes = {
    { cidr = '10.42.0.0/16', interface = 'lan' },
},
```

## What happens with them

`850-l3routes` installs a netifd route per range and, for interfaces gluon does
not manage itself, a firewall zone that lets the mesh reach them. The
announcement is done by the protocol packages, last in the upgrade chain:

- `ffgraz-l3routes-babel` writes babeld redistribute filters
- `ffgraz-l3routes-olsr` writes olsr `Hna4` / `Hna6` sections

`ffgraz-web-l3routes` adds a config mode page for operators.

## Testing

`tests/parse.lua` checks the prefix handling; run it on a node, which is where
`luci.ip` lives:

    scp -O tests/parse.lua root@<node>:/tmp/ && ssh root@<node> lua /tmp/parse.lua

`contrib/push.sh <user@node>` copies the packages onto a running node and
reconfigures it. Everything here is interpreted Lua, so that is a full
iteration - no build, no flash.
