# Gluon community packages repository

During one of the bimonthly gluon review-days in 2020, the Gluon community-packages repository was created. Previously, many attempts to upstream community packages were either stuck for a very long time in the review process or died down completely.

We want to solve this by creating a central repository for inter-community packages, which is aimed at having shorter review cycles. Ideally, the community repository is maintained by the package maintainers themselves, allowing for faster improvements and a higher willingness for upstreaming community-packages.

## Using this repository

To include a package from this repository in your own firmware, add the repository to the feeds declared in the `modules` file of your site.

```
GLUON_SITE_FEEDS='community'

PACKAGES_COMMUNITY_REPO=https://github.com/freifunk-gluon/community-packages.git
PACKAGES_COMMUNITY_COMMIT=<COMMIT-HASH>
PACKAGES_COMMUNITY_BRANCH=master
```

Your commit has to be on the branch specified in `PACKAGES_COMMUNITY_BRANCH`.
If you leave out the `PACKAGES_COMMUNITY_BRANCH`, the repository default branch is used.

You should always test and check changes before using a new commit of the community-packages in your modules, as many people of the community have commit rights and there is currently no test or release process defined.

### Branches

There are 3 branches of this repository:

* main - follows development of [gluon](https://github.com/freifunk-gluon/gluon/) main branch
* v2023.2.x - for firmware releases based on [v2023.2.x](https://github.com/freifunk-gluon/gluon/tree/v2023.2.x)
* v2023.1.x - legacy branch for firmware up to [v2023.1.x](https://github.com/freifunk-gluon/gluon/tree/v2023.1.x)

## Contribution guidelines

In general, everybody is invited to open a pull request (PR), upstream useful packages and contribute to existing ones.
Everybody who contributed a package is given commit rights for the whole repository - to be able to maintain the package and contribute to the other packages as well.

There is no code ownership.
Additions to packages of other communities are possible as well, but should adhere to good communication standards

* Use pull requests if you are uncertain about your patches - this is generally a good practice to get feedback from others.
* Mark pull requests as draft if they are work-in-progress (WIP) or not ready to merge yet
* Give some time for reviews/feedback for non-urgent issues
* Being respectful of differing viewpoints and experiences
* Gracefully accepting constructive criticism
* Focusing on what is best for the community

### Style guide

Contributions need to pass `luacheck` and `shellcheck` which is also checked in PRs in the linting pipeline.

If specific adjustments are absolutely necessary (e.g. custom globals for luacheck), add them but make sure that the glob is specific to the files of your package.

### Commit guidelines

* The master branch is protected against the use of `git push --force`.
* Merge commits are disabled in the master branch. If you accept single-commit pull-requests, do a "rebase"- or "squash"-merge instead.
  This will prevent the commit-history to be cluttered with superfluous "merge" log messages.
  You can also merge with fast-forward locally and push this commit to the master branch, to keep the same commit hash.

### Commit-message guidelines

Every commit message should be prefixed with the package-name, followed by a colon.

It should also contain a summary of the changes and a short reasoning why they are needed

### Creating a package

For a general documentation on how OpenWrt packages software, see this wiki entry.

https://openwrt.org/docs/guide-developer/packages

Each package has its own subdirectory in the community-packages repository.

#### Package naming

Ideally, the name consists of the maintaining communities short-handle, followed by the package name.

After this scheme, a community with the short-handle `ffap` would name their package `ffap-sample-package`.

It is also possible to add packages with the `ff` slug to generalize the ownership or add packages without a tying maintenance to a specific community.

#### PKG_LICENSE

The PKG License should be defined as a SPDX ID. See the SPDX FAQ for more details.

[spdx.dev/learn/handling-license-info](https://spdx.dev/learn/handling-license-info/#how)

It is mandatory for packages to include a license in the Makefile

#### Sample Makefile

See the sample package Makefile below.

```
include $(TOPDIR)/rules.mk

PKG_NAME:=ffXX-hello-world
PKG_VERSION:=1.0.6
PKG_RELEASE:=1

PKG_MAINTAINER:=John Doe <john@doe.com>
PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Simple Hello World Makefile
  DEPENDS:=+ffXX-world
endef

define Package/$(PKG_NAME)/description
  A simple package to demonstrate a Makefile for the Gluon
  community-packages repository.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
```

After creating the package, open a PR to the community-packages repository.

#### Package Documentation

You are encouraged to add a README.md in your package folder, which specifies more details about your package.

This is the place to include detailed usage and configuration documentation of your package.
