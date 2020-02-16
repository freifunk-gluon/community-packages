# Gluon community repository

During the last bimonthly review-day, the Gluon community repository was created. Previously, many attempts to upstream community packages were either stuck for a very long time in the review process or died down completely.

We want to solve this by creating a central repository for inter-community packages which is aimed at having shorter review cycles. Ideally, the community repository is maintained by the package maintainers themselves, allowing for faster improvements and a higher willingness for upstreaming community-packages.

## Using this repository

To include a package from this repository in your own firmware, add the repository to the feeds declared in the `modules` file of your site.

```
GLUON_SITE_FEEDS='community'

PACKAGES_COMMUNITY_REPO=https://github.com/freifunk-gluon/community-packages.git
PACKAGES_COMMUNITY_COMMIT=<COMMIT-HASH>
```

## Commit-message guidelines

Every commit message should prefixed with the package-name, followed by a colon.

## Creating a package

For a general documentation on how OpenWrt packages software, see this wiki entry.

https://openwrt.org/docs/guide-developer/packages

Each package has it's own subdirectory in the community-repository.

### Package naming

Ideally, the name consists of the maintaining communities short-handle, followed by the package name.

After this scheme, a community with the short-handle `ffap` would name their package `ffap-sample-package`.

### PKG_LICENSE

The PKG License should be defined as a SPDX ID. See the SPDX FAQ for more details.

https://spdx.org/ids-how


### Sample Makefile

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


## Addition to the [Contributing Guidelines](https://github.com/freifunk-gluon/gluon/blob/master/CONTRIBUTING.md)

for those, who have commit access:

* The master branch is protected against the use of `git push --force`.
* Use Pull Requests if you are unsure and to suggest changes to other developers.
* Merge commits are disabled in the master branch if you accept a single-commit PR, do a "rebase"- or "squash"-merge instead. This will prevent the commit-history to be cluttered with superfluous "merge" logmessages.
