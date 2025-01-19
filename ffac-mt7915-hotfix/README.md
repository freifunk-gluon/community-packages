ffac-mt7915-hotfix
=============

This package reboots the device if the mt7915-firmware hangs on ramips-mt7621
and mediatek-filogic. It's meant as a hotfix for the mcu timeout issue:
https://github.com/freifunk-gluon/gluon/issues/3154
The issue popped up with Gluon v2023.2, earlier releases are not affected.

Credits go to istrator from FFMUC who found the rf_regval correlation.

Create a file `modules` with the following content in your `./gluon/site/`
directory and add these lines: 

```
GLUON_SITE_FEEDS="community"
PACKAGES_COMMUNITY_REPO=https://github.com/freifunk-gluon/community-packages.git
PACKAGES_COMMUNITY_COMMIT=*/missing/*
PACKAGES_COMMUNITY_BRANCH=master
```

Now you can add the package `ffac-mt7915-hotfix` to your site.mk
(`*/missing/*` has to be replaced by the github-commit-ID of the version you
want to use, you have to pick it manually.)

Further info on the issue this tries to prevent from happening:
I've seen the MCU timeout issue happening as early as 16 hours of uptime.
MCU timeouts result in WiFi not working. WiFi mesh nodes running into the
issue go offline until they are rebooted manually while any wired node is
still accessible via ssh.

On most devices it will take days or weeks for this issue to manifest,
while others are affected daily. This is due to the difference in clients
that are connecting to it on a frequent base. The more people frequent
the device the more probable it is to go offline.

Also see https://github.com/freifunk-gluon/gluon/issues/3154
