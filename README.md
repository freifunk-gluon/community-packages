# Community Repository

During the last bimonthly review-day, the Gluon community repository was created. Previously, many attempts to upstream community package-projects were either stuck for a very long time in the review process or died down completely.

We want to solve this by creating a central repository for inter-community packages which is aimed at having shorter review cycles. Ideally, the community repository is maintained by the package maintainers themselves, allowing for faster improvements and a higher willingness for upstreaming community-packages.

## Creating a package

For a general documentation on how OpenWrt packages software, see this wiki entry.

https://openwrt.org/docs/guide-developer/packages

Each package has it's own subdirectory in the community-repository. Ideally, the name consists of the maintaining communities short-handle, followed by the package name.

See the sample package Makefile below.

```
include $(TOPDIR)/rules.mk

PKG_NAME:=ffXX-hello-world
PKG_VERSION:=1.0.6
PKG_RELEASE:=1

PKG_MAINTAINER:=John Doe <john@doe.com>
PKG_LICENSE:=FantasyLicense

include $(TOPDIR)/../package/gluon.mk

define Package/ffXX-hello-world
  TITLE:=Simple Hello World Makefile
  DEPENDS:=+ffXX-world
endef

define Package/ffXX-hello-world/description
  A simple package to demonstrate a Makefile for the Gluon
  community-packages repository.
endef

$(eval $(call BuildPackageGluon,ffXX-hello-world))
```

After creating the package, open a pull-request to the community-repository.

## PKG_LICENSE

The PKG License should be defined as a SPDX ID. See the SPDX FAQ for more details.

https://spdx.org/ids-how
