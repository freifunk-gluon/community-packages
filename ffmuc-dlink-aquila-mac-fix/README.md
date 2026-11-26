# ffmuc-dlink-aquila-mac-fix

D-Link AQUILA PRO AI M30 and M60 units from a multi-pack got the same
broken MAC address, for example `06:00:dc:ea:e7:af`. This package deletes
a broken stored primary MAC, so that Gluon reads the factory address
again. The node ID changes, so the node appears as a new node on the map.

The package needs firmware with the fixed device tree. On older firmware
nothing changes.

Add it to the filogic images in `image-customization.lua`:

```lua
if target('mediatek', 'filogic') then
    packages {'ffmuc-dlink-aquila-mac-fix'}
end
```
