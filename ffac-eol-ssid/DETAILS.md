# ffac-eol-ssid – Details

## Files

| File | Purpose |
| --- | --- |
| `check_site.lua` | Validates `eol_ssid` in `site.conf` (dates must match `YYYY-MM-DD`) |
| `files/etc/config/eol-ssid` | Per-router switch (`enabled`), kept across upgrades |
| `files/etc/hotplug.d/ntp/50-eol-ssid` | Trigger: runs on busybox `ntpd` events |
| `luasrc/lib/gluon/upgrade/950-eol-ssid-nagger` | Migration and the actual logic |

## Trigger

1. **Gluon upgrade/boot** runs `950-eol-ssid-nagger` without `EOL_SSID_NTP_SYNCED`.
   Only the uci migrations are done, wifi is not touched (the clock is usually not yet valid).
2. **ntpd events** (`step`, `stratum`, `periodic`) call `/etc/hotplug.d/ntp/50-eol-ssid`.
   If `stratum < 16` (= clock is synchronized), it runs the nagger with `EOL_SSID_NTP_SYNCED=1`.
   `periodic` fires regularly, so a date that is reached while the router is running is applied without reboot.
   
   Even without NTP sync, you will receive a “periodic” hotplug event, with stratum=16, about every 11 minutes out of the box. (https://openwrt.org/docs/guide-user/base-system/hotplug)

No cron/`micrond` and no extra packages are required.

## Logic of the script

1. Migrate old settings (`eol-wifi`, `ffmuc`) to `eol-ssid.settings.enabled`.
2. Exit if disabled in `site.conf` (`eol_ssid.enabled`) or on the router (`eol-ssid.settings.enabled == 0`).
3. Exit if `EOL_SSID_NTP_SYNCED` is not `1` (no trusted time).
4. Parse `date_ssid` and `date_wifi_off` (local midnight) and compare with `os.time()`.
5. From `date_ssid`: set `wireless.client_radio0.ssid` to `eol_ssid.ssid`.
6. From `date_wifi_off`: set `disabled=1` on `client_radio0/1` and `owe_radio0/1`. Mesh sections are never touched.
7. If anything changed: `uci save` + `uci commit wireless` + `wifi reload`.

## Safety

- **No NTP, no action**: a wrong clock (e.g. 1970 or an unsynced RTC) can neither change the SSID nor disable wifi.
- **Idempotent**: values are written only if they differ; repeated runs do nothing and don't reload wifi.
- **Missing sections** (e.g. no second radio) are skipped.
- An invalid or missing date is ignored (that step never triggers); `check_site.lua` rejects it at build time.

## Notes

- Commit is needed here because the script runs at runtime. During a Gluon upgrade, Gluon commits itself.
- The SSID is only changed on `client_radio0` (2.4GHz); 5GHz SSIDs are not changed.
- Re-enabling wifi on a router needs a new config (e.g. reconfigure/factory reset), since `disabled=1` is re-applied on every sync after `date_wifi_off`.

## Testing

The script writes log messages with `logger -t eol-ssid` to the syslog. Logged are the early exits during upgrade/boot (disabled, no NTP sync yet) and every actual change (`client_radio0.ssid -> ...`, `client_radio0.disabled -> 1`, wifi reload). Runs without any change stay silent, so the small log buffer is not flooded.

Show the messages on the router:

```sh
logread -e eol-ssid
```

Trigger a run manually without waiting for ntpd (simulates a synchronized clock):

```sh
ACTION=periodic stratum=1 sh /etc/hotplug.d/ntp/50-eol-ssid
```

Then check the log and the resulting wireless config:

```sh
logread -e eol-ssid
uci show wireless | grep -E 'ssid|disabled'
```

To test the dates, temporarily set the router clock (e.g. `date -s "2027-01-01 12:00:00"`) before triggering. Note that a running ntpd will correct the time again.