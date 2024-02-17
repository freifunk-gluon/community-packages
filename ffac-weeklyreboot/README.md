weekly reboot
=============

this script basically reboots a node once a week on thursday morning at a random
time between 3h15 and 6h AM.

Create a file `modules` with the following content in your `./gluon/site/`
directory and add these lines:

```
GLUON_SITE_FEEDS="community"
PACKAGES_EULENFUNK_REPO=https://github.com/freifunk-gluon/community-packages.git
PACKAGES_EULENFUNK_COMMIT=*/missing/*
PACKAGES_EULENFUNK_BRANCH=v2018.1.x
```

Now you can add the package `ffac-weeklyreboot` to your site.mk
(`*/missing/*` has to be replaced by the github-commit-ID of the version you
want to use, you have to pick it manually.)
