# SPDX-FileCopyrightText: 2023 Florian Maurer (FFAC)
# SPDX-License-Identifier: BSD-2-Clause
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-scheduled-sysupgrade
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-or-later

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Allows scheduled sysupgrades from a given firmware server
  DEPENDS:=+gluon-core
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
