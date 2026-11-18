# ff3l-eol-ssid-disable

This package changes the 2.4GHz SSID and optionally disables WiFi AP on a configured date. It is used to show a deprecation warning in the SSID name for unsupported targets (end-of-life).
It was created to deprecate devices with 4MB and 32MB RAM.

However it can be used for various deprecation processes of old versions.
For example the soon to come deprecation of devices with 8MB Flash.

One should update all supported devices to the new gluon version, so that only devices without an update are left at the old version.
Then one can add the `ffac-eol-ssid-disable` package to the old version and leave a much noticed note in the ssid to switch to a supported device.

Optionally one can set a date where the client wifi is swichted off.

**_Note:_**
_This is very similar as `ffac-eol-ssid` but with the extended features for setting a date for ssid change and switch off client wifi._


## Site Configuration

```lua
eol_ssid = {
    enabled = true,
    ssid = 'erneuern.freifunk.net',-- EOL SSID for the SSID change
    date_ssid = '2026-12-31',      -- Date when SSID changes (required)
    date_wifi_off = '2027-12-31',  -- Date when WiFi AP is disabled (optional, must be >= date_ssid)
}
```

From `date_ssid` the SSID is changed, from `date_wifi_off` the client wifi is additionally switched off (mesh stays active).
Dates are only evaluated once NTP is synchronized. See [DETAILS.md](DETAILS.md) for how it works and is triggered.


# Implement this package in your firmware

Edit the `modules` file with the following content in your site directory:

    GLUON_SITE_FEEDS="community"
    PACKAGES_SSIDCHANGER_REPO=https://github.com/freifunk-gluon/community-packages.git
    PACKAGES_SSIDCHANGER_COMMIT=<COMMIT_HASH> # <-- set the newest commit here
    PACKAGES_SSIDCHANGER_BRANCH=v2023.2.x

With this done you can add the package `ff3l-eol-ssid-disable` to your `GLUON_SITE_PACKAGES` in your `site.mk`


## Upgrading

This package will migrate uci settings for previous versions of it.

## Limitations

As this package was created to migrate older devices, it does not respect 5GHz or OWE radio.

DO NOT use this package and `ffac-eol-ssid` at the same time.

## Credits

This is based on `ffac-eol-ssid` which ich based on the hard-coded packages from FFMUC and FFKA

- https://github.com/freifunk-gluon/community-packages/tree/main/ffac-eol-ssid
- https://github.com/freifunkMUC/gluon-packages/tree/main/ffmuc-eol-ssid/
- https://gitlab.karlsruhe.freifunk.net/firmware/packages/-/blob/master/ffka-eol-ssid/
