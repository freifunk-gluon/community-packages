---
title: ffac-scheduled-sysupgrade
---

This package allows to do as scheduled sysupgrade by first downloading
the image, then waiting a while before doing the actual update. If all
routers a doing it this way, one does not have to care about leaf nodes
updating before their offloader. A switch can be scheduled by a given
time or will be done if a firmware update is already available for
*switch_after_existing_mins* minutes. This makes switching configs where
the site.mk is incompatible easier. If only site.conf changes are
incompatible, one should use **gluon-scheduled-domain-switch** instead.

In most cases, *ffho-autoupdater-wifi-fallback* can help with the
update. If the only uplink comes from a mesh-on-WAN/LAN connection,
which already did the update -this does not help - this package resolves
these situations.

If `sysupgrade` does not succeed with `--ignore-minor-compat-version`, it
will fall back to attempting an upgrade without the parameter. This makes
the package compatible with older versions of sysupgrade.

Nodes will switch when the defined *switch-time* has passed. In case the
node was powered off while this was supposed to happen, it might not be
able to acquire the correct time. If it downloaded a image previously,
it can still update after a given time.

# site.conf

All those settings have to be defined exclusively in the domain, not the
site.

scheduled_sysupgrade : optional (needed for domains to switch)


    firmware_server :
    -   server from which updates are fetched
    switch_after_existing_mins :
    -   amount of time to switch after the firmware has been successfully downloaded
    switch_time :
    -   UNIX epoch after which domain will be switched

Example:

    scheduled_sysupgrade = {
      firmware_server = 'http://firmware.freifunk-aachen.de/firmware/download/from-2022.1.x/stable/sysupgrade',
      switch_time = 1683626400, -- 09.05.2023 - 10:00 UTC
      switch_after_existing_mins = 120,
    },

This package is inspired by the gluon-core package `gluon-scheduled-domain-switch`.
