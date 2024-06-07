# ffmuc-custom banner

This package modifies the /etc/banner that is shown during SSH login.

The custom banner template is located [here](files/etc/banner.gluon).

⚠️ This package will consume an additional 2x the banner size, one for the template and one for the final banner. Make sure to have enough flash size available.


### Configuration

The custom banner can optionally also be configured in the site.conf:

```lua
custom_banner = {
    enabled     = true,                         -- optional (enabled by default)
    map_url     = 'https://map.ffmuc.net/#!/',  -- optional (skipped by default)
    contact_url = 'https://ffmuc.net/kontakt/', -- optional (skipped by default)
},
```

The custom banner can also be disabled per-node:

```
uci set custom-banner.settings.enabled='0'
```
