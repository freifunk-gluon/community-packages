# ffac-eol-ssid

This package changes the 2.4GHz SSID. It is used to show a deprecation warning in the SSID name for unsupported targets (end-of-life).
It was created to deprecate devices with 4MB and 32MB RAM.

However it can be used for various deprecation processes of old versions.
For example the soon to come deprecation of devices with 8MB Flash.

One should update all supported devices to the new gluon version, so that only devices without an update are left at the old version.
Then one can add the `ffac-eol-ssid` package to the old version and leave a much noticed note in the ssid to switch to a supported device.


## Site Configuration

```
eol_wifi_ssid = 'erneuern.freifunk.net'
```

## Limitations

As this package was created to migrate older devices, it does not respect 5GHz or OWE radio.

## Credits

This is based on the hard-coded packages from FFMUC and FFKA

- https://github.com/freifunkMUC/gluon-packages/tree/main/ffmuc-eol-ssid/
- https://gitlab.karlsruhe.freifunk.net/firmware/packages/-/blob/master/ffka-eol-ssid/
