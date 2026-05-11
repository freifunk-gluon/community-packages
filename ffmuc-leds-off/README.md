# ffmuc-leds-off

This package lets node operators turn off **all LEDs** during normal operation,
for nodes deployed in dark environments or where the LEDs would expose the
device to onlookers.

Errors and warnings remain visible because their existing LED behaviour is
untouched:

- **Setup / config mode** — the device still blinks its status LED so users
  can find a misconfigured node.
- **Sysupgrade in progress** — the OpenWrt diagnostic LED pattern fires
  normally, so users see the upgrade is running and won't power-off the
  device mid-flash.
- **Boot in progress (preinit)** — LEDs run their normal patterns until the
  device finishes booting. Only after `set_state done` (S95) does this package
  darken them (S99).

## Configuration

The package is **disabled by default** after install. To darken the LEDs on
a node:

```sh
uci set leds-off.settings.enabled='1'
uci commit leds-off
gluon-reconfigure                # registers the S99 init.d service
/etc/init.d/leds-off restart     # apply immediately (or reboot)
```

To restore default LED behaviour:

```sh
uci set leds-off.settings.enabled='0'
uci commit leds-off
gluon-reconfigure                # unregisters the S99 init.d service
/etc/init.d/leds-off stop        # best-effort restore now (or reboot)
```

A reboot is the safest way to restore LEDs whose default triggers come from
kernel device tree (DTS) and aren't tracked in `/etc/config/system`.

## How it works

When `enabled='1'`, an init script at `/etc/init.d/leds-off` (START=99,
i.e. *after* OpenWrt's `set_state done` at S95) iterates every entry under
`/sys/class/leds/` and sets:

- `trigger` → `none`
- `brightness` → `0`

This affects only software-controllable LEDs. LEDs wired directly to PHY
chips (some RJ45 link/activity indicators) cannot be turned off in software
and are unaffected by this package.

If the device is in setup mode (`gluon-setup-mode.@setup_mode[0].configured`
is not `1`), the darkening step is skipped so the setup-mode blink pattern
remains visible. In practice, setup mode runs a different init path
(`/lib/gluon/setup-mode/init.d/`) entirely, so the standard `/etc/init.d/leds-off`
wouldn't fire there anyway — the check is defence-in-depth.
