# SPDX-FileCopyrightText: 2024 Florian Maurer
# SPDX-License-Identifier: BSD-2-Clause
include $(TOPDIR)/rules.mk

PKG_NAME:=ffac-dsl
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_LICENSE:=BSD-2-Clause

include $(TOPDIR)/../package/gluon.mk

define Package/$(PKG_NAME)
  TITLE:=Configure Gluon firmware for DSL usage
  DEPENDS:=ppp
endef

define Package/$(PKG_NAME)/description
  This package allows to set DSL credentials in gluon to connect WAN directly from DSL.
  Besides the username and password, the vlanid can be set.
endef

$(eval $(call BuildPackageGluon,$(PKG_NAME)))
