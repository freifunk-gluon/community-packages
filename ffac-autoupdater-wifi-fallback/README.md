# ffac-autoupdater-wifi-fallback

If a node has no connection to the mesh, neither via wlan-mesh nor via
mesh-vpn, it ist not possible to update this node via `autoupdater`. Therefor
the *wifi-fallback* was developed. It checks hourly whether the node is part of
a fully operative mesh or not. Else the node connects to a visible "Freifunknetz"
and tries downloads an update as wlan-client via executing `autoupdater -f`.

This is compatible with gluon/openwrt versions >= v2022.x

## /etc/config/autoupdater-wifi-fallback

**autoupdater-wifi-fallback.settings.enabled:**
- `0` disables the fallback mode
- `1` enables the fallback mode

### example
```
config autoupdater-wifi-fallback 'settings'
	option enabled '1'
```

## Credits

This includes gluon-state-check from tecff to be mesh protocol independent.
As well as using upstream wpa-supplicant-mini to support new version.
It was formerly created by ffho as `ffho-autoupdater-wifi-fallback`
